#!/usr/bin/env python3
"""Audit `data/` and the numeric claims the docs make about it.

Owner: e (data & copy). Run from the repo root:

    python tools/audit_data.py

Exit code 0 = every check passed; 1 = at least one failed.

Four checks:
  1. Re-derive `data/exoplanets.json` from `data/pscomppars_raw.csv` and diff
     the planet records (the README calls the builder deterministic).
  2. Recompute every derived `game.*` value from the stored measured fields
     (rounding-tolerant), so a hand-edit or stale dataset is caught.
  3. Validate `data/events.json` against the schema/effect contract in
     `docs/EVENTS.md`.
  4. Assert the exact counts/ranges that README.md, docs/PROJECT.md and
     docs/SUBMISSION.md state, so the copy cannot drift from the data.

This is a static check: it needs Python 3 only, no Godot runtime.
"""
from __future__ import annotations

import collections
import contextlib
import importlib.util
import io
import json
import os
import re
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
PLANETS = os.path.join(DATA, "exoplanets.json")
EVENTS = os.path.join(DATA, "events.json")
RAW = os.path.join(DATA, "pscomppars_raw.csv")
BUILDER = os.path.join(ROOT, "tools", "build_exoplanets.py")
README = os.path.join(ROOT, "README.md")
PROJECT = os.path.join(ROOT, "docs", "PROJECT.md")
SUBMISSION = os.path.join(ROOT, "docs", "SUBMISSION.md")

CHECKS: list[tuple[str, bool, str]] = []


def check(name: str, ok: bool, detail: str = "") -> None:
    CHECKS.append((name, bool(ok), detail))
    print(("PASS  " if ok else "FAIL  ") + name + (("  -  " + detail) if detail else ""))


def read_text(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        return f.read()


def read_json(path: str):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def canon(value) -> str:
    return json.dumps(value, sort_keys=True, indent=1)


def main() -> int:
    planets_payload = read_json(PLANETS)
    planets = planets_payload["planets"]
    meta = planets_payload.get("meta", {})
    ids = [p["id"] for p in planets]
    readme = read_text(README)
    project = read_text(PROJECT)
    submission = read_text(SUBMISSION)

    print("== 1. dataset shape and regeneration ==")
    check("exoplanets: meta count matches records",
          int(meta.get("count", -1)) == len(planets),
          "meta=%s actual=%d" % (meta.get("count"), len(planets)))
    check("exoplanets: ids are unique", len(ids) == len(set(ids)))
    check("exoplanets: every record has a game block",
          all(isinstance(p.get("game"), dict) for p in planets))

    if os.path.exists(RAW) and os.path.exists(BUILDER):
        spec = importlib.util.spec_from_file_location("build_exoplanets", BUILDER)
        builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(builder)
        fd, regen_path = tempfile.mkstemp(prefix="regen_exoplanets_", suffix=".json")
        os.close(fd)
        try:
            builder.OUT = regen_path
            with contextlib.redirect_stdout(io.StringIO()):
                builder.main()
            regen = read_json(regen_path)["planets"]
            identical = canon(regen) == canon(planets)
            check("exoplanets: regenerates byte-identically from the raw CSV",
                  identical,
                  "regen %d vs committed %d" % (len(regen), len(planets)))
            if not identical:
                a = {p["id"]: p for p in planets}
                b = {p["id"]: p for p in regen}
                only_a = sorted(set(a) - set(b))
                only_b = sorted(set(b) - set(a))
                diff = [k for k in sorted(set(a) & set(b)) if canon(a[k]) != canon(b[k])]
                print("      only committed:", only_a[:5])
                print("      only regenerated:", only_b[:5])
                print("      records differing:", diff[:5])
        finally:
            if os.path.exists(regen_path):
                os.remove(regen_path)
    else:
        check("exoplanets: raw CSV + builder present for regeneration", False,
              "cannot verify determinism without %s" % RAW)

    print("\n== 2. derived game values recompute from measurements ==")

    def expected(p: dict) -> dict:
        teq = float(p["eq_temp_k"])
        rad = float(p["radius_earth"])
        mass = float(p["mass_earth"])
        age = p.get("star_age_gyr")
        teff = p.get("star_temp_k")
        insol = p.get("insolation_earth")
        dist = float(p["distance_ly"])
        npl = int(p["system_planets"])
        g = mass / (rad * rad)
        out = {"heat": int(max(4, min(100, (teq - 140.0) / 8.0)))}
        r = 12.0
        if age is not None and age < 1.0:
            r += 32
        elif age is not None and age < 3.0:
            r += 16
        if teff and teff > 6200:
            r += 14
        if teff and teff < 3900:
            r += 8
        if insol and insol > 10:
            r += 10
        out["radiation"] = int(max(10, min(95, r)))
        out["quakes"] = int(max(0, min(55, (g - 0.8) * 45.0)))
        out["comms_loss"] = (0 if dist < 20 else 5 if dist < 50 else
                             10 if dist < 120 else 18 if dist < 350 else 25)
        s = 55
        if 180 <= teq <= 330:
            s += 28
        if rad <= 1.65:
            s += 16
        if npl >= 3:
            s += 8
        if teff and 4200 <= teff <= 6800:
            s += 6
        out["science"] = int(max(40, min(120, s)))
        dv = 36 - g * 2.5 - out["heat"] * 0.05 - out["radiation"] * 0.08
        out["delta_v"] = int(max(18, min(36, round(dv))))
        out["sols"] = int(max(22, min(36, round(34 - abs(teq - 280) / 55.0))))
        return out

    mismatches: list[str] = []
    for p in planets:
        for key, value in expected(p).items():
            if abs(int(p["game"][key]) - value) > 1:  # stored inputs are rounded
                mismatches.append("%s.%s committed=%d recomputed=%d" %
                                  (p["id"], key, int(p["game"][key]), value))
    check("exoplanets: game.* values agree with the documented formulas",
          not mismatches,
          "%d mismatches%s" % (len(mismatches),
                               (": " + "; ".join(mismatches[:4])) if mismatches else ""))

    print("\n== 3. event cards ==")
    events_payload = read_json(EVENTS)
    events = events_payload.get("events", [])
    emeta = events_payload.get("meta", {})
    effect_keys = set(emeta.get("effect_keys", []))
    check("events: count matches meta", int(emeta.get("count", -1)) == len(events),
          "meta=%s actual=%d" % (emeta.get("count"), len(events)))
    check("events: ids unique", len(events) == len({e["id"] for e in events}))

    problems: list[str] = []
    for e in events:
        choices = e.get("choices", [])
        if len(choices) != 2:
            problems.append("%s has %d choices" % (e["id"], len(choices)))
        if not str(e.get("title", "")) == str(e.get("title", "")).upper():
            problems.append("%s title not uppercase" % e["id"])
        if len(str(e.get("title", ""))) > 18:
            problems.append("%s title too long" % e["id"])
        if len(str(e.get("tag", ""))) > 13:
            problems.append("%s tag too long" % e["id"])
        if len(str(e.get("body", ""))) > 150:
            problems.append("%s body too long" % e["id"])
        for c in choices:
            label = str(c.get("label", ""))
            if not label or label != label.upper():
                problems.append("%s choice label not uppercase" % e["id"])
            if not str(c.get("detail", "")).strip():
                problems.append("%s choice missing detail" % e["id"])
            if c.get("kind") not in ("safe", "greedy"):
                problems.append("%s choice kind %r" % (e["id"], c.get("kind")))
            for key, value in (c.get("effects") or {}).items():
                if key not in effect_keys:
                    problems.append("%s unknown effect key %s" % (e["id"], key))
                if key.endswith("_mult_next") and not (0.5 <= float(value) <= 2.0):
                    problems.append("%s multiplier %s=%s out of clamp" %
                                    (e["id"], key, value))
    check("events: schema, effect keys, clamps and copy limits", not problems,
          "; ".join(problems[:5]))

    print("\n== 4. numeric claims in the docs ==")
    stats = {
        "planets": len(planets),
        "radius_min": min(p["radius_earth"] for p in planets),
        "radius_max": max(p["radius_earth"] for p in planets),
        "stars": len({p["star"] for p in planets}),
        "transit": sum(1 for p in planets if p["method"] == "Transit"),
        "rv": sum(1 for p in planets if p["method"] == "Radial Velocity"),
        "distance_min": min(p["distance_ly"] for p in planets),
        "distance_max": max(p["distance_ly"] for p in planets),
        "mass_est": sum(1 for p in planets if p["mass_est"]),
        "gravity_max": max(p["gravity_g"] for p in planets),
        "biomes": collections.Counter(p["biome"] for p in planets),
        "raw_rows": 0,
    }
    if os.path.exists(RAW):
        import csv
        with open(RAW, newline="", encoding="utf-8") as f:
            stats["raw_rows"] = sum(1 for _ in csv.DictReader(f))
    print("      stats: " + json.dumps({
        k: (dict(v) if isinstance(v, collections.Counter) else v)
        for k, v in stats.items()}, sort_keys=True))

    claims = [
        ("README: '72 curated planets'", "72 curated planets" in readme),
        ("README: '0.69-2.19 Earth radii'",
         "0.69\u20132.19 Earth radii" in readme),
        ("README: '54 host stars'", "54 host stars" in readme),
        ("README: '52 transit and 20 radial-velocity'",
         "52 transit and 20 radial-velocity" in readme),
        ("README: '4.2-4,976 light-years'",
         "4.2\u20134,976 light-years" in readme),
        ("README: '5,801 rows'", "5,801 rows" in readme),
        ("README: 'Nine are landable'", "Nine are landable" in readme),
        ("PROJECT: '72 planets, 0.69-2.19'",
         "72 planets, 0.69\u20132.19" in project),
        ("PROJECT: 'builder filter 0.35-2.2'",
         "builder filter 0.35\u20132.2" in project),
        ("SUBMISSION: 'three archive masses'", "three archive masses" in submission),
        ("SUBMISSION: '72 planets, 0.69-2.19'",
         "72 planets, 0.69\u20132.19" in submission),
    ]
    for name, ok in claims:
        check(name, ok)

    check("data: curated count is 72", stats["planets"] == 72, str(stats["planets"]))
    check("data: radius range is 0.69-2.19",
          (stats["radius_min"], stats["radius_max"]) == (0.69, 2.19),
          repr((stats["radius_min"], stats["radius_max"])))
    check("data: 54 host stars", stats["stars"] == 54, str(stats["stars"]))
    check("data: 52 transit / 20 radial velocity",
          (stats["transit"], stats["rv"]) == (52, 20),
          repr((stats["transit"], stats["rv"])))
    check("data: 4.2-4,976 ly", stats["distance_min"] == 4.2 and
          round(stats["distance_max"]) == 4976,
          repr((stats["distance_min"], stats["distance_max"])))
    check("data: 3 mass estimates", stats["mass_est"] == 3, str(stats["mass_est"]))
    check("data: raw CSV has 5,801 rows", stats["raw_rows"] == 5801,
          str(stats["raw_rows"]))
    landable = {"temperate", "arid", "cryo", "volcanic", "barren",
                "iron", "sulfur", "crystal", "ammonia"}
    check("data: pool uses only the 9 landable biomes",
          set(stats["biomes"]) <= landable,
          repr(sorted(set(stats["biomes"]) - landable)))
    check("data: all 9 landable biomes are represented",
          set(stats["biomes"]) == landable,
          repr(sorted(landable - set(stats["biomes"]))))

    print("\n== 5. shipped event pool and doc claims ==")
    game_state = read_text(os.path.join(ROOT, "scripts", "game_state.gd"))
    events_doc = read_text(os.path.join(ROOT, "docs", "EVENTS.md"))
    start = game_state.find("const EVENTS := [")
    end = game_state.find("func science_fit", start)
    block = game_state[start:end] if start >= 0 and end > start else ""
    shipped_ids = re.findall(r'"id":\s*"([^"]+)"', block)
    shipped_titles = re.findall(r'"title":\s*"([^"]+)"', block)
    expected_ids = {
        "solar_storm", "private_donor", "salvage_cache", "cryo_leak",
        "stellar_data", "crew_fatigue", "rival_agency", "anomalous_signal",
        "pulsar_fix", "sail_trial", "debris_sweep", "host_city",
        "radiator_swap", "open_source",
    }
    check("events: shipped inline pool has 14 cards", len(shipped_ids) == 14,
          "found %d" % len(shipped_ids))
    check("events: shipped ids match the documented pool",
          set(shipped_ids) == expected_ids,
          repr(sorted(set(shipped_ids) ^ expected_ids)))
    check("events: shipped titles are uppercase",
          all(t == t.upper() for t in shipped_titles),
          repr([t for t in shipped_titles if t != t.upper()]))
    for eid in sorted(expected_ids):
        check("EVENTS.md: shipped card %s is documented" % eid, eid in events_doc)
    check("EVENTS.md: data/events.json is marked as a prototype",
          "data/events.json" in events_doc and "prototype" in events_doc)

    check("README: incident choice is documented",
          "one seeded incident with two trade-offs" in readme)
    check("README: FORMING pre-state is documented", "FORMING" in readme)
    check("README: next-grade gap is documented", "next-grade gap" in readme)
    check("README: does not claim a DECISIONS report line",
          "DECISIONS" not in readme)
    check("SUBMISSION: relay sector is documented", "RELAY SURVEY" in submission)
    check("SUBMISSION: seeded agency event is documented",
          "seeded agency event" in submission)
    page_path = os.path.join(ROOT, "docs", "PROJECT_PAGE.md")
    check("E1: project page exists", os.path.exists(page_path))
    if os.path.exists(page_path):
        page = read_text(page_path)
        check("E1: project page carries the crew/difficulty/daily story",
              all(s in page for s in ("Cadet", "Standard", "Director", "daily")))
    check("E1: deck speaker notes exist",
          os.path.exists(os.path.join(ROOT, "docs", "DECK_NOTES.md")))

    failed = [name for name, ok, _ in CHECKS if not ok]
    print("\n%d checks, %d failed" % (len(CHECKS), len(failed)))
    if failed:
        print("FAILED: " + "; ".join(failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
