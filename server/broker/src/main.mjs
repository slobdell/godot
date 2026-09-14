#!/usr/bin/env node
// Run the broker: `make broker` (or `node src/main.mjs --port=9300 --host=0.0.0.0`).
// Every DEFAULTS key can be overridden as --kebab-case=value, e.g. --grace-ms=10000.
// Prints BROKER_LISTENING port=N once it accepts connections (smoke tests wait for it).
import { Broker, DEFAULTS } from "./broker.mjs";

const args = Object.fromEntries(
  process.argv.slice(2).map((arg) => {
    const [key, value = ""] = arg.replace(/^--/, "").split("=", 2);
    return [key.replace(/-([a-z])/g, (_, c) => c.toUpperCase()), value];
  }),
);

const options = {};
for (const [key, value] of Object.entries(args)) {
  if (key === "port" || key === "host") continue;
  if (!(key in DEFAULTS) || typeof DEFAULTS[key] !== "number") {
    console.error(`unknown option --${key}`);
    process.exit(2);
  }
  options[key] = Number(value);
}

const broker = new Broker(options);
const port = await broker.listen(Number(args.port ?? 9300), args.host ?? "127.0.0.1");
console.log(`BROKER_LISTENING port=${port}`);

let lastLine = "";
setInterval(() => {
  const line = JSON.stringify(broker.stats());
  if (line !== lastLine) console.log(`BROKER_STATS ${line}`);
  lastLine = line;
}, 10_000).unref();

for (const signal of ["SIGINT", "SIGTERM"]) {
  process.on(signal, async () => {
    await broker.close();
    process.exit(0);
  });
}
