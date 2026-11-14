#!/usr/bin/env node
/**
 * Headless browser loop for the Orbit & Outplay Web build.
 *
 * This is person c's release check: it launches Chrome with the DevTools
 * protocol, plays a short all-failure campaign so the run reaches the final
 * report quickly, screenshots every screen, and fails on page errors.
 *
 *   python -m http.server 8061 --directory build/web
 *   node tools/browser_loop.mjs --url http://127.0.0.1:8061/index.html --out demo/capture/web
 *
 * Requires Node 22+ (global fetch + WebSocket) and Chrome/Edge installed.
 * No npm packages.
 *
 * Coordinates are logical game coordinates (640x360), matching the Control
 * positions in scripts/*.gd. The canvas is forced to 1280x720 via
 * Emulation.setDeviceMetricsOverride so the scale is a clean 2x, and the
 * canvas rect is re-read before every click: Godot boots at 300x150 and only
 * resizes after the WASM runtime starts, so a cached rect sends every click to
 * the top-left corner.
 *
 * Every navigation is asserted: the loop keeps a coarse pixel signature of the
 * last screen (PNG decoded with node:zlib, 16x9 cell averages) and fails if a
 * click does not change the screen. That turns "the loop ran" into "the loop
 * reached the report", which is what QA actually needs.
 */

import { spawn } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import zlib from "node:zlib";

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (!a.startsWith("--")) continue;
    const key = a.slice(2);
    const next = argv[i + 1];
    if (next && !next.startsWith("--")) { out[key] = next; i += 1; }
    else out[key] = true;
  }
  return out;
}

const args = parseArgs(process.argv.slice(2));
const URL_ARG = args.url ?? "http://127.0.0.1:8061/index.html";
const OUT = path.resolve(args.out ?? "demo/capture/web");
const W = Number(args.width ?? 1280);
const H = Number(args.height ?? 720);
const PORT = Number(args.port ?? 9223);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function findChrome() {
  const candidates = [
    process.env.CHROME,
    "C:/Program Files/Google/Chrome/Application/chrome.exe",
    "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
    "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
    "C:/Program Files/Microsoft/Edge/Application/msedge.exe",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  ].filter(Boolean);
  for (const c of candidates) if (fs.existsSync(c)) return c;
  throw new Error("Chrome/Edge not found; pass --chrome <path> or set CHROME");
}

/** Minimal PNG -> RGBA decoder (8-bit RGB/RGBA, the two types Chrome emits). */
function decodePng(buf) {
  let pos = 8;
  let w = 0, h = 0, colorType = 6;
  const idat = [];
  while (pos + 8 <= buf.length) {
    const len = buf.readUInt32BE(pos);
    const type = buf.toString("ascii", pos + 4, pos + 8);
    const data = buf.subarray(pos + 8, pos + 8 + len);
    if (type === "IHDR") {
      w = data.readUInt32BE(0);
      h = data.readUInt32BE(4);
      colorType = data[9];
    } else if (type === "IDAT") {
      idat.push(data);
    } else if (type === "IEND") break;
    pos += 12 + len;
  }
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const bpp = colorType === 6 ? 4 : colorType === 2 ? 3 : 1;
  const stride = w * bpp;
  const out = Buffer.alloc(h * stride);
  let p = 0;
  for (let y = 0; y < h; y += 1) {
    const filter = raw[p]; p += 1;
    const row = out.subarray(y * stride, (y + 1) * stride);
    const prev = y ? out.subarray((y - 1) * stride, y * stride) : null;
    for (let x = 0; x < stride; x += 1) {
      const a = x >= bpp ? row[x - bpp] : 0;
      const b = prev ? prev[x] : 0;
      const c = prev && x >= bpp ? prev[x - bpp] : 0;
      let v = raw[p + x];
      if (filter === 1) v += a;
      else if (filter === 2) v += b;
      else if (filter === 3) v += (a + b) >> 1;
      else if (filter === 4) {
        const q = a + b - c;
        const pa = Math.abs(q - a), pb = Math.abs(q - b), pc = Math.abs(q - c);
        v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
      }
      row[x] = v & 0xff;
    }
    p += stride;
  }
  return { w, h, bpp, data: out };
}

/** 16x9 grid of cell averages, quantised to 5 bits per channel. */
function signature(pngBuf) {
  const { w, h, bpp, data } = decodePng(pngBuf);
  const GX = 16, GY = 9;
  const sig = [];
  for (let gy = 0; gy < GY; gy += 1) {
    for (let gx = 0; gx < GX; gx += 1) {
      const x0 = Math.floor((gx * w) / GX), x1 = Math.floor(((gx + 1) * w) / GX);
      const y0 = Math.floor((gy * h) / GY), y1 = Math.floor(((gy + 1) * h) / GY);
      let r = 0, g = 0, b = 0, n = 0;
      for (let y = y0; y < y1; y += 3) {
        for (let x = x0; x < x1; x += 3) {
          const i = (y * w + x) * bpp;
          r += data[i]; g += data[i + 1]; b += data[i + 2]; n += 1;
        }
      }
      n = n || 1;
      sig.push((r / n) >> 3, (g / n) >> 3, (b / n) >> 3);
    }
  }
  return sig;
}

/** Same screen: >=92% of cells within 16/255 per channel (starfield noise OK). */
function sameScreen(a, b) {
  if (!a || !b || a.length !== b.length) return false;
  let close = 0;
  const cells = a.length / 3;
  for (let i = 0; i < a.length; i += 3) {
    const d = Math.max(
      Math.abs(a[i] - b[i]),
      Math.abs(a[i + 1] - b[i + 1]),
      Math.abs(a[i + 2] - b[i + 2]),
    );
    if (d <= 2) close += 1;
  }
  return close / cells >= 0.92;
}

const chromePath = args.chrome ?? findChrome();
fs.mkdirSync(OUT, { recursive: true });
const profile = fs.mkdtempSync(path.join(os.tmpdir(), "orbit-web-"));
const chrome = spawn(chromePath, [
  "--headless=new",
  "--enable-unsafe-swiftshader",
  "--hide-scrollbars",
  "--mute-audio",
  `--remote-debugging-port=${PORT}`,
  `--user-data-dir=${profile}`,
  `--window-size=${W},${H}`,
  "about:blank",
], { stdio: ["ignore", "ignore", "pipe"] });

const pageErrors = [];
const consoleErrors = [];
const consoleWarnings = [];

async function waitForDevtools() {
  for (let i = 0; i < 120; i += 1) {
    try {
      const res = await fetch(`http://127.0.0.1:${PORT}/json/version`);
      if (res.ok) return;
    } catch { /* not up yet */ }
    await sleep(250);
  }
  throw new Error("DevTools endpoint did not start");
}

await waitForDevtools();
const targetRes = await fetch(
  `http://127.0.0.1:${PORT}/json/new?${encodeURIComponent(URL_ARG)}`,
  { method: "PUT" },
);
const target = await targetRes.json();
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  ws.addEventListener("open", resolve, { once: true });
  ws.addEventListener("error", reject, { once: true });
});

let nextId = 0;
const pending = new Map();
ws.addEventListener("message", (event) => {
  const msg = JSON.parse(event.data);
  if (msg.id && pending.has(msg.id)) {
    const { resolve, reject } = pending.get(msg.id);
    pending.delete(msg.id);
    if (msg.error) reject(new Error(JSON.stringify(msg.error)));
    else resolve(msg.result);
    return;
  }
  if (msg.method === "Runtime.exceptionThrown") {
    pageErrors.push(msg.params?.exceptionDetails?.exception?.description
      ?? msg.params?.exceptionDetails?.text ?? "exception");
  }
  if (msg.method === "Runtime.consoleAPICalled") {
    const text = (msg.params?.args ?? []).map((a) => a.value ?? a.description ?? "?").join(" ");
    if (msg.params.type === "error") consoleErrors.push(text);
    else if (msg.params.type === "warning") consoleWarnings.push(text);
  }
  if (msg.method === "Log.entryAdded") {
    const entry = msg.params.entry;
    if (entry.level === "error") consoleErrors.push(`${entry.source}: ${entry.text}`);
    else if (entry.level === "warning") consoleWarnings.push(`${entry.source}: ${entry.text}`);
  }
});

function send(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = ++nextId;
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params }));
  });
}

async function evaluate(expression) {
  const res = await send("Runtime.evaluate", {
    expression,
    returnByValue: true,
    awaitPromise: true,
  });
  if (res.exceptionDetails) throw new Error(res.exceptionDetails.text ?? "eval failed");
  return res.result?.value;
}

async function rawShot() {
  const shot = await send("Page.captureScreenshot", { format: "png" });
  return Buffer.from(shot.data, "base64");
}

const shots = [];
let lastSig = null;

async function screenshot(name) {
  const buf = await rawShot();
  fs.writeFileSync(path.join(OUT, name), buf);
  lastSig = signature(buf);
  shots.push(name);
  console.log(`shot ${name}`);
  return lastSig;
}

async function canvasRect() {
  return evaluate(`(() => {
    const c = document.querySelector("canvas");
    if (!c) return null;
    const r = c.getBoundingClientRect();
    return { x: r.x, y: r.y, w: r.width, h: r.height, cw: c.width, ch: c.height };
  })()`);
}

async function clickLogical(lx, ly) {
  const rect = await canvasRect();
  if (!rect || rect.w < 100) throw new Error("canvas not sized");
  const x = rect.x + (lx / 640) * rect.w;
  const y = rect.y + (ly / 360) * rect.h;
  await send("Input.dispatchMouseEvent", { type: "mouseMoved", x, y });
  await sleep(40);
  await send("Input.dispatchMouseEvent", {
    type: "mousePressed", x, y, button: "left", buttons: 1, clickCount: 1,
  });
  await sleep(90);
  await send("Input.dispatchMouseEvent", {
    type: "mouseReleased", x, y, button: "left", buttons: 0, clickCount: 1,
  });
  await sleep(120);
  console.log(`click (${lx}, ${ly}) -> page (${x.toFixed(0)}, ${y.toFixed(0)})`);
}

/** Mean brightness of a signature (used to spot the dimmed result overlay). */
function meanLuma(sig) {
  let sum = 0;
  for (let i = 0; i < sig.length; i += 3) sum += sig[i] + sig[i + 1] + sig[i + 2];
  return sum / (sig.length / 3);
}

/**
 * End a sector without playing it well.
 *
 * EXTRACT now refuses until the data quota is met AND the ship is back on the
 * landing zone (sector.gd:_extract), so the old "extract immediately" path is
 * gone. Every step costs one delta-v and one sol and the mission ends when
 * either runs out, so a four-way circuit (net drift zero, so the ship stays on
 * the map) is a legal way to reach the result overlay on the all-failure path
 * this check wants. 34 steps covers the worst case (sols 31) with margin; once
 * the mission is done the remaining clicks are inert because sector.gd guards
 * move/extract with `if done: return`.
 */
const ARROWS = {
  ArrowRight: 39, ArrowLeft: 37, ArrowUp: 38, ArrowDown: 40,
};

async function endSectorByAttrition(tag, steps = 34) {
  const dirs = ["ArrowRight", "ArrowDown", "ArrowLeft", "ArrowUp"];
  for (let i = 0; i < steps; i += 1) {
    const dir = dirs[i % dirs.length];
    await key(dir, dir, ARROWS[dir]);
    await clickLogical(...HIT.move);
    await sleep(350);
  }
  console.log(`ok   ${tag}: ${steps} moves walked (delta-v / sols should be gone)`);
  return true;
}

async function key(keyName, code, vk) {
  await send("Input.dispatchKeyEvent", {
    type: "keyDown", key: keyName, code, windowsVirtualKeyCode: vk, nativeVirtualKeyCode: vk,
  });
  await sleep(70);
  await send("Input.dispatchKeyEvent", {
    type: "keyUp", key: keyName, code, windowsVirtualKeyCode: vk, nativeVirtualKeyCode: vk,
  });
  await sleep(70);
}

/** Poll until the screen differs from the last screenshot. Throws on timeout. */
async function expectChange(label, timeoutMs = 4000) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeoutMs) {
    const sig = signature(await rawShot());
    if (!sameScreen(lastSig, sig)) {
      lastSig = sig;
      console.log(`ok   ${label} (${Date.now() - t0} ms)`);
      return true;
    }
    await sleep(150);
  }
  throw new Error(`screen did not change after: ${label}`);
}

/** Poll until the screen matches the last screenshot; returns false on timeout. */
async function expectStill(label, timeoutMs = 2500) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeoutMs) {
    const sig = signature(await rawShot());
    if (!sameScreen(lastSig, sig)) return false;
    await sleep(150);
  }
  console.log(`ok   ${label} (screen stayed put)`);
  return true;
}

/** expectChange, but reports false instead of throwing. */
async function expectChangeAllowFail(label, timeoutMs = 4000) {
  try {
    await expectChange(label, timeoutMs);
    return true;
  } catch {
    console.log(`skip ${label} (no change)`);
    return false;
  }
}

await send("Page.enable");
await send("Runtime.enable");
await send("Log.enable");
// Fixed 1280x720 viewport => clean 2x logical mapping and 720p screenshots.
await send("Emulation.setDeviceMetricsOverride", {
  width: W, height: H, deviceScaleFactor: 1, mobile: false,
});
console.log(`loading ${URL_ARG}`);

// Wait for the engine to boot: Godot removes the #status boot overlay and
// resizes the canvas to the viewport once the runtime is up.
let rect = null;
for (let i = 0; i < 240; i += 1) {
  const status = await evaluate(`!!document.getElementById("status")`);
  rect = await canvasRect();
  if (status === false && rect && rect.w >= 600) break;
  await sleep(250);
}
if (!rect || rect.w < 600) throw new Error("canvas never sized up");
console.log(`canvas ${rect.cw}x${rect.ch} css ${rect.w}x${rect.h}`);
// SwiftShader compiles shaders on first draw; give it real time.
await sleep(12000);

// --- Screen coordinates (logical 640x360) -------------------------------
const HIT = {
  callsignFile: [210, 204], // briefing.gd callsign sheet (110,82)+(18,110) 164x24
  briefingSkip: [576, 42],  // briefing.gd SKIP [ESC] (530,32) 92x20
  begin: [124, 243],        // title.gd BEGIN MISSION (44,228) 160x30
  quick: [153, 338],        // design.gd QUICK LOADOUT (90,326) 126x24
  confirmDesign: [514, 338],// design.gd CONFIRM & DRAFT ... (398,326) 232x24
  setCourse: [557, 299],    // draft.gd SET COURSE > footer (10,282)+(482,6) 130x22
  commitMission: [526, 296],// draft.gd COMMIT MISSION > review (20,24)+(426,260)
  move: [494, 279],         // sector.gd MOVE (444,268) 100x22
  extract: [494, 331],      // sector.gd EXTRACT (444,320) 100x22
  continueOverlay: [320, 253], // sector.gd CONTINUE TO DEBRIEF > (150,70)+(70,170)
  // debrief.gd footer button (398,9) inside the (10,304) panel, 206x28.
  // HANDLE EVENT > / CLAIM COMMISSION > / SELECT NEXT TARGET > / FILE FINAL
  // REPORT > all live here. Left third on purpose: the report screen's
  // NEW CAMPAIGN > starts at x=456, so a stray click cannot restart a run.
  debriefNext: [511, 327],
  eventChoice0: [484, 166], // debrief.gd modal option 0 CHOOSE (96,44)+(318+86/2, ...)
  commissionCard1: [150, 177], // buff.gd first card (150,143)+303x423
};

// --- Flow --------------------------------------------------------------
// 1. First run boots the Agency Induction (title.gd defers to briefing.tscn
//    while GameState.briefing_seen is false, and a fresh profile always is).
//    The callsign sheet is a modal over the briefing, so it has to be filed
//    before SKIP is clickable. Filing it keeps the default name CHIEF.
await screenshot("00_briefing.png");
await clickLogical(...HIT.callsignFile);
await expectChange("callsign -> briefing");
await clickLogical(...HIT.briefingSkip);
await expectChange("briefing -> title");
await screenshot("01_title.png");

// 2. Title -> design -> draft.
await clickLogical(...HIT.begin);
await expectChange("title -> design");
await screenshot("02_design.png");

await clickLogical(...HIT.quick);
await sleep(600);
await screenshot("03_design_filled.png");
await clickLogical(...HIT.confirmDesign);
await expectChange("design -> draft");
await screenshot("04_draft.png");

// 3. Draft -> mission architecture review -> sector 1.
await clickLogical(...HIT.setCourse);
await expectChange("draft -> review");
await screenshot("05_review.png");
await clickLogical(...HIT.commitMission);
await expectChange("review -> sector", 20000);
await screenshot("06_sector.png");

// 4. Arrow keys preview a path, then the sector is walked until the mission
//    window closes (delta-v / sols run out) or the hull goes; EXTRACT is no
//    longer allowed before the quota is met, so attrition is the legal way to
//    reach the result overlay.
await key("ArrowRight", "ArrowRight", 39);
await key("ArrowRight", "ArrowRight", 39);
await sleep(600);
await screenshot("07_path_preview.png");
await clickLogical(...HIT.move);
await sleep(1200);
await screenshot("08_turn_committed.png");
if (!(await endSectorByAttrition("s1"))) {
  throw new Error("sector 1 never ended: neither delta-v, sols nor hull ran out");
}
await screenshot("09_sector_result.png");

// 5. Result overlay -> debrief 01.
await clickLogical(...HIT.continueOverlay);
await expectChange("result -> debrief");
await screenshot("10_debrief.png");

// 6. Debrief -> next draft. Every continuing debrief rolls an agency event
//    (game_state.gd roll_event) and the field-commission screen can sit
//    between debrief and draft, so the ladder is: footer button, then the
//    modal's option 0, then the commission's first card. Each of those points
//    is inert on screens where it does not apply, and every step is verified
//    by the next click having to change the screen.
async function leaveDebrief(tag, sector) {
  await clickLogical(...HIT.debriefNext);
  await expectChange(`debrief -> event/commission/draft (s${sector})`);
  await clickLogical(...HIT.eventChoice0);
  await sleep(1000);
  await clickLogical(...HIT.commissionCard1);
  await sleep(1200);
  await screenshot(`${tag}_draft_s${sector}.png`);
}

let reachedReport = false;
for (let sector = 2; sector <= 3; sector += 1) {
  await leaveDebrief("11", sector);
  await clickLogical(...HIT.setCourse);
  // If the agency collapsed (approval <= 0) the debrief routes straight to the
  // report, so SET COURSE lands on a screen with no such button.
  if (!(await expectChangeAllowFail(`draft -> review (s${sector})`, 3000))) {
    console.log("agency collapsed before the draft; the run ended early");
    break;
  }
  await screenshot(`12_review_s${sector}.png`);
  await clickLogical(...HIT.commitMission);
  await expectChange(`review -> sector (s${sector})`, 20000);
  await screenshot(`13_sector_s${sector}.png`);
  if (!(await endSectorByAttrition(`s${sector}`))) {
    throw new Error(`sector ${sector} never ended`);
  }
  await screenshot(`14_result_s${sector}.png`);
  await clickLogical(...HIT.continueOverlay);
  await expectChange(`result -> debrief (s${sector})`);
  await screenshot(`15_debrief_s${sector}.png`);
}

// 7. FILE FINAL REPORT.
await clickLogical(...HIT.debriefNext);
if (await expectChangeAllowFail("debrief -> report", 6000)) {
  await screenshot("16_report.png");
  reachedReport = true;
  // The report is terminal: the footer point must not do anything any more.
  // If it still advances, the loop is actually sitting on a debrief.
  if (!(await expectStill("report is terminal"))) {
    throw new Error("footer still advances: this is not the report screen");
  }
} else {
  await screenshot("16_report.png");
  throw new Error("final debrief click did not open the report");
}

const summary = {
  url: URL_ARG,
  canvas: rect,
  shots,
  reachedReport,
  pageErrors,
  consoleErrors,
  consoleWarnings: consoleWarnings.slice(0, 20),
};
fs.writeFileSync(path.join(OUT, "report.json"), JSON.stringify(summary, null, 2));
console.log(JSON.stringify({
  shots: shots.length,
  reachedReport,
  pageErrors,
  consoleErrors,
  consoleWarnings: summary.consoleWarnings,
}, null, 2));

ws.close();
chrome.kill();
await sleep(500);
try { fs.rmSync(profile, { recursive: true, force: true }); } catch { /* best effort */ }
process.exit(pageErrors.length || consoleErrors.length || !reachedReport ? 1 : 0);
