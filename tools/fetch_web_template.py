#!/usr/bin/env python3
"""Install only the Godot 4.7.2 Web export templates (not the 1.2 GB pack).

Godot ships export templates as one `Godot_v4.7.2-stable_export_templates.tpz`
(1.2 GB). A Web-only build needs a small slice of it. This tool treats the
remote .tpz as a random-access ZIP over HTTP range requests, lists the archive,
and extracts only the requested members into the local template directory.

Usage:
    python tools/fetch_web_template.py
    python tools/fetch_web_template.py --list
    python tools/fetch_web_template.py --dest "C:/.../export_templates/4.7.2.stable"

The destination defaults to the platform export-template folder:
    Windows  %APPDATA%/Godot/export_templates/4.7.2.stable
    Linux    ~/.local/share/godot/export_templates/4.7.2.stable
    macOS    ~/Library/Application Support/Godot/export_templates/4.7.2.stable

After this, `godot --headless --path . --export-release "Web" build/web/index.html`
works without downloading the full template pack.
"""

from __future__ import annotations

import argparse
import io
import os
import platform
import sys
import urllib.request
import zipfile
from pathlib import Path

VERSION = "4.7.2.stable"
TPZ_URL = (
    "https://github.com/godotengine/godot/releases/download/4.7.2-stable/"
    "Godot_v4.7.2-stable_export_templates.tpz"
)
# Web templates are small (~10-12 MB each). Fetch the threadless and threaded
# sets so the export config can change without another download.
MEMBERS = [
    "templates/web_release.zip",
    "templates/web_debug.zip",
    "templates/web_nothreads_release.zip",
    "templates/web_nothreads_debug.zip",
    "templates/web_dlink_release.zip",
    "templates/web_dlink_debug.zip",
    "templates/web_dlink_nothreads_release.zip",
    "templates/web_dlink_nothreads_debug.zip",
    "templates/version.txt",
]


class HTTPRangeFile(io.RawIOBase):
    """Read-only seekable file over HTTP range requests."""

    def __init__(self, url: str) -> None:
        super().__init__()
        self.url = url
        self.pos = 0
        req = urllib.request.Request(url, headers={"Range": "bytes=0-0"})
        with urllib.request.urlopen(req) as res:
            # Follow GitHub's redirect to the object host once.
            self.url = res.geturl()
            cr = res.headers.get("Content-Range", "")
            if "/" not in cr:
                raise RuntimeError("server does not expose a range length")
            self.size = int(cr.rsplit("/", 1)[1])

    def readable(self) -> bool:
        return True

    def seekable(self) -> bool:
        return True

    def tell(self) -> int:
        return self.pos

    def seek(self, offset: int, whence: int = io.SEEK_SET) -> int:
        if whence == io.SEEK_SET:
            self.pos = offset
        elif whence == io.SEEK_CUR:
            self.pos += offset
        elif whence == io.SEEK_END:
            self.pos = self.size + offset
        else:
            raise ValueError("bad whence")
        if self.pos < 0:
            raise ValueError("negative seek")
        return self.pos

    def read(self, n: int = -1) -> bytes:
        if n < 0:
            n = self.size - self.pos
        if n == 0 or self.pos >= self.size:
            return b""
        end = min(self.size, self.pos + n) - 1
        req = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{end}"})
        with urllib.request.urlopen(req) as res:
            data = res.read()
        self.pos += len(data)
        return data

    def readinto(self, b) -> int:
        data = self.read(len(b))
        b[: len(data)] = data
        return len(data)


def default_dest() -> Path:
    home = Path.home()
    if platform.system() == "Windows":
        root = Path(os.environ.get("APPDATA", home / "AppData" / "Roaming")) / "Godot"
    elif platform.system() == "Darwin":
        root = home / "Library" / "Application Support" / "Godot"
    else:
        root = home / ".local" / "share" / "godot"
    return root / "export_templates" / VERSION


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dest", default=str(default_dest()),
                    help="export_templates/<version> directory")
    ap.add_argument("--list", action="store_true", help="list template members only")
    ap.add_argument("--release-only", action="store_true", help="skip web_debug.zip")
    args = ap.parse_args()

    print(f"opening {TPZ_URL}")
    remote = HTTPRangeFile(TPZ_URL)
    print(f"remote pack: {remote.size / 1e9:.2f} GB")

    wanted = [m for m in MEMBERS if not (args.release_only and "debug" in m)]
    with zipfile.ZipFile(remote) as z:
        names = z.namelist()
        if args.list:
            for n in names:
                info = z.getinfo(n)
                print(f"{info.file_size / 1e6:8.2f} MB  {n}")
            return
        found = {n: z.getinfo(n) for n in names if n in wanted}
        missing = [m for m in wanted if m not in found]
        if missing:
            sys.exit(f"missing in template pack: {missing}")
        dest = Path(args.dest)
        dest.mkdir(parents=True, exist_ok=True)
        for name, info in found.items():
            target = dest / Path(name).name
            print(f"extracting {name}  ({info.file_size / 1e6:.1f} MB) -> {target}")
            with z.open(name) as src, open(target, "wb") as out:
                while True:
                    chunk = src.read(1 << 20)
                    if not chunk:
                        break
                    out.write(chunk)
    print(f"templates ready in {dest}")
    print('export with: godot --headless --path . --export-release "Web" build/web/index.html')


if __name__ == "__main__":
    main()
