#!/usr/bin/env node
/**
 * Headless browser loop for the Orbit & Outplay Web build.
 *
 * This is person c's release check: it launches Chrome with the DevTools
 * protocol, plays a short all-failure campaign so the run reaches the final
 * report quickly, screenshots every screen, and fails on page errors.
 *
 * Usage:
 *   python -m http.server 8061 --directory build/web
 *   node tools/browser_loop.mjs --url http://127.0.0.1:8061/index.html --out demo/capture/web
 *
 * Requires Node 22+ (global fetch + WebSocket) and Chrome/Edge installed.
 * No npm packages.
 *
 * Coordinates below are logical game coordinates (640x360). The canvas is
 * forced to 1280x720 via Emulation.setDeviceMetricsOverride so the scale is a
 * clean 2x, and the canvas rect is re-read before every click (Godot resizes
 * the canvas after boot; a cached rect silently sends every click to the
 * top-left corner).
 */

import { spawn } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

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
const URL = args.url ?? "http://127.0.0.1:8061/index.html";
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
  `http://127.0.0.1:${PORT}/json/new?${encodeURIComponent(URL)}`,
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

async function screenshot(name) {
  const shot = await send("Page.captureScreenshot", { format: "png" });
  const file = path.join(OUT, name);
  fs.writeFileSync(file, Buffer.from(shot.data, "base64"));
  console.log(`shot ${name}`);
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

await send("Page.enable");
await send("Runtime.enable");
await send("Log.enable");
// Fixed 1280x720 viewport => clean 2x logical mapping and 720p screenshots.
await send("Emulation.setDeviceMetricsOverride", {
  width: W, height: H, deviceScaleFactor: 1, mobile: false,
});
console.log(`loading ${URL}`);

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

const shots = [];
async function beat(name, wait = 2200) {
  await screenshot(name);
  shots.push(name);
  await sleep(wait);
}

// Title screen.
await beat("01_title.png", 1200);

// BEGIN MISSION -> design
await clickLogical(132, 254);
await beat("02_design.png", 1800);

// QUICK LOADOUT fills a legal loadout, then CONFIRM -> draft
await clickLogical(153, 338);
await sleep(700);
await beat("03_design_filled.png", 700);
await clickLogical(514, 338);
await beat("04_draft.png", 2000);

// SET COURSE -> sector 1
await clickLogical(557, 299);
await sleep(6500);
await beat("05_sector.png", 800);

// Arrow keys preview a path, MOVE commits one turn, then bail out early.
await key("ArrowRight", "ArrowRight", 39);
await key("ArrowRight", "ArrowRight", 39);
await sleep(700);
await beat("06_path_preview.png", 300);
await clickLogical(498, 279); // MOVE (ENTER)
await sleep(1800);
await beat("07_turn_committed.png", 300);
await clickLogical(498, 331); // EXTRACT (E) -> deliberate failure
await sleep(2200);
await beat("08_sector_result.png", 600);

// Result overlay -> debrief
await clickLogical(320, 255);
await beat("09_debrief.png", 1800);

// Remaining sectors: straight to the surface, extract immediately, debrief.
for (let sector = 2; sector <= 3; sector += 1) {
  await clickLogical(511, 327); // SELECT NEXT TARGET
  await sleep(2200);
  await beat(`10_draft_s${sector}.png`, 600);
  await clickLogical(557, 299); // SET COURSE
  await sleep(6000);
  await beat(`11_sector_s${sector}.png`, 400);
  await clickLogical(498, 331); // EXTRACT immediately
  await sleep(2200);
  await beat(`12_result_s${sector}.png`, 400);
  await clickLogical(320, 255); // CONTINUE TO DEBRIEF
  await sleep(2000);
  await beat(`13_debrief_s${sector}.png`, 600);
}

// FILE FINAL REPORT
await clickLogical(511, 327);
await sleep(2600);
await beat("14_report.png", 400);

const summary = {
  url: URL,
  canvas: rect,
  shots,
  pageErrors,
  consoleErrors,
  consoleWarnings: consoleWarnings.slice(0, 20),
};
fs.writeFileSync(path.join(OUT, "report.json"), JSON.stringify(summary, null, 2));
console.log(JSON.stringify({ shots: shots.length, pageErrors, consoleErrors, consoleWarnings: summary.consoleWarnings }, null, 2));

ws.close();
chrome.kill();
await sleep(500);
try { fs.rmSync(profile, { recursive: true, force: true }); } catch { /* best effort */ }
process.exit(pageErrors.length || consoleErrors.length ? 1 : 0);
