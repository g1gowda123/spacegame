#!/usr/bin/env node
/**
 * Dependency-free browser QA loop for Orbit & Outplay (person d).
 *
 * Uses the Chrome DevTools Protocol over Node's built-in WebSocket + fetch, so
 * it needs no npm install. It serves build/web (or an existing URL), boots the
 * game, walks title -> design -> draft -> sector x3 -> report, captures a
 * screenshot per stage, and fails on page errors.
 *
 * Usage:
 *   node tools/qa/browser_loop.mjs --dir build/web --port 8061 --out qa/artifacts/web
 *   node tools/qa/browser_loop.mjs --url http://localhost:8061 --mode boot
 *   node tools/qa/browser_loop.mjs --self-test          # proves the harness works
 *
 * Options:
 *   --mode boot   boot + one screenshot only (use when the build is new)
 *   --mode loop   full failure-path loop (default)
 *
 * Exit code: 0 = every stage reached with no page errors, 1 = failed.
 */
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");

function arg(name, fallback = null) {
  const i = process.argv.indexOf(`--${name}`);
  if (i === -1) return fallback;
  const next = process.argv[i + 1];
  return next && !next.startsWith("--") ? next : true;
}
const has = (name) => process.argv.includes(`--${name}`);

const PORT = Number(arg("port", 8061));
const DEBUG_PORT = Number(arg("debug-port", PORT + 1));
const OUT = path.resolve(ROOT, String(arg("out", "qa/artifacts/web")));
const MODE = String(arg("mode", "loop"));
const SELF_TEST = has("self-test");
const DIR = arg("dir", null);
const URL_IN = arg("url", null);
const HEADFUL = has("headful");

const CHROME_CANDIDATES = [
  process.env.CHROME_PATH,
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
  "C:/Program Files/Microsoft/Edge/Application/msedge.exe",
  "/usr/bin/google-chrome",
  "/usr/bin/chromium",
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
].filter(Boolean);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function findChrome() {
  const explicit = arg("chrome", null);
  const list = explicit ? [String(explicit), ...CHROME_CANDIDATES] : CHROME_CANDIDATES;
  for (const p of list) if (fs.existsSync(p)) return p;
  throw new Error("Chrome/Edge not found; pass --chrome <path> or set CHROME_PATH");
}

const MIME = {
  ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm",
  ".pck": "application/octet-stream", ".png": "image/png", ".svg": "image/svg+xml",
  ".json": "application/json", ".css": "text/css", ".ico": "image/x-icon",
};

function serveStatic(dir, port) {
  const server = createServer((req, res) => {
    const clean = decodeURIComponent((req.url || "/").split("?")[0]);
    let file = path.join(dir, clean === "/" ? "index.html" : clean);
    if (!file.startsWith(dir)) { res.writeHead(403); res.end(); return; }
    if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, "index.html");
    if (!fs.existsSync(file)) { res.writeHead(404); res.end("not found"); return; }
    res.writeHead(200, {
      "Content-Type": MIME[path.extname(file)] || "application/octet-stream",
      // Godot Web threadless still likes these; harmless for a static host.
      "Cross-Origin-Opener-Policy": "same-origin",
      "Cross-Origin-Embedder-Policy": "require-corp",
    });
    fs.createReadStream(file).pipe(res);
  });
  return new Promise((resolve) => server.listen(port, "127.0.0.1", () => resolve(server)));
}

class CDP {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.pending = new Map();
    this.logs = [];
    this.errors = [];
    ws.addEventListener("message", (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id && this.pending.has(msg.id)) {
        const { resolve, reject } = this.pending.get(msg.id);
        this.pending.delete(msg.id);
        msg.error ? reject(new Error(msg.error.message)) : resolve(msg.result);
        return;
      }
      if (msg.method === "Runtime.consoleAPICalled") {
        const text = (msg.params.args || []).map((a) => a.value ?? a.description ?? "").join(" ");
        this.logs.push(`${msg.params.type}: ${text}`);
        if (msg.params.type === "error") this.errors.push(text);
      } else if (msg.method === "Runtime.exceptionThrown") {
        const d = msg.params.exceptionDetails;
        this.errors.push(d.exception?.description || d.text || "exception");
      } else if (msg.method === "Log.entryAdded") {
        const e = msg.params.entry;
        this.logs.push(`${e.level}: ${e.text}`);
        if (e.level === "error") this.errors.push(e.text);
      }
    });
  }
  send(method, params = {}, sessionId) {
    const id = ++this.id;
    const payload = { id, method, params };
    if (sessionId) payload.sessionId = sessionId;
    this.ws.send(JSON.stringify(payload));
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      setTimeout(() => {
        if (this.pending.has(id)) { this.pending.delete(id); reject(new Error(`CDP timeout: ${method}`)); }
      }, 30000);
    });
  }
}

async function bootBrowser(chrome, url) {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), "qa-chrome-"));
  const args = [
    `--remote-debugging-port=${DEBUG_PORT}`,
    `--user-data-dir=${profile}`,
    "--no-first-run", "--no-default-browser-check", "--disable-extensions",
    "--enable-unsafe-swiftshader", "--window-size=1280,720",
  ];
  if (!HEADFUL) args.push("--headless=new");
  args.push("about:blank");
  const proc = spawn(chrome, args, { stdio: "ignore" });

  let version;
  for (let i = 0; i < 100; i++) {
    try {
      version = await (await fetch(`http://127.0.0.1:${DEBUG_PORT}/json/version`)).json();
      break;
    } catch { await sleep(150); }
  }
  if (!version) throw new Error("Chrome DevTools endpoint did not start");
  const ws = new WebSocket(version.webSocketDebuggerUrl);
  await new Promise((res, rej) => {
    ws.addEventListener("open", res, { once: true });
    ws.addEventListener("error", rej, { once: true });
  });
  const cdp = new CDP(ws);
  const { targetId } = await cdp.send("Target.createTarget", { url });
  const { sessionId } = await cdp.send("Target.attachToTarget", { targetId, flatten: true });
  await cdp.send("Page.enable", {}, sessionId);
  await cdp.send("Runtime.enable", {}, sessionId);
  await cdp.send("Log.enable", {}, sessionId);
  await cdp.send("Emulation.setDeviceMetricsOverride",
    { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false }, sessionId);
  return { proc, cdp, sessionId, profile };
}

/** Best-effort teardown. Chrome can hold its profile briefly on Windows, so
 *  cleanup must never turn a passing QA run into a failure. */
async function shutdown(proc, server, profile) {
  try { proc.kill(); } catch {}
  await sleep(400);
  try { server?.close(); } catch {}
  for (let i = 0; i < 6; i++) {
    try {
      fs.rmSync(profile, { recursive: true, force: true, maxRetries: 3, retryDelay: 200 });
      return;
    } catch {
      await sleep(400);
    }
  }
  console.warn(`note: could not remove temp profile ${profile}`);
}

async function evaluate(cdp, sessionId, expression) {
  const r = await cdp.send("Runtime.evaluate",
    { expression, returnByValue: true, awaitPromise: true }, sessionId);
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.text);
  return r.result?.value;
}

async function shot(cdp, sessionId, name) {
  const { data } = await cdp.send("Page.captureScreenshot", { format: "png" }, sessionId);
  const file = path.join(OUT, `${name}.png`);
  fs.writeFileSync(file, Buffer.from(data, "base64"));
  return file;
}

const KEYS = {
  Enter: { key: "Enter", code: "Enter", windowsVirtualKeyCode: 13, nativeVirtualKeyCode: 13 },
  Space: { key: " ", code: "Space", windowsVirtualKeyCode: 32, nativeVirtualKeyCode: 32 },
  Escape: { key: "Escape", code: "Escape", windowsVirtualKeyCode: 27, nativeVirtualKeyCode: 27 },
};

async function press(cdp, sessionId, name, holdMs = 40) {
  const k = KEYS[name];
  await cdp.send("Input.dispatchKeyEvent", { type: "keyDown", ...k }, sessionId);
  await sleep(holdMs);
  await cdp.send("Input.dispatchKeyEvent", { type: "keyUp", ...k }, sessionId);
  await sleep(120);
}

/** Click at a logical (640x360) game coordinate, mapped through the canvas rect. */
async function clickLogical(cdp, sessionId, x, y) {
  const pt = await evaluate(cdp, sessionId, `(() => {
    const c = document.querySelector('canvas');
    if (!c) return null;
    const r = c.getBoundingClientRect();
    return { x: r.left + r.width * (${x} / 640), y: r.top + r.height * (${y} / 360) };
  })()`);
  if (!pt) throw new Error("canvas not found");
  for (const type of ["mousePressed", "mouseReleased"]) {
    await cdp.send("Input.dispatchMouseEvent",
      { type, x: pt.x, y: pt.y, button: "left", clickCount: 1 }, sessionId);
  }
  await sleep(350);
}

async function waitForGame(cdp, sessionId, timeoutMs = 90000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const state = await evaluate(cdp, sessionId, `(() => {
      const canvas = document.querySelector('canvas');
      if (!canvas) return { ready: false, why: 'no canvas' };
      const status = document.querySelector('#status');
      const notice = document.querySelector('#status-notice');
      const bar = document.querySelector('#status-progress');
      const visible = (el) => el && getComputedStyle(el).display !== 'none' && el.offsetParent !== null;
      return {
        ready: canvas.width > 0 && canvas.height > 0 && !visible(status),
        why: visible(bar) ? 'loading' : (notice && notice.textContent.trim() ? notice.textContent.trim() : 'booting'),
      };
    })()`).catch(() => null);
    if (state?.ready) return state;
    if (state?.why && /failed|error/i.test(state.why)) throw new Error(`boot failed: ${state.why}`);
    await sleep(500);
  }
  throw new Error("game did not finish booting");
}

async function selfTest() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "qa-stub-"));
  fs.writeFileSync(path.join(dir, "index.html"), `<!doctype html>
<meta charset="utf-8"><title>QA harness self-test</title>
<style>html,body{margin:0;background:#070a11}canvas{width:1280px;height:720px;display:block}</style>
<canvas width="640" height="360"></canvas>
<script>
  const c = document.querySelector('canvas').getContext('2d');
  c.fillStyle = '#0e1624'; c.fillRect(0, 0, 640, 360);
  c.fillStyle = '#54e6d1'; c.font = '32px monospace'; c.fillText('QA HARNESS OK', 160, 190);
  // Deliberate console noise tests the error collector without failing the run.
  console.log('harness self-test booted');
</script>`);
  const server = await serveStatic(dir, PORT);
  const chrome = findChrome();
  fs.mkdirSync(OUT, { recursive: true });
  const { proc, cdp, sessionId, profile } = await bootBrowser(chrome, `http://127.0.0.1:${PORT}/`);
  try {
    await waitForGame(cdp, sessionId, 20000);
    await sleep(300);
    const file = await shot(cdp, sessionId, "selftest");
    const size = fs.statSync(file).size;
    const logged = cdp.logs.some((l) => l.includes("harness self-test booted"));
    console.log(`${size > 2000 && logged ? "PASS" : "FAIL"} self-test -> ${file} (${size} bytes, console captured: ${logged})`);
    return size > 2000 && logged ? 0 : 1;
  } finally {
    await shutdown(proc, server, profile);
  }
}

async function main() {
  if (SELF_TEST) return selfTest();

  let server = null;
  let url = String(URL_IN || `http://127.0.0.1:${PORT}/`);
  if (DIR) {
    const dir = path.resolve(ROOT, String(DIR));
    if (!fs.existsSync(path.join(dir, "index.html"))) {
      throw new Error(`no build at ${dir}/index.html - build/ is gitignored; get an export from c first`);
    }
    server = await serveStatic(dir, PORT);
    url = `http://127.0.0.1:${PORT}/`;
  } else if (!URL_IN) {
    throw new Error("pass --dir build/web (preferred) or --url <hosted build>");
  }

  fs.mkdirSync(OUT, { recursive: true });
  const chrome = findChrome();
  const { proc, cdp, sessionId, profile } = await bootBrowser(chrome, url);
  const stages = [];
  let exitCode = 0;
  try {
    await waitForGame(cdp, sessionId);
    stages.push({ stage: "title", file: await shot(cdp, sessionId, "01-title") });
    if (MODE === "loop") {
      await press(cdp, sessionId, "Enter");
      stages.push({ stage: "design", file: await shot(cdp, sessionId, "02-design") });
      await press(cdp, sessionId, "Enter");
      stages.push({ stage: "draft", file: await shot(cdp, sessionId, "03-draft") });
      await press(cdp, sessionId, "Enter");
      stages.push({ stage: "sector", file: await shot(cdp, sessionId, "04-sector") });

      // Failure-path loop: hold until the sector ends, continue, repeat x3.
      for (let sector = 1; sector <= 3; sector++) {
        for (let turn = 0; turn < 45; turn++) await press(cdp, sessionId, "Space", 25);
        stages.push({ stage: `sector-${sector}-end`, file: await shot(cdp, sessionId, `05-sector-${sector}-end`) });
        await clickLogical(cdp, sessionId, 326, 260);          // CONTINUE TO DEBRIEF
        stages.push({ stage: `debrief-${sector}`, file: await shot(cdp, sessionId, `06-debrief-${sector}`) });
        await clickLogical(cdp, sessionId, 518, 333);          // SELECT NEXT TARGET / FINAL REPORT
        if (sector < 3) {
          stages.push({ stage: `draft-${sector + 1}`, file: await shot(cdp, sessionId, `07-draft-${sector + 1}`) });
          await press(cdp, sessionId, "Enter");               // confirm target -> sector
          stages.push({ stage: `sector-${sector + 1}`, file: await shot(cdp, sessionId, `08-sector-${sector + 1}`) });
        }
      }
      stages.push({ stage: "report", file: await shot(cdp, sessionId, "09-report") });
    }

    const pageErrors = cdp.errors.filter((e) => !/ReadPixels|WebGL|GroupMarkerNotSet/i.test(e));
    const report = { url, mode: MODE, at: new Date().toISOString(), stages, consoleErrors: cdp.errors, pageErrors };
    fs.writeFileSync(path.join(OUT, "report.json"), JSON.stringify(report, null, 2));
    for (const s of stages) console.log(`CAPTURED ${s.stage.padEnd(16)} ${path.relative(ROOT, s.file)}`);
    if (pageErrors.length) {
      console.log(`FAIL ${pageErrors.length} page error(s):`);
      for (const e of pageErrors.slice(0, 8)) console.log(`  ${e.split("\n")[0]}`);
      exitCode = 1;
    } else {
      console.log(`PASS no page errors, ${stages.length} stage capture(s) -> ${path.relative(ROOT, OUT)}`);
    }
    return exitCode;
  } finally {
    await shutdown(proc, server, profile);
  }
}

main().then((code) => process.exit(code)).catch((err) => {
  console.error(`QA browser loop failed: ${err.message}`);
  process.exit(1);
});
