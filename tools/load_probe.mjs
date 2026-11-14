// Time-to-title probe for the Web build (queue item C3).
// Measures, in wall-clock ms from navigation start:
//   wasm-runtime  - canvas reaches the viewport size (#status gone)
//   first-frame   - first screenshot whose bytes differ from the boot frame
//   title-frame   - first screenshot that is stable for 500 ms (title painted)
import { spawn } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const URL = process.argv[2] ?? "http://127.0.0.1:8061/index.html";
const PORT = 9345;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const profile = fs.mkdtempSync(path.join(os.tmpdir(), "load-"));
const chrome = spawn("C:/Program Files/Google/Chrome/Application/chrome.exe", [
  "--headless=new", "--enable-unsafe-swiftshader", "--hide-scrollbars", "--mute-audio",
  `--remote-debugging-port=${PORT}`, `--user-data-dir=${profile}`, "--window-size=1280,720", "about:blank",
], { stdio: ["ignore", "ignore", "pipe"] });

for (let i = 0; i < 120; i += 1) {
  try { const r = await fetch(`http://127.0.0.1:${PORT}/json/version`); if (r.ok) break; } catch { /* wait */ }
  await sleep(200);
}
const target = await (await fetch(`http://127.0.0.1:${PORT}/json/new?about:blank`, { method: "PUT" })).json();
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((res, rej) => {
  ws.addEventListener("open", res, { once: true });
  ws.addEventListener("error", rej, { once: true });
});
let id = 0;
const pending = new Map();
ws.addEventListener("message", (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) {
    const p = pending.get(m.id);
    pending.delete(m.id);
    m.error ? p.rej(new Error(JSON.stringify(m.error))) : p.res(m.result);
  }
});
const send = (method, params = {}) => new Promise((res, rej) => {
  const i = ++id;
  pending.set(i, { res, rej });
  ws.send(JSON.stringify({ id: i, method, params }));
});

await send("Page.enable");
await send("Runtime.enable");
await send("Emulation.setDeviceMetricsOverride", { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });

const t0 = Date.now();
await send("Page.navigate", { url: URL });

const rect = async () => {
  const r = await send("Runtime.evaluate", {
    expression: `(() => { const c = document.querySelector("canvas"); if (!c) return null; const r = c.getBoundingClientRect(); return { w: r.width, h: r.height, s: !!document.getElementById("status") }; })()`,
    returnByValue: true,
  });
  return r.result?.value ?? null;
};
const shot = async () => (await send("Page.captureScreenshot", { format: "png" })).data;

let runtimeMs = null;
let firstFrameMs = null;
let titleMs = null;
let last = null;
let stableSince = null;

while (Date.now() - t0 < 60000) {
  if (runtimeMs === null) {
    const r = await rect();
    if (r && r.w >= 600 && r.s === false) runtimeMs = Date.now() - t0;
  }
  const data = await shot();
  const now = Date.now() - t0;
  if (firstFrameMs === null && last !== null && data !== last) firstFrameMs = now;
  if (data === last) {
    if (stableSince === null) stableSince = now;
    if (titleMs === null && now - stableSince > 500 && firstFrameMs !== null) titleMs = stableSince;
  } else {
    stableSince = null;
  }
  last = data;
  if (titleMs !== null) break;
  await sleep(120);
}

console.log(JSON.stringify({
  url: URL,
  wasm_runtime_ms: runtimeMs,
  first_drawn_frame_ms: firstFrameMs,
  title_painted_ms: titleMs,
}, null, 2));
ws.close();
chrome.kill();
await sleep(300);
try { fs.rmSync(profile, { recursive: true, force: true }); } catch { /* best effort */ }
