// What does a browser player actually get? (ship W1, round 17.)
//
// Usage: node observe.mjs <url> <out-dir> [options]
//   --seconds=N        how long to watch after the game's READY marker (default 40)
//   --shots=S          a screenshot every S seconds (default 5)
//   --keys=K@T,...     press key K T seconds after READY (e.g. Space@6 to leave the planning pause)
//   --clicks=X:Y@T,... click the canvas at (X, Y) T seconds after READY
//   --mbps=N           throttle the network to N Mbit/s down (CDP), to time the first load on a stated connection
//   --size=WxH         viewport (default 1280x720)
//
// Writes <out-dir>/report.json (timings, console, failed requests, the audio timeline), <out-dir>/console.txt and
// <out-dir>/shot_<t>.png. Exits 0 unless the harness itself failed: this is an instrument, not a gate.
//
// THE AUDIO TAP. Headless Chrome has no speaker, but WebAudio still renders: every node Godot connects to the
// context's destination is routed through an AnalyserNode first (AudioNode.prototype.connect is wrapped before the
// page's scripts run), and the page samples its RMS every 250 ms. So "did anything sound" is a measured dBFS
// timeline, not a guess. Chrome is launched with autoplay allowed and the canvas is clicked once (a user gesture),
// as a player's first tap would be.
import fs from "node:fs";
import path from "node:path";
import puppeteer from "puppeteer-core";

const [url, outDir, ...rest] = process.argv.slice(2);
if (!url || !outDir) {
  console.error("usage: node observe.mjs <url> <out-dir> [--seconds=N] [--shots=S] [--keys=K@T,..] [--mbps=N]");
  process.exit(2);
}
const opt = Object.fromEntries(rest.map((a) => a.replace(/^--/, "").split("=")));
const seconds = Number(opt.seconds ?? 40);
const shotEvery = Number(opt.shots ?? 5);
const [width, height] = (opt.size ?? "1280x720").split("x").map(Number);
const parseTimed = (s) =>
  (s ? s.split(",") : []).map((item) => {
    const [what, at] = item.split("@");
    return { what, at: Number(at) };
  });
const keys = parseTimed(opt.keys);
const clicks = parseTimed(opt.clicks);
fs.mkdirSync(outDir, { recursive: true });

const AUDIO_TAP = () => {
  window.__audio = { samples: [], contexts: 0, taps: 0 };
  const analysers = new Map();
  const connect = AudioNode.prototype.connect;
  AudioNode.prototype.connect = function (target, ...args) {
    if (target instanceof AudioDestinationNode) {
      let analyser = analysers.get(target.context);
      if (!analyser) {
        analyser = target.context.createAnalyser();
        analyser.fftSize = 2048;
        connect.call(analyser, target);
        analysers.set(target.context, analyser);
        window.__audio.contexts++;
      }
      window.__audio.taps++;
      return connect.call(this, analyser, ...args);
    }
    return connect.call(this, target, ...args);
  };
  const buf = new Float32Array(2048);
  setInterval(() => {
    let peak = 0, sum = 0, n = 0, state = "none";
    for (const [ctx, analyser] of analysers) {
      state = ctx.state;
      analyser.getFloatTimeDomainData(buf);
      for (const v of buf) { sum += v * v; peak = Math.max(peak, Math.abs(v)); n++; }
    }
    const rms = n ? Math.sqrt(sum / n) : 0;
    window.__audio.samples.push({
      t: performance.now() / 1000,
      db: rms > 0 ? 20 * Math.log10(rms) : -200,
      peak_db: peak > 0 ? 20 * Math.log10(peak) : -200,
      state,
    });
  }, 250);
};

const started = Date.now();
const since = () => (Date.now() - started) / 1000;
const browser = await puppeteer.launch({
  executablePath: process.env.CHROME ?? "/usr/bin/google-chrome",
  headless: true,
  args: [
    "--use-angle=swiftshader", "--enable-unsafe-swiftshader", `--window-size=${width},${height}`,
    "--autoplay-policy=no-user-gesture-required",
  ],
});
const report = { url, started: new Date().toISOString(), viewport: [width, height], mbps: opt.mbps ?? null,
  marks: {}, console: [], failed_requests: [], responses: [], shots: [], audio: null, errors: [] };
const consoleLines = [];
try {
  const page = await browser.newPage();
  await page.setViewport({ width, height });
  await page.evaluateOnNewDocument(AUDIO_TAP);
  if (opt.mbps) {
    const cdp = await page.createCDPSession();
    await cdp.send("Network.enable");
    await cdp.send("Network.emulateNetworkConditions", {
      offline: false, latency: 40, uploadThroughput: 5 * 125000,
      downloadThroughput: Number(opt.mbps) * 125000,
    });
  }
  let markReady;
  const ready = new Promise((r) => (markReady = r));
  page.on("console", (msg) => {
    const line = { t: since(), type: msg.type(), text: msg.text() };
    report.console.push(line);
    consoleLines.push(`${line.t.toFixed(2)} [${line.type}] ${line.text}`);
    if (line.text.includes("TANK_SQUAD_READY") && !report.marks.ready) { report.marks.ready = line.t; markReady(); }
  });
  page.on("pageerror", (err) => report.errors.push(`uncaught: ${err.message}`));
  page.on("requestfailed", (req) => report.failed_requests.push({ t: since(), url: req.url(), why: req.failure()?.errorText }));
  page.on("response", (res) => {
    report.responses.push({ t: since(), url: res.url().replace(/^https?:\/\/[^/]+/, ""), status: res.status(),
      bytes: Number(res.headers()["content-length"] ?? -1) });
  });
  for (let attempt = 0; ; attempt++) {
    try { await page.goto(url, { waitUntil: "load", timeout: 600_000 }); break; } catch (err) {
      if (attempt >= 40) throw err;
      await new Promise((r) => setTimeout(r, 250));
    }
  }
  report.marks.page_load = since();
  const bootTimeout = Number(process.env.SMOKE_TIMEOUT_MS ?? 900_000);
  const timedOut = await Promise.race([ready.then(() => false), new Promise((r) => setTimeout(() => r(true), bootTimeout))]);
  if (timedOut) report.errors.push(`never logged TANK_SQUAD_READY within ${bootTimeout / 1000}s`);
  // A player's first tap: the user gesture WebAudio waits for (autoplay is also allowed above).
  await page.mouse.click(width / 2, height - 8);
  const t0 = Date.now();
  const events = [
    ...keys.map((k) => ({ at: k.at, run: () => page.keyboard.press(k.what), label: `key ${k.what}` })),
    ...clicks.map((c) => {
      const [x, y] = c.what.split(":").map(Number);
      return { at: c.at, run: () => page.mouse.click(x, y), label: `click ${x},${y}` };
    }),
  ];
  for (let s = 0; s <= seconds; s += shotEvery) events.push({ at: s, shot: true });
  events.sort((a, b) => a.at - b.at);
  for (const ev of events) {
    const wait = ev.at * 1000 - (Date.now() - t0);
    if (wait > 0) await new Promise((r) => setTimeout(r, wait));
    if (ev.shot) {
      const file = path.join(outDir, `shot_${String(ev.at).padStart(3, "0")}.png`);
      await page.screenshot({ path: file });
      report.shots.push({ at: ev.at, file });
    } else {
      await ev.run();
      report.console.push({ t: since(), type: "observer", text: ev.label });
      consoleLines.push(`${since().toFixed(2)} [observer] ${ev.label}`);
    }
  }
  report.audio = await page.evaluate(() => window.__audio);
} catch (err) {
  report.errors.push(`harness: ${err.message}`);
} finally {
  await browser.close();
}
// The audio verdict in a few numbers: how much of the watch was above -60 dBFS, and the loudest second.
const samples = report.audio?.samples ?? [];
const after = samples.filter((s) => report.marks.ready && s.t >= 0);
const audible = after.filter((s) => s.db > -60);
report.audio_summary = {
  contexts: report.audio?.contexts ?? 0, taps: report.audio?.taps ?? 0, samples: after.length,
  audible_fraction: after.length ? +(audible.length / after.length).toFixed(3) : 0,
  max_db: after.length ? +Math.max(...after.map((s) => s.db)).toFixed(1) : null,
  states: [...new Set(after.map((s) => s.state))],
};
fs.writeFileSync(path.join(outDir, "report.json"), JSON.stringify(report, null, 1));
fs.writeFileSync(path.join(outDir, "console.txt"), consoleLines.join("\n") + "\n");
console.log(`OBSERVE ready=${report.marks.ready ?? "never"}s page_load=${report.marks.page_load}s ` +
  `audio=${JSON.stringify(report.audio_summary)} errors=${report.errors.length} ` +
  `console_errors=${report.console.filter((l) => l.type === "error").length} failed=${report.failed_requests.length}`);
process.exit(report.errors.some((e) => e.startsWith("harness")) ? 1 : 0);
