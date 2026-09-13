// Web export smoke test: `make web-smoke`.
//
// Usage: node smoke.mjs <url> <screenshot.png> [seconds-after-ready] [ready-marker]
//
// Passes when the page logs the game's READY marker (printed by game/main.gd)
// with no uncaught exceptions or console errors. Always writes the screenshot
// so a human or agent can look at what the browser actually rendered.
// Uses the system Chrome (override with $CHROME); SwiftShader provides WebGL 2
// without a GPU, so this works on a headless server too.
import puppeteer from "puppeteer-core";

const [url, screenshotPath, settleArg, markerArg] = process.argv.slice(2);
const settleMs = Number(settleArg ?? 3) * 1000;
const READY_MARKER = markerArg ?? "TANK_SQUAD_READY";
const BOOT_TIMEOUT_MS = 60_000;

const browser = await puppeteer.launch({
  executablePath: process.env.CHROME ?? "/usr/bin/google-chrome",
  headless: true,
  args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--window-size=1280,720"],
});

const problems = [];
let exitCode = 0;
try {
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720 });

  let markReady;
  const ready = new Promise((resolve) => (markReady = resolve));
  page.on("console", (msg) => {
    const text = msg.text();
    console.log(`[browser:${msg.type()}] ${text}`);
    if (msg.type() === "error") problems.push(`console error: ${text}`);
    if (text.includes(READY_MARKER)) markReady();
  });
  page.on("pageerror", (err) => problems.push(`uncaught exception: ${err.message}`));

  // The static server is started by make just before us; retry until it answers.
  for (let attempt = 0; ; attempt++) {
    try {
      await page.goto(url, { waitUntil: "load" });
      break;
    } catch (err) {
      if (attempt >= 40) throw err;
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
  }
  const timedOut = await Promise.race([
    ready.then(() => false),
    new Promise((resolve) => setTimeout(() => resolve(true), BOOT_TIMEOUT_MS)),
  ]);
  if (timedOut) problems.push(`game never logged ${READY_MARKER} within ${BOOT_TIMEOUT_MS / 1000}s`);
  else await new Promise((resolve) => setTimeout(resolve, settleMs));

  await page.screenshot({ path: screenshotPath });
  console.log(`screenshot saved: ${screenshotPath}`);
} catch (err) {
  problems.push(`smoke harness failed: ${err.message}`);
} finally {
  await browser.close();
}

if (problems.length) {
  console.error("\nWEB SMOKE FAILED:\n  " + problems.join("\n  "));
  exitCode = 1;
} else {
  console.log("\nWEB SMOKE PASSED");
}
process.exit(exitCode);
