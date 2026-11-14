#!/usr/bin/env python3
"""One-command Web release for Orbit & Outplay.

Does what the checklist in docs/BOARD.md asks for, so no release depends on
memory:

    import -> export -> validate -> package -> sha256 -> smoke serve -> RELEASE.txt

Usage:
    python tools/release.py                  # full release
    python tools/release.py --skip-import    # reuse the existing .godot cache
    python tools/release.py --port 8060      # pick the smoke-test port
    python tools/release.py --godot PATH     # explicit Godot 4.7.x binary

Writes:
    build/web/                        static export (index.html + 8 files)
    build/web/.gdignore               keeps Godot from importing the exports
    build/RELEASE.txt                 timestamps, sizes, sha256, smoke results
    submission/orbit_outplay_web.zip  the submission ZIP (files at the root)

Exit code is 0 only if the export, the file check, the zip and every smoke
request succeeded.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import http.server
import os
import shutil
import socket
import subprocess
import sys
import threading
import time
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"
WEB = BUILD / "web"
ZIP = ROOT / "submission" / "orbit_outplay_web.zip"
RELEASE_TXT = BUILD / "RELEASE.txt"

# Files the Godot 4.7.x Web exporter must produce (threadless variant).
EXPECTED = [
    "index.html",
    "index.js",
    "index.wasm",
    "index.pck",
    "index.png",
    "index.icon.png",
    "index.apple-touch-icon.png",
    "index.audio.worklet.js",
    "index.audio.position.worklet.js",
]

GODOT_CANDIDATES = [
    "godot",
    "godot4",
    "godot.exe",
    "Godot_v4.7.2-stable_win64_console.exe",
    "Godot_v4.7.2-stable_win64.exe",
    "/usr/local/bin/godot",
]


def find_godot(explicit: str | None) -> str:
    if explicit:
        if Path(explicit).exists() or shutil.which(explicit):
            return explicit
        raise SystemExit(f"godot binary not found: {explicit}")
    for cand in GODOT_CANDIDATES:
        found = shutil.which(cand)
        if found:
            return found
    raise SystemExit("no Godot binary on PATH; pass --godot <path>")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def stamp(path: Path) -> str:
    return dt.datetime.fromtimestamp(path.stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S")


def run(cmd: list[str], label: str) -> tuple[int, str]:
    print(f"$ {' '.join(cmd)}")
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True,
                          encoding="utf-8", errors="replace")
    tail = (proc.stdout + proc.stderr).strip().splitlines()
    if proc.returncode != 0:
        print("\n".join(tail[-25:]))
    print(f"{label}: exit {proc.returncode}")
    return proc.returncode, "\n".join(tail[-25:])


def free_port(preferred: int) -> int:
    with socket.socket() as s:
        if s.connect_ex(("127.0.0.1", preferred)) != 0:
            return preferred
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return int(s.getsockname()[1])


class _Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_args):  # keep the release log readable
        pass


def smoke(port: int) -> dict[str, int]:
    web = str(WEB)
    handler = lambda *a, **kw: _Quiet(*a, directory=web, **kw)  # noqa: E731
    httpd = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
    thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    thread.start()
    results: dict[str, int] = {}
    try:
        for name in ("index.html", "index.js", "index.wasm", "index.pck"):
            url = f"http://127.0.0.1:{port}/{name}"
            with urllib.request.urlopen(url, timeout=30) as resp:
                resp.read(64)  # touch the body so the read is real
                results[name] = resp.status
            print(f"smoke {name}: {results[name]}")
    finally:
        httpd.shutdown()
    return results


def package() -> int:
    ZIP.parent.mkdir(parents=True, exist_ok=True)
    metadata_date = (2026, 1, 1, 0, 0, 0)
    with zipfile.ZipFile(ZIP, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for name in EXPECTED:  # fixed order => stable diffs between releases
            src = WEB / name
            if not src.exists():
                raise SystemExit(f"missing export file: {name}")
            info = zipfile.ZipInfo(name, date_time=metadata_date)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            zf.writestr(info, src.read_bytes())
    return ZIP.stat().st_size


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default=None)
    ap.add_argument("--port", type=int, default=8060)
    ap.add_argument("--skip-import", action="store_true")
    ap.add_argument("--skip-smoke", action="store_true")
    args = ap.parse_args()

    godot = find_godot(args.godot)
    started = dt.datetime.now()
    notes: list[str] = []
    failures: list[str] = []

    BUILD.mkdir(parents=True, exist_ok=True)
    # Godot scans the whole project folder; this keeps build/ out of the
    # resource filesystem so exported PNGs are not re-imported as source art.
    gdignore = BUILD / ".gdignore"
    if not gdignore.exists():
        gdignore.write_text("", encoding="utf-8")

    shutil.rmtree(WEB, ignore_errors=True)
    WEB.mkdir(parents=True, exist_ok=True)

    if not args.skip_import:
        code, _ = run([godot, "--headless", "--path", str(ROOT), "--import"], "import")
        if code != 0:
            failures.append(f"import exited {code}")

    code, _ = run([godot, "--headless", "--path", str(ROOT),
                   "--export-release", "Web", str(WEB / "index.html")], "export")
    if code != 0:
        failures.append(f"export exited {code}")

    missing = [n for n in EXPECTED if not (WEB / n).is_file() or (WEB / n).stat().st_size == 0]
    if missing:
        failures.append(f"missing export files: {', '.join(missing)}")
    # Editor leftovers (exported PNGs re-imported as project art).
    for stray in WEB.glob("*.import"):
        stray.unlink()
        notes.append(f"removed stray import sidecar {stray.name}")

    zip_size = 0
    if not missing:
        zip_size = package()

    statuses: dict[str, int] = {}
    port = 0
    if not failures and not args.skip_smoke:
        port = free_port(args.port)
        statuses = smoke(port)
        bad = {k: v for k, v in statuses.items() if v != 200}
        if bad:
            failures.append(f"smoke failed: {bad}")

    lines = [
        "ORBIT & OUTPLAY - Web release",
        f"generated      {started.strftime('%Y-%m-%d %H:%M:%S')}",
        f"godot          {godot}",
        f"finished       {dt.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        f"result         {'OK' if not failures else 'FAILED'}",
        "",
        "export",
    ]
    for name in EXPECTED:
        p = WEB / name
        if p.is_file():
            lines.append(f"  {name:32} {p.stat().st_size:>11,}  {stamp(p)}")
    lines += [
        "",
        f"zip            {ZIP}",
        f"zip size       {zip_size:,}",
        f"zip entries    {len(EXPECTED)} (files at the archive root)",
        "",
        "sha256",
        f"  index.pck    {sha256(WEB / 'index.pck')}",
        f"  index.wasm   {sha256(WEB / 'index.wasm')}",
        f"  zip          {sha256(ZIP)}",
        "",
        f"smoke          {'skipped' if args.skip_smoke else f'http://127.0.0.1:{port} ' + ', '.join(f'{k} {v}' for k, v in statuses.items())}",
    ]
    if notes:
        lines += ["", "notes"] + [f"  {n}" for n in notes]
    if failures:
        lines += ["", "failures"] + [f"  {f}" for f in failures]
    RELEASE_TXT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    print(f"\nwrote {RELEASE_TXT}")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
