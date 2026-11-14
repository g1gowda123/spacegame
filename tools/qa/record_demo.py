#!/usr/bin/env python3
"""Record the submission demo from the current Web build.

Walks the judged flow (callsign -> briefing -> title -> design -> draft ->
review -> sector turns) in a recording browser context and saves one still per
beat, plus the raw video. Cutting/trimming to <30 s is a separate ffmpeg step.

Usage: python3 tools/qa/record_demo.py [outdir]
"""
import asyncio
import os
import subprocess
import sys
import time

from playwright.async_api import async_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BUILD = os.path.join(ROOT, "build", "web")
OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/opencode/demo_rec"
PORT = "8899"


async def main():
    os.makedirs(OUT, exist_ok=True)
    server = subprocess.Popen(
        [sys.executable, "-m", "http.server", PORT],
        cwd=BUILD,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(1)
    marks, errors = [], []
    try:
        async with async_playwright() as pw:
            browser = await pw.firefox.launch(headless=True)
            ctx = await browser.new_context(
                viewport={"width": 1280, "height": 720},
                record_video_dir=os.path.join(OUT, "video"),
                record_video_size={"width": 1280, "height": 720},
            )
            page = await ctx.new_page()
            video = page.video
            page.on("console", lambda m: errors.append(m.text[:160]) if m.type == "error" else None)
            page.on("pageerror", lambda e: errors.append("PAGEERROR " + str(e)[:160]))
            await page.goto(f"http://127.0.0.1:{PORT}/index.html", wait_until="load", timeout=60000)
            for _ in range(60):
                await asyncio.sleep(1)
                if await page.evaluate("() => { const c=document.querySelector('canvas'); return !!(c && c.width>0); }"):
                    break
            t0 = time.time()

            async def mark(name):
                await page.screenshot(path=os.path.join(OUT, f"{name}.png"))
                marks.append((name, round(time.time() - t0, 1)))

            await asyncio.sleep(3)
            await page.mouse.click(640, 660)
            await asyncio.sleep(2.0)
            await mark("01_callsign")
            await page.keyboard.press("Enter")
            await asyncio.sleep(2.4)
            await mark("02_brief")
            await page.keyboard.press("Escape")
            await asyncio.sleep(2.5)
            await mark("03_title")
            await page.mouse.click(180, 353)
            await asyncio.sleep(5.0)
            await mark("04_design")
            await page.keyboard.press("Enter")
            await asyncio.sleep(4.5)
            await mark("05_draft")
            await page.keyboard.press("Enter")
            await asyncio.sleep(4.5)
            await mark("06_review")
            await page.keyboard.press("Enter")
            await asyncio.sleep(5.5)
            await mark("07_sector")
            for i, key in enumerate(["ArrowRight", "ArrowRight", "Enter", "ArrowDown", "Enter", "ArrowRight", "Enter"]):
                await page.keyboard.press(key)
                await asyncio.sleep(1.6)
                if key == "Enter":
                    await mark(f"08_turn{i}")
            await asyncio.sleep(1.5)
            await mark("09_end")
            path = await video.path()
            await ctx.close()
            await browser.close()
            target = os.path.join(OUT, "raw.webm")
            os.replace(path, target)
    finally:
        server.terminate()
    print("errors:", len(errors), errors[:3])
    for name, t in marks:
        print(f"MARK {name} {t}")


if __name__ == "__main__":
    asyncio.run(main())
