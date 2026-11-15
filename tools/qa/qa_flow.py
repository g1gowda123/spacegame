"""QA flow for the Web build: boot -> callsign -> briefing -> title -> design
-> draft -> review -> sector -> one committed turn, with a capture per screen.

Godot's Web export ignores Playwright's synthetic mouse on Firefox, so every
click is dispatched straight onto the canvas element.

Usage: python3 tools/qa/qa_flow.py [outdir]
"""
import asyncio
import os
import subprocess
import sys
import time

from playwright.async_api import async_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BUILD = os.path.join(ROOT, "build", "web")
OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/opencode/qa_flow"
PORT = "8777"

# Measured orange-button centres at 1280x720 (see docs/QA_REPORT.md).
BTN_BEGIN = (243, 445)
BTN_CONFIRM_DESIGN = (1195, 673)
BTN_COMMIT = (1101, 605)
BTN_SKIP_LAUNCH = (1168, 671)


async def tap(page, x, y):
    await page.evaluate(
        """(pt) => {
            const c = document.querySelector('canvas');
            for (const type of ['pointerdown','pointerup','mousedown','mouseup','click']) {
                const ev = type.startsWith('pointer')
                    ? new PointerEvent(type, {clientX: pt[0], clientY: pt[1], bubbles: true,
                                              pointerId: 1, button: 0, isPrimary: true, buttons: 1})
                    : new MouseEvent(type, {clientX: pt[0], clientY: pt[1], bubbles: true,
                                            button: 0, buttons: 1});
                c.dispatchEvent(ev);
            }
        }""",
        [x, y],
    )


def scale(pt, width, height):
    return (int(pt[0] * width / 1280), int(pt[1] * height / 720))


async def run(pw, width, height, tag, outdir):
    browser = await pw.firefox.launch(headless=True)
    page = await browser.new_page(viewport={"width": width, "height": height})
    errors = []
    page.on("console", lambda m: errors.append(m.text[:200]) if m.type == "error" else None)
    page.on("pageerror", lambda e: errors.append("PAGEERROR " + str(e)[:200]))
    await page.goto(f"http://127.0.0.1:{PORT}/index.html", wait_until="load", timeout=60000)
    for _ in range(60):
        await asyncio.sleep(1)
        if await page.evaluate("() => { const c = document.querySelector('canvas'); return !!(c && c.width > 0); }"):
            break
    await asyncio.sleep(3)

    async def shot(name):
        await page.screenshot(path=os.path.join(outdir, f"{tag}_{name}.png"))

    await tap(page, *scale((640, 660), width, height))
    await asyncio.sleep(1)
    await shot("01_briefing")
    await page.keyboard.press("Enter")      # file the callsign
    await asyncio.sleep(1.6)
    await page.keyboard.press("Escape")     # skip the briefing
    await asyncio.sleep(2.5)
    await shot("02_title")
    # Enter starts the mission from the terminal title (the button moved when
    # the title was rebuilt, so keyboard driving is the stable path).
    await page.keyboard.press("Enter")
    await asyncio.sleep(4)
    await shot("03_design")
    await tap(page, *scale(BTN_CONFIRM_DESIGN, width, height))
    await asyncio.sleep(4)
    await shot("04_draft")
    await page.keyboard.press("Enter")      # open the architecture review
    await asyncio.sleep(3.5)
    await shot("05_review")
    await page.keyboard.press("Enter")      # review owns the keyboard: Enter commits
    await asyncio.sleep(3)
    await shot("06_launch")
    await page.keyboard.press("Escape")     # launch: ESC skips
    await asyncio.sleep(4)
    await shot("07_sector")
    for key in ["ArrowRight", "ArrowRight"]:
        await page.keyboard.press(key)
        await asyncio.sleep(0.7)
    await page.keyboard.press("Enter")
    await asyncio.sleep(3)
    await shot("08_move")
    await browser.close()
    return errors


async def main():
    os.makedirs(OUT, exist_ok=True)
    server = subprocess.Popen([sys.executable, "-m", "http.server", PORT], cwd=BUILD,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1)
    failed = 0
    try:
        async with async_playwright() as pw:
            for width, height in [(1280, 720), (640, 360)]:
                errors = await run(pw, width, height, "hd" if width > 700 else "small", OUT)
                print(f"{width}x{height}: {len(errors)} error(s)")
                for e in errors[:5]:
                    print("   ", e)
                failed += len(errors)
    finally:
        server.terminate()
    print(("qa_flow: PASS -> " if failed == 0 else "qa_flow: FAIL -> ") + OUT)
    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    asyncio.run(main())
