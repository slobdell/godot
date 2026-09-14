// `make broker-load`: how much CPU and memory does the broker need per player?
// Usage: node load.mjs <port> <broker pid> [rooms=25] [players=4] [seconds=20]
//
// Opens `rooms` rooms, each with a host and `players` players, and replays the traffic measured
// in real relay matches (netcode.md "Measurements", 10 tanks): the host sends each player ~33
// snapshot frames/s of ~440 bytes (Godot sends per peer), and each player sends ~30 command frames/s
// of ~50 bytes. Reads the broker's CPU time and RSS from /proc before and after.
import fs from "node:fs";
import { MODE_UNRELIABLE, flagsFor } from "./src/protocol.mjs";
import { TestPeer } from "./src/test_peer.mjs";

const [port, brokerPid, rooms = 25, playersPerRoom = 4, seconds = 20] = process.argv.slice(2).map(Number);
const url = `ws://127.0.0.1:${port}/`;
const SNAPSHOT_HZ = 33;
const SNAPSHOT_BYTES = 440;
const COMMAND_HZ = 30;
const COMMAND_BYTES = 50;

function procStats(pid) {
  const stat = fs.readFileSync(`/proc/${pid}/stat`, "utf8").split(") ")[1].split(" ");
  const ticks = Number(stat[11]) + Number(stat[12]); // utime + stime (fields 14, 15)
  const rssKb = Number(fs.readFileSync(`/proc/${pid}/status`, "utf8").match(/VmRSS:\s+(\d+)/)[1]);
  return { cpuSeconds: ticks / 100, rssKb };
}

async function openRoom() {
  const host = await TestPeer.open(url);
  const { room } = await host.host();
  const players = [];
  for (let i = 0; i < playersPerRoom; i++) {
    const player = await TestPeer.open(url);
    await player.join(room);
    players.push(player);
  }
  // Nobody reads their inbox in a load test; drop it so the load generator doesn't grow.
  for (const peer of [host, ...players]) peer.inbox = { push() {}, findIndex: () => -1, splice() {}, length: 0 };
  return { host, players };
}

const idle = procStats(brokerPid);
const all = [];
for (let r = 0; r < rooms; r++) all.push(await openRoom());
await new Promise((resolve) => setTimeout(resolve, 500));
const connected = procStats(brokerPid);

const snapshot = Buffer.alloc(SNAPSHOT_BYTES, 7);
const command = Buffer.alloc(COMMAND_BYTES, 3);
const ackEvery = 10;
let frames = 0;
const timers = [];
for (const { host, players } of all) {
  timers.push(setInterval(() => {
    for (const p of players) host.sendFrame(p.id, snapshot, flagsFor(MODE_UNRELIABLE));
    frames += players.length;
  }, 1000 / SNAPSHOT_HZ));
  for (const p of players) {
    let n = 0;
    timers.push(setInterval(() => {
      p.sendFrame(1, command, flagsFor(MODE_UNRELIABLE));
      frames += 1;
      if (++n % ackEvery === 0) p.send({ op: "ack", seq: 0 });
    }, 1000 / COMMAND_HZ));
  }
}
const begin = procStats(brokerPid);
const beginMs = Date.now();
await new Promise((resolve) => setTimeout(resolve, seconds * 1000));
const end = procStats(brokerPid);
const elapsed = (Date.now() - beginMs) / 1000;
for (const t of timers) clearInterval(t);
const stats = await (await fetch(`http://127.0.0.1:${port}/stats`)).json();

const players = rooms * playersPerRoom;
const cpuPercent = ((end.cpuSeconds - begin.cpuSeconds) / elapsed) * 100;
const result = {
  rooms,
  players,
  connections: rooms * (playersPerRoom + 1),
  offered_frames_per_sec: Math.round(frames / elapsed),
  broker_cpu_percent_of_one_core: Number(cpuPercent.toFixed(1)),
  broker_rss_mb_idle: Number((idle.rssKb / 1024).toFixed(1)),
  broker_rss_mb_loaded: Number((end.rssKb / 1024).toFixed(1)),
  rss_kb_per_connection: Math.round((connected.rssKb - idle.rssKb) / (rooms * (playersPerRoom + 1))),
  cpu_percent_per_100_players: Number(((cpuPercent / players) * 100).toFixed(1)),
  frames_relayed: stats.framesRelayed,
  rate_limited: stats.rateLimited,
};
console.log(`BROKER_LOAD ${JSON.stringify(result)}`);
for (const { host, players: ps } of all) for (const p of [host, ...ps]) p.terminate();
process.exit(0);
