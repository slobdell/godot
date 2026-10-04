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
  window.__audio = { samples: [], contexts: 0, taps: 0, worklet: [], fps: [], worklet_error: null, starts: [], states: [] };
  // Every sound the browser is asked to START (Godot's Sample mode plays each sound as an AudioBufferSourceNode), with
  // the context's state at that moment, and every state change / resume: which playbacks began while it was suspended.
  const now = () => +(performance.now() / 1000).toFixed(2);
  // AudioBufferSourceNode and OscillatorNode/ConstantSourceNode each define their own start(): hook every one.
  for (const Cls of [AudioBufferSourceNode, OscillatorNode, ConstantSourceNode, AudioScheduledSourceNode]) {
    if (!Object.prototype.hasOwnProperty.call(Cls.prototype, "start")) continue;
    const origStart = Cls.prototype.start;
    Cls.prototype.start = function (...args) {
      const buf = this.buffer;
      window.__audio.starts.push({ t: now(), state: this.context.state, kind: this.constructor.name,
        seconds: buf ? +buf.duration.toFixed(2) : null, loop: !!this.loop, when: args[0] ?? 0, ctx_t: +this.context.currentTime.toFixed(2) });
      return origStart.apply(this, args);
    };
  }
  const origResume = BaseAudioContext.prototype.resume ?? AudioContext.prototype.resume;
  AudioContext.prototype.resume = function (...args) {
    window.__audio.states.push({ t: now(), event: "resume() called", state: this.state });
    return origResume.apply(this, args);
  };
  const OrigCtx = window.AudioContext;
  window.AudioContext = function (...args) {
    const ctx = new OrigCtx(...args);
    window.__audio.states.push({ t: now(), event: "created", state: ctx.state, rate: ctx.sampleRate });
    ctx.addEventListener("statechange", () => window.__audio.states.push({ t: now(), event: "statechange", state: ctx.state }));
    return ctx;
  };
  window.AudioContext.prototype = OrigCtx.prototype;
  const analysers = new Map();
  const connect = AudioNode.prototype.connect;
  // The audio thread's own account: an AudioWorklet sums every block that reaches the speakers and posts one record
  // per ~0.5 s of AUDIO time. The main thread can be starved (SwiftShader at a few fps) and still receive every record
  // later, so a quiet starved page and a silent page are told apart.
  const WORKLET = `class EnergyTap extends AudioWorkletProcessor {
    constructor() { super(); this.n = 0; this.loud = 0; this.peak = 0; this.sum = 0; this.count = 0; }
    process(inputs) {
      const ch = inputs[0] && inputs[0][0];
      if (ch) { let p = 0, s = 0; for (const v of ch) { const a = Math.abs(v); if (a > p) p = a; s += v * v; }
        this.n++; this.sum += s; this.count += ch.length; if (p > this.peak) this.peak = p; if (p > 0.001) this.loud++; }
      if (this.n >= Math.round(sampleRate / 128 / 2)) {
        this.port.postMessage({ t: currentTime, blocks: this.n, loud_blocks: this.loud, peak: this.peak,
          rms: this.count ? Math.sqrt(this.sum / this.count) : 0 });
        this.n = 0; this.loud = 0; this.peak = 0; this.sum = 0; this.count = 0; }
      return true; } }
  registerProcessor("energy-tap", EnergyTap);`;
  const workletUrl = URL.createObjectURL(new Blob([WORKLET], { type: "application/javascript" }));
  let frames = 0;
  const raf = () => { frames++; requestAnimationFrame(raf); };
  requestAnimationFrame(raf);
  setInterval(() => { window.__audio.fps.push({ t: performance.now() / 1000, fps: frames }); frames = 0; }, 1000);
  AudioNode.prototype.connect = function (target, ...args) {
    if (target instanceof AudioDestinationNode) {
      let analyser = analysers.get(target.context);
      if (!analyser) {
        analyser = target.context.createAnalyser();
        analyser.fftSize = 2048;
        connect.call(analyser, target);
        analysers.set(target.context, analyser);
        window.__audio.contexts++;
        const ctx = target.context;
        ctx.audioWorklet.addModule(workletUrl).then(() => {
          const tap = new AudioWorkletNode(ctx, "energy-tap", { numberOfInputs: 1, numberOfOutputs: 0 });
          tap.port.onmessage = (e) => window.__audio.worklet.push(e.data);
          connect.call(analyser, tap);
        }).catch((err) => { window.__audio.worklet_error = String(err); });
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
  // OBSERVE_HEADFUL=1: a real window on $DISPLAY (builder0's desktop) at the machine's normal frame rate.
  headless: !process.env.OBSERVE_HEADFUL,
  // OBSERVE_GPU=1: the machine's real GPU (ANGLE over GL) instead of SwiftShader, still headless -- to tell an effect of
  // a 2 fps software renderer from the game's own behaviour.
  args: [
    ...(process.env.OBSERVE_GPU || process.env.OBSERVE_HEADFUL ? ["--use-angle=gl", "--enable-gpu", "--ignore-gpu-blocklist"]
      : ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"]), `--window-size=${width},${height}`,
    "--autoplay-policy=no-user-gesture-required",
  ],
});
const report = { url, started: new Date().toISOString(), viewport: [width, height], mbps: opt.mbps ?? null, cpu: Number(opt.cpu ?? 1),
  marks: {}, console: [], failed_requests: [], responses: [], shots: [], audio: null, errors: [] };
const consoleLines = [];
try {
  const page = await browser.newPage();
  await page.setViewport({ width, height });
  await page.evaluateOnNewDocument(AUDIO_TAP);
  // --cpu=N: slow the page's main thread N times (CDP Emulation.setCPUThrottlingRate). The match stays the same; only
  // the frame time moves -- the mechanism under test when the engine mixes sound on the main thread (Stream mode).
  if (opt.cpu && Number(opt.cpu) > 1) {
    const cdpCpu = await page.createCDPSession();
    await cdpCpu.send("Emulation.setCPUThrottlingRate", { rate: Number(opt.cpu) });
  }
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
const recs = report.audio?.worklet ?? [];
const blocks = recs.reduce((a, r) => a + r.blocks, 0);
const loudBlocks = recs.reduce((a, r) => a + r.loud_blocks, 0);
const fpsList = (report.audio?.fps ?? []).map((f) => f.fps).sort((x, y) => x - y);
report.audio_thread = {
  records: recs.length, audio_seconds: recs.length ? +(recs.at(-1).t - recs[0].t).toFixed(1) : 0,
  loud_block_fraction: blocks ? +(loudBlocks / blocks).toFixed(3) : 0,
  peak_db: recs.length ? +(20 * Math.log10(Math.max(1e-10, ...recs.map((r) => r.peak)))).toFixed(1) : null,
  first_loud_t: recs.find((r) => r.loud_blocks > 0)?.t ?? null, error: report.audio?.worklet_error ?? null,
  median_fps: fpsList.length ? fpsList[Math.floor(fpsList.length / 2)] : null,
};
const starts = report.audio?.starts ?? [];
report.audio_starts = {
  count: starts.length, while_suspended: starts.filter((x) => x.state !== "running").length,
  first: starts[0] ?? null, by_seconds: Object.entries(starts.reduce((m, x) => { const k = `${x.kind}:${x.seconds}s${x.loop ? ":loop" : ""}`; m[k] = (m[k] || 0) + 1; return m; }, {})).slice(0, 25),
  context_states: report.audio?.states ?? [],
  autoplay_policy: "no-user-gesture-required", gesture: "a trusted CDP click at READY (page.mouse.click)",
};
report.audio_summary = {
  contexts: report.audio?.contexts ?? 0, taps: report.audio?.taps ?? 0, samples: after.length,
  audible_fraction: after.length ? +(audible.length / after.length).toFixed(3) : 0,
  max_db: after.length ? +Math.max(...after.map((s) => s.db)).toFixed(1) : null,
  states: [...new Set(after.map((s) => s.state))],
};
fs.writeFileSync(path.join(outDir, "report.json"), JSON.stringify(report, null, 1));
fs.writeFileSync(path.join(outDir, "console.txt"), consoleLines.join("\n") + "\n");
// OBSERVE_KEEP=<dir>: a second copy outside build/ -- a remote copy-back MIRRORS build/ and deleted a measurement's
// reports before anyone had read them (ship, round 17: the frame-cost A/B could not be re-proved afterwards).
if (process.env.OBSERVE_KEEP) {
  const keep = path.join(process.env.OBSERVE_KEEP, path.basename(outDir));
  fs.mkdirSync(keep, { recursive: true });
  for (const f of ["report.json", "console.txt"]) fs.copyFileSync(path.join(outDir, f), path.join(keep, f));
}
// Which playback path the page REALLY used (not which build we meant to serve): the browser is asked to start
// AudioBufferSourceNodes only in Sample mode; in Stream mode the engine mixes into one worklet and starts none.
report.playback = (report.audio_starts?.count ?? 0) > 0 ? "sample" : "stream";
console.log(`OBSERVE playback=${report.playback} sources_started=${report.audio_starts?.count ?? 0} cpu=${opt.cpu ?? 1} mode=${process.env.OBSERVE_HEADFUL ? "window" : process.env.OBSERVE_GPU ? "headless-gpu" : "headless-swiftshader"} ready=${report.marks.ready ?? "never"}s page_load=${report.marks.page_load}s ` +
  `audio=${JSON.stringify(report.audio_summary)} audio_thread=${JSON.stringify(report.audio_thread)} errors=${report.errors.length} ` +
  `console_errors=${report.console.filter((l) => l.type === "error").length} failed=${report.failed_requests.length}`);
process.exit(report.errors.some((e) => e.startsWith("harness")) ? 1 : 0);
