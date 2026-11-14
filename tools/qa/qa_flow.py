#!/usr/bin/env python3
"""Full-loop browser QA for the Web build.

Serves build/web over HTTP, boots the game with Playwright Firefox, walks the
whole flow (callsign -> briefing -> title -> design -> draft -> review -> sector
-> one turn) and saves a screenshot per screen plus every console/page error.

Usage:
    python3 tools/qa/qa_flow.py [outdir] [--port 8777]

Exit code is non-zero when any console/page error was collected, so it can gate
a release.
"""
import asyncio
import os
import subprocess
import sys
import time

from playwright.async_api import async_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BUILD = os.path.join(ROOT, "build", "web")
OUT = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "/tmp/opencode/qa_flow"
PORT = sys.argv[sys.argv.index("--port") + 1] if "--port" in sys.argv else "8777"


async def run(pw, width, height, tag, outdir):
    browser = await pw.firefox.launch(headless=True)
    page = await browser.new_page(viewport={"width": width, "height": height})
    errors = []
    page.on("console", lambda m: errors.append(m.text[:200]) if m.type == "error" else None)
    page.on("pageerror", lambda e: errors.append("PAGEERROR " + str(e)[:200]))

    await page.goto(f"http://127.0.0.1:{PORT}/index.html", wait_until="load", timeout=60000)
    for _ in range(60):
        await asyncio.sleep(1)
        ready = await page.evaluate(
            "() => { const c = document.querySelector('canvas'); return !!(c && c.width > 0); }"
        )
        if ready:
            break
    await asyncio.sleep(4)

    async def shot(name):
        await page.screenshot(path=os.path.join(outdir, f"{tag}_{name}.png"))

    await page.mouse.click(width // 2, height - 60)
    await asyncio.sleep(1.5)
    await shot("01_briefing")
    await page.keyboard.press("Enter")      # file the callsign
    await asyncio.sleep(1.5)
    await page.keyboard.press("Escape")     # skip the briefing
    await asyncio.sleep(2.0)
    await shot("02_title")
    await page.mouse.click(int(width * 0.14), int(height * 0.49))  # BEGIN MISSION
    await asyncio.sleep(4.0)
    await shot("03_design")
    await page.keyboard.press("Enter")      # confirm design -> draft
    await asyncio.sleep(4.0)
    await shot("04_draft")
    await page.keyboard.press("Enter")      # open the architecture review
    await asyncio.sleep(3.0)
    await shot("05_review")
    await page.keyboard.press("Enter")      # commit the mission
    await asyncio.sleep(5.0)
    await shot("06_sector")
    for key in ("ArrowRight", "ArrowRight", "Enter"):
        await page.keyboard.press(key)
        await asyncio.sleep(1.6)
    await shot("07_move")
    await browser.close()
    return errors


async def main():
    os.makedirs(OUT, exist_ok=True)
    if not os.path.isdir(BUILD):
        print(f"qa_flow: no build at {BUILD}", file=sys.stderr)
        return 2
    server = subprocess.Popen(
        [sys.executable, "-m", "http.server", PORT],
        cwd=BUILD,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(1)
    bad = 0
    try:
        async with async_playwright() as pw:
            for width, height, tag in ((1280, 720, "hd"), (640, 360, "small")):
                errors = await run(pw, width, height, tag, OUT)
                print(f"{width}x{height}: {len(errors)} error(s)")
                for e in errors[:8]:
                    print("   ", e)
                bad += len(errors)
    finally:
        server.terminate()
    print("qa_flow:", "PASS" if bad == 0 else f"FAIL ({bad} errors)", "->", OUT)
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
