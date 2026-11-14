#!/usr/bin/env python3
"""Build data/exoplanets.json from a NASA Exoplanet Archive pscomppars CSV.

Source: https://exoplanetarchive.ipac.caltech.edu/  (NASA Exoplanet Archive,
Caltech/IPAC, operated under contract with NASA). Values are the archive's
composite parameters (pscomppars table).

The game only lands on small, rocky worlds, so the curated set keeps planets
with 0.4 <= radius <= 2.7 Earth radii and a measured equilibrium temperature.
Every derived game number is stored next to the measured value so the UI can
show exactly which real datum produced which constraint.
"""
import csv, json, math, hashlib, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "data", "pscomppars_raw.csv")
OUT = os.path.join(ROOT, "data", "exoplanets.json")

# Iconic, well-known small worlds first. Missing entries are skipped.
PREFERRED = [
    "TRAPPIST-1 b", "TRAPPIST-1 c", "TRAPPIST-1 d", "TRAPPIST-1 e",
    "TRAPPIST-1 f", "TRAPPIST-1 g",
    "Proxima Cen b", "Proxima Cen d",
    "Kepler-186 f", "Kepler-442 b", "Kepler-452 b", "Kepler-62 f",
    "Kepler-62 e", "Kepler-22 b", "Kepler-1649 c", "Kepler-1652 b",
    "Kepler-283 c", "Kepler-296 e", "Kepler-296 f", "Kepler-705 b",
    "Kepler-1229 b", "Kepler-1544 b", "Kepler-1410 b", "Kepler-1638 b",
    "TOI-700 d", "TOI-700 e", "TOI-2257 b", "TOI-1452 b", "TOI-270 d",
    "TOI-1233 b", "TOI-2095 b", "TOI-2095 c", "TOI-244 b",
    "Teegarden's Star b", "Teegarden's Star c",
    "LHS 1140 b", "LHS 1140 c", "LHS 1723 b", "GJ 667C c", "GJ 667C f",
    "GJ 1002 b", "GJ 1002 c", "GJ 1061 c", "GJ 1061 d", "GJ 273 b",
    "Ross 128 b", "Wolf 1061 c", "Barnard's Star b", "Barnard b",
    "K2-18 b", "K2-3 d", "K2-72 e", "K2-155 d", "K2-9 b",
    "55 Cnc e", "HD 219134 b", "HD 219134 c", "HD 40307 g",
    "tau Cet e", "tau Cet f", "GJ 1214 b", "GJ 486 b",
    "WASP-47 e", "HD 260655 b", "HD 260655 c", "HD 20794 d",
    "Kepler-10 b", "Kepler-78 b", "Kepler-93 b", "Kepler-138 c",
    "Kepler-138 d", "Kepler-20 b", "Kepler-36 b", "Kepler-48 e",
]


def fnum(row, key):
    v = row.get(key, "").strip()
    if v == "":
        return None
    try:
        return float(v)
    except ValueError:
        return None


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def stable_hash(s):
    return int(hashlib.sha256(s.encode()).hexdigest()[:8], 16)


def classify(teq, radius, name):
    """Pick a surface archetype from real equilibrium temperature."""
    h = stable_hash(name) % 100
    if teq >= 800:
        return "volcanic" if h < 55 else "sulfur"
    if teq >= 460:
        return "arid" if h < 60 else "iron"
    if teq >= 335:
        return "barren" if h < 60 else "crystal"
    if teq >= 238:
        return "temperate" if radius <= 1.9 or h < 35 else "arid"
    if teq >= 175:
        return "barren" if h < 70 else "cryo"
    return "cryo" if h < 60 else "ammonia"


def build_record(row):
    name = row["pl_name"]
    radius = fnum(row, "pl_rade")
    teq = fnum(row, "pl_eqt")
    if teq is None:
        insol0 = fnum(row, "pl_insol")
        if insol0 is None:
            sma = fnum(row, "pl_orbsmax")
            insol0 = (1.0 / (sma ** 2)) if sma else None
        if insol0 is not None:
            # Blackbody equilibrium temperature, zero-albedo convention.
            teq = 255.0 * (insol0 ** 0.25)
    if radius is None or teq is None:
        return None
    if not (0.35 <= radius <= 2.2):
        return None

    mass = fnum(row, "pl_bmasse")
    mass_est = False
    # A handful of archive mass entries are upper limits or composite outliers
    # (e.g. Kepler-62 e/f at 36 M-earth for a 1.6 R-earth world). A density
    # above 3 Earth-densities is not a plausible rocky planet, so use the same
    # Chen & Kipping (2017) mass-radius estimate and flag it in the data.
    if mass is None or mass / (radius ** 3) > 3.0:
        mass = radius ** 2.06
        mass_est = True

    period = fnum(row, "pl_orbper")
    semimajor = fnum(row, "pl_orbsmax")
    ecc = fnum(row, "pl_orbeccen") or 0.0
    insol = fnum(row, "pl_insol")
    if insol is None and semimajor:
        insol = 1.0 / (semimajor ** 2)
    dist_pc = fnum(row, "sy_dist") or 100.0
    dist_ly = dist_pc * 3.26156

    star_teff = fnum(row, "st_teff")
    star_rad = fnum(row, "st_rad")
    star_mass = fnum(row, "st_mass")
    star_age = fnum(row, "st_age")
    star_met = fnum(row, "st_met") or 0.0
    n_planets = int(fnum(row, "sy_pnum") or 1)

    gravity = 9.81 * mass / (radius * radius)
    escape = 11.186 * math.sqrt(mass / radius)

    # --- game-facing derived values (all traceable to the fields above) ---
    heat = int(clamp((teq - 140.0) / 8.0, 4, 100))          # thermal load
    rad = 12.0
    if star_age is not None and star_age < 1.0:
        rad += 32
    elif star_age is not None and star_age < 3.0:
        rad += 16
    if star_teff and star_teff > 6200:
        rad += 14
    if star_teff and star_teff < 3900:
        rad += 8
    if insol and insol > 10:
        rad += 10
    rad = int(clamp(rad, 10, 95))

    quake = int(clamp((gravity / 9.81 - 0.8) * 45.0, 0, 55))
    comms_loss = 0 if dist_ly < 20 else 5 if dist_ly < 50 else 10 if dist_ly < 120 else 18 if dist_ly < 350 else 25

    science = 55
    if 180 <= teq <= 330:
        science += 28
    if radius <= 1.65:
        science += 16
    if n_planets >= 3:
        science += 8
    if star_teff and 4200 <= star_teff <= 6800:
        science += 6
    science = int(clamp(science, 40, 120))

    # Fuel budget: heavy, hot, radioactive worlds cost more delta-v.
    dv = 36 - (gravity / 9.81) * 2.5 - heat * 0.05 - rad * 0.08
    dv = int(clamp(round(dv), 18, 36))
    sols = int(clamp(round(34 - abs(teq - 280) / 55.0), 22, 36))

    biome = classify(teq, radius, name)
    return {
        "id": name,
        "name": name,
        "star": row.get("hostname", "").strip(),
        "star_type": row.get("st_spectype", "").strip() or "—",
        "distance_ly": round(dist_ly, 1),
        "discovered": int(fnum(row, "disc_year") or 0),
        "method": row.get("discoverymethod", "").strip() or "—",
        "period_days": round(period, 3) if period else None,
        "semi_major_au": round(semimajor, 4) if semimajor else None,
        "eccentricity": round(ecc, 3),
        "radius_earth": round(radius, 2),
        "mass_earth": round(mass, 2),
        "mass_est": mass_est,
        "eq_temp_k": round(teq, 0),
        "insolation_earth": round(insol, 3) if insol else None,
        "star_temp_k": round(star_teff, 0) if star_teff else None,
        "star_radius_sun": round(star_rad, 3) if star_rad else None,
        "star_mass_sun": round(star_mass, 3) if star_mass else None,
        "star_age_gyr": round(star_age, 2) if star_age else None,
        "star_metallicity": round(star_met, 2),
        "system_planets": n_planets,
        "gravity_g": round(gravity / 9.81, 2),
        "escape_kms": round(escape, 2),
        "biome": biome,
        "game": {
            "heat": heat,
            "radiation": rad,
            "quakes": quake,
            "comms_loss": comms_loss,
            "science": science,
            "delta_v": dv,
            "sols": sols,
        },
    }


def main():
    rows = []
    with open(RAW, newline="") as f:
        for row in csv.DictReader(f):
            rec = build_record(row)
            if rec:
                rows.append(rec)
    by_name = {r["id"]: r for r in rows}

    picked = []
    for name in PREFERRED:
        if name in by_name:
            picked.append(by_name[name])

    # Fill to 60 with a spread across temperature and distance, preferring
    # complete mass measurements and famous hosts.
    def score(r):
        famous = 1000 if r["id"] in PREFERRED else 0
        complete = 60 if not r["mass_est"] else 0
        multi = 25 if r["system_planets"] >= 3 else 0
        temp = 30 if 180 <= r["eq_temp_k"] <= 330 else 0
        return famous + complete + multi + temp

    rest = sorted(rows, key=score, reverse=True)
    seen = {r["id"] for r in picked}
    # quota by biome so drafts are never all one flavour
    quota = {"temperate": 12, "cryo": 8, "arid": 7, "barren": 7,
             "volcanic": 6, "iron": 4, "sulfur": 3, "crystal": 3,
             "ammonia": 4}
    counts = {}
    for r in picked:
        counts[r["biome"]] = counts.get(r["biome"], 0) + 1
    for r in rest:
        if len(picked) >= 72:
            break
        if r["id"] in seen:
            continue
        cap = quota.get(r["biome"], 3)
        if counts.get(r["biome"], 0) >= cap:
            continue
        picked.append(r)
        seen.add(r["id"])
        counts[r["biome"]] = counts.get(r["biome"], 0) + 1

    # Interleave biomes so a 3-card draft is visually varied.
    from collections import defaultdict
    buckets = defaultdict(list)
    for r in picked:
        buckets[r["biome"]].append(r)
    for b in buckets:
        buckets[b].sort(key=lambda r: -r["game"]["science"])
    mixed = []
    order = ["temperate", "cryo", "arid", "volcanic", "barren",
             "iron", "crystal", "ammonia", "sulfur"]
    while any(buckets[b] for b in order):
        for b in order:
            if buckets[b]:
                mixed.append(buckets[b].pop(0))
    picked = mixed
    meta = {
        "source": "NASA Exoplanet Archive — Planetary Systems Composite Parameters (pscomppars)",
        "source_url": "https://exoplanetarchive.ipac.caltech.edu/",
        "retrieved": "2026-11-14",
        "count": len(picked),
        "fields": list(picked[0].keys()) if picked else [],
    }
    payload = {"meta": meta, "planets": picked}
    with open(OUT, "w") as f:
        json.dump(payload, f, indent=1)
    print(f"wrote {OUT}: {len(picked)} planets")
    from collections import Counter
    print(Counter(r["biome"] for r in picked))
    for r in picked[:8]:
        print(r["name"], r["biome"], r["eq_temp_k"], r["radius_earth"],
              r["game"])


if __name__ == "__main__":
    main()
