// `make broker-smoke`: drive a running broker (the real CLI process) like a small match would.
// Usage: node smoke.mjs <port>
//   host + 2 players join by code; 300 frames flow each way; one player's socket is cut and it
//   resumes without losing a reliable frame; the host leaves and the players are told; /stats agrees.
import assert from "node:assert/strict";
import { MODE_RELIABLE, MODE_UNRELIABLE, flagsFor } from "./src/protocol.mjs";
import { TestPeer } from "./src/test_peer.mjs";

const port = Number(process.argv[2] ?? 9300);
const base = `127.0.0.1:${port}`;
const FRAMES = 300;

async function waitForBroker() {
  for (let attempt = 0; attempt < 50; attempt++) {
    try {
      if ((await fetch(`http://${base}/healthz`)).ok) return;
    } catch {}
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`broker never answered on ${base}`);
}

async function collect(peer, count, label) {
  const payloads = [];
  for (let i = 0; i < count; i++) payloads.push((await peer.frame(5000)).payload.toString());
  return payloads;
}

async function main() {
  await waitForBroker();
  const host = await TestPeer.open(`ws://${base}/`);
  const room = (await host.host()).room;
  const players = [];
  for (let i = 0; i < 2; i++) {
    const player = await TestPeer.open(`ws://${base}/`);
    await player.join(room);
    await host.control("peer_joined");
    players.push(player);
  }
  console.log(`BROKER_SMOKE room=${room} players=${players.map((p) => p.id).join(",")}`);

  // Players -> host: interleaved, stamped with the right sender, in order per sender.
  for (let i = 0; i < FRAMES; i++) for (const p of players) p.sendFrame(1, `${p.id}:${i}`, flagsFor(MODE_UNRELIABLE));
  const atHost = await collect(host, FRAMES * 2);
  for (const p of players) {
    const mine = atHost.filter((text) => text.startsWith(`${p.id}:`));
    assert.deepEqual(mine, [...Array(FRAMES).keys()].map((i) => `${p.id}:${i}`), `host got player ${p.id}'s frames in order`);
  }

  // Host -> everyone.
  for (let i = 0; i < FRAMES; i++) host.sendFrame(0, `snap:${i}`);
  for (const p of players) assert.equal((await collect(p, FRAMES)).at(-1), `snap:${FRAMES - 1}`);
  for (const p of players) p.send({ op: "ack", seq: FRAMES });

  // Cut one player's socket (a phone going into a tunnel), keep sending, resume.
  const [dropped, steady] = players;
  dropped.terminate();
  assert.equal((await host.control("peer_away", 3000)).peer_id, dropped.id);
  for (let i = 0; i < 20; i++) host.sendFrame(0, `away:${i}`, flagsFor(MODE_RELIABLE));
  await collect(steady, 20);
  const back = await TestPeer.open(`ws://${base}/`);
  back.send({ op: "resume", token: dropped.token, last_seq: FRAMES });
  await back.control("resumed");
  const replay = await collect(back, 20);
  assert.deepEqual(replay, [...Array(20).keys()].map((i) => `away:${i}`), "resumed player got every reliable frame");
  await host.control("peer_back");

  const stats = await (await fetch(`http://${base}/stats`)).json();
  assert.equal(stats.rooms, 1);
  assert.equal(stats.peers, 3);
  assert.ok(stats.resumes >= 1);

  host.send({ op: "leave" });
  await steady.control("host_left");
  await back.control("host_left");
  await new Promise((resolve) => setTimeout(resolve, 100));
  const after = await (await fetch(`http://${base}/stats`)).json();
  assert.equal(after.rooms, 0, "the room is gone after the host leaves");
  console.log(`BROKER_SMOKE PASS relayed=${after.framesRelayed} bytes=${after.bytesRelayed}`);
  process.exit(0);
}

main().catch((err) => {
  console.error(`BROKER_SMOKE FAIL ${err.stack ?? err}`);
  process.exit(1);
});
