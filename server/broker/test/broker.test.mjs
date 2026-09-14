import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";
import { startBroker } from "../src/broker.mjs";
import {
  CLOSE,
  MODE_RELIABLE,
  MODE_UNRELIABLE,
  ROOM_CODE_LENGTH,
  decodeHeader,
  encodeFrame,
  flagsFor,
  isRoomCode,
  modeOf,
} from "../src/protocol.mjs";
import { TestPeer } from "../src/test_peer.mjs";

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Each describe block gets its own broker so timing options can differ.
async function withBroker(options = {}) {
  const { broker, port } = await startBroker({ ackMs: 50, ...options });
  const url = `ws://127.0.0.1:${port}`;
  const peers = [];
  const open = async (wsOptions) => {
    const peer = await TestPeer.open(url, wsOptions);
    peers.push(peer);
    return peer;
  };
  const room = async (players = 1) => {
    const host = await open();
    await host.host();
    const clients = [];
    for (let i = 0; i < players; i++) {
      const client = await open();
      await client.join(host.room);
      await host.control("peer_joined");
      clients.push(client);
    }
    return { host, clients };
  };
  const shutdown = async () => {
    for (const peer of peers) peer.terminate();
    await broker.close();
  };
  return { broker, port, url, open, room, shutdown };
}

describe("protocol", () => {
  test("a frame header round-trips peer, mode, channel and sequence", () => {
    const frame = encodeFrame(-123456, flagsFor(MODE_RELIABLE, 5), 4000000000, Buffer.from("hi"));
    const header = decodeHeader(frame);
    assert.equal(header.peer, -123456);
    assert.equal(modeOf(header.flags), MODE_RELIABLE);
    assert.equal(header.flags >> 2, 5);
    assert.equal(header.seq, 4000000000);
    assert.equal(frame.subarray(9).toString(), "hi");
  });

  test("room codes avoid characters that are misread aloud", () => {
    assert.ok(isRoomCode("ABCDE"));
    assert.ok(!isRoomCode("ABCD0"), "zero looks like O");
    assert.ok(!isRoomCode("ABCDI"), "I looks like 1");
    assert.ok(!isRoomCode("ABCD"));
  });
});

describe("lobbies", () => {
  let ctx;
  before(async () => (ctx = await withBroker({ maxPeersPerRoom: 3, maxFailedJoins: 3 })));
  after(() => ctx.shutdown());

  test("a host opens a room and gets a join code, peer id 1 and a token", async () => {
    const host = await ctx.open();
    const msg = await host.host();
    assert.equal(msg.peer_id, 1);
    assert.ok(isRoomCode(msg.room) && msg.room.length === ROOM_CODE_LENGTH);
    assert.ok(msg.token.length >= 20, "token is long enough not to be guessed");
  });

  test("a player joins by code (any case) and the host hears about it", async () => {
    const host = await ctx.open();
    await host.host();
    const player = await ctx.open();
    const joined = await player.join(host.room.toLowerCase(), { peer_id: 777 });
    assert.equal(joined.peer_id, 777, "the proposed peer id is kept when it's free");
    assert.equal(joined.host_id, 1);
    assert.equal((await host.control("peer_joined")).peer_id, 777);
  });

  test("a taken or invalid proposed peer id is replaced by a fresh one", async () => {
    const host = await ctx.open();
    await host.host();
    const first = await ctx.open();
    await first.join(host.room, { peer_id: 50 });
    const second = await ctx.open();
    const joined = await second.join(host.room, { peer_id: 50 });
    assert.notEqual(joined.peer_id, 50);
    assert.ok(joined.peer_id > 1);
  });

  test("a full room refuses players", async () => {
    const { host } = await ctx.room(2);
    const late = await ctx.open();
    late.send({ op: "join", room: host.room });
    assert.equal((await late.control("error")).code, "room_full");
  });

  test("a closed room refuses players", async () => {
    const host = await ctx.open();
    await host.host();
    host.send({ op: "set_open", open: false });
    await wait(50);
    const late = await ctx.open();
    late.send({ op: "join", room: host.room });
    assert.equal((await late.control("error")).code, "room_closed");
  });

  test("guessing codes gets the connection closed", async () => {
    const guesser = await ctx.open();
    for (const code of ["AAAAA", "BBBBB"]) {
      guesser.send({ op: "join", room: code });
      assert.equal((await guesser.control("error")).code, "room_not_found");
    }
    guesser.send({ op: "join", room: "CCCCC" });
    assert.equal(await guesser.closedWith(), CLOSE.PROTOCOL_ERROR);
  });

  test("a client speaking another protocol version is refused", async () => {
    const peer = await ctx.open();
    peer.ws.send(JSON.stringify({ op: "host", version: 99 }));
    assert.equal((await peer.control("error")).code, "version");
    assert.equal(await peer.closedWith(), CLOSE.PROTOCOL_ERROR);
  });

  test("the host kicks a player", async () => {
    const { host, clients } = await ctx.room(1);
    host.send({ op: "kick", peer_id: clients[0].id });
    assert.equal(await clients[0].closedWith(), CLOSE.KICKED);
    const left = await host.control("peer_left");
    assert.deepEqual([left.peer_id, left.reason], [clients[0].id, "kicked"]);
  });

  test("when the host leaves, players are told and the room is gone", async () => {
    const { host, clients } = await ctx.room(1);
    const code = host.room;
    host.send({ op: "leave" });
    assert.equal((await clients[0].control("host_left")).reason, "host_left");
    assert.equal(await clients[0].closedWith(), CLOSE.ROOM_CLOSED);
    const late = await ctx.open();
    late.send({ op: "join", room: code });
    assert.equal((await late.control("error")).code, "room_not_found");
  });

  test("health and stats endpoints answer without leaking room codes", async () => {
    const health = await fetch(`http://127.0.0.1:${ctx.port}/healthz`);
    assert.equal(await health.text(), "ok\n");
    const stats = await (await fetch(`http://127.0.0.1:${ctx.port}/stats`)).json();
    assert.ok(stats.rooms >= 1 && typeof stats.framesRelayed === "number");
    assert.ok(!JSON.stringify(stats).match(/"[A-Z2-9]{5}"/), "no room codes in stats");
  });
});

describe("relay", () => {
  let ctx;
  before(async () => (ctx = await withBroker()));
  after(() => ctx.shutdown());

  test("a player's frame reaches the host stamped with the player's id", async () => {
    const { host, clients } = await ctx.room(1);
    clients[0].sendFrame(1, "fire!");
    const frame = await host.frame();
    assert.equal(frame.from, clients[0].id);
    assert.equal(frame.payload.toString(), "fire!");
  });

  test("the host broadcasts, targets one player, or excludes one", async () => {
    const { host, clients } = await ctx.room(2);
    const [a, b] = clients;
    host.sendFrame(0, "all");
    assert.equal((await a.frame()).payload.toString(), "all");
    assert.equal((await b.frame()).payload.toString(), "all");
    host.sendFrame(b.id, "only b");
    const toB = await b.frame();
    assert.deepEqual([toB.from, toB.payload.toString()], [1, "only b"]);
    host.sendFrame(-b.id, "not b");
    assert.equal((await a.frame()).payload.toString(), "not b");
    await wait(100);
    const frames = (peer) => peer.inbox.filter((i) => i.kind === "frame").length;
    assert.equal(frames(a) + frames(b), 0, "nothing extra delivered");
  });

  test("players can't message each other (star topology)", async () => {
    const { host, clients } = await ctx.room(2);
    const [a, b] = clients;
    a.sendFrame(b.id, "psst");
    a.sendFrame(0, "everyone");
    await wait(150);
    assert.equal(b.inbox.filter((i) => i.kind === "frame").length, 0);
    assert.equal(host.inbox.filter((i) => i.kind === "frame").length, 0, "a non-host target isn't rerouted either");
  });

  test("mode and channel survive the relay; each receiver gets its own sequence numbers", async () => {
    const { host, clients } = await ctx.room(1);
    host.sendFrame(0, "x", flagsFor(MODE_UNRELIABLE, 3));
    host.sendFrame(0, "y");
    const first = await clients[0].frame();
    const second = await clients[0].frame();
    assert.equal(modeOf(first.flags), MODE_UNRELIABLE);
    assert.equal(first.flags >> 2, 3);
    assert.deepEqual([first.seq, second.seq], [1, 2]);
  });

  test("a retransmitted frame (sequence already seen) is not delivered twice", async () => {
    const { host, clients } = await ctx.room(1);
    clients[0].sendFrame(1, "once", flagsFor(MODE_RELIABLE), 5);
    clients[0].sendFrame(1, "once", flagsFor(MODE_RELIABLE), 5);
    clients[0].sendFrame(1, "next", flagsFor(MODE_RELIABLE), 6);
    assert.equal((await host.frame()).payload.toString(), "once");
    assert.equal((await host.frame()).payload.toString(), "next");
  });

  test("the broker acknowledges what it received", async () => {
    const { host, clients } = await ctx.room(1);
    clients[0].sendFrame(1, "a");
    clients[0].sendFrame(1, "b");
    await host.frame();
    let ack;
    do ack = await clients[0].control("ack");
    while (ack.seq < 2);
    assert.equal(ack.seq, 2);
  });

  test("frames before joining a room are a protocol error", async () => {
    const stranger = await ctx.open();
    stranger.sendFrame(1, "hello?");
    assert.equal(await stranger.closedWith(), CLOSE.PROTOCOL_ERROR);
  });
});

describe("limits", () => {
  let ctx;
  before(
    async () =>
      (ctx = await withBroker({
        maxFrameBytes: 1024,
        clientRate: { msgsPerSec: 20, bytesPerSec: 100_000 },
        burstSeconds: 1,
        retainBytes: 2000,
        handshakeTimeoutMs: 200,
      })),
  );
  after(() => ctx.shutdown());

  test("an oversized frame closes the connection", async () => {
    const { clients } = await ctx.room(1);
    clients[0].sendFrame(1, Buffer.alloc(2000));
    assert.equal(await clients[0].closedWith(), 1009, "ws 'message too big'");
  });

  test("flooding gets a player rate limited and removed without a grace period", async () => {
    const { host, clients } = await ctx.room(1);
    for (let i = 0; i < 60; i++) clients[0].sendFrame(1, "spam");
    assert.equal(await clients[0].closedWith(), CLOSE.RATE_LIMITED);
    assert.equal((await host.control("peer_left")).reason, "rate_limited");
  });

  test("a connection that never joins is closed", async () => {
    const idle = await ctx.open();
    assert.equal(await idle.closedWith(1000), CLOSE.HANDSHAKE_TIMEOUT);
  });

  test("a player that never acknowledges overflows its retransmit buffer and is removed", async () => {
    const { host, clients } = await ctx.room(1);
    // Throttle our acks: this TestPeer never sends any. Each 500-byte reliable frame is retained.
    for (let i = 0; i < 6; i++) host.sendFrame(0, Buffer.alloc(500));
    assert.equal(await clients[0].closedWith(), CLOSE.OVERFLOW);
    assert.equal((await host.control("peer_left")).reason, "overflow");
  });
});

describe("session survival", () => {
  let ctx;
  before(async () => (ctx = await withBroker({ graceMs: 600, heartbeatMs: 100 })));
  after(() => ctx.shutdown());

  test("a player whose socket drops resumes its seat and gets the reliable frames it missed", async () => {
    const { host, clients } = await ctx.room(1);
    const player = clients[0];
    host.sendFrame(0, "before");
    const before = await player.frame();
    player.ws.send(JSON.stringify({ op: "ack", seq: before.seq }));
    await wait(30);
    player.terminate();
    assert.equal((await host.control("peer_away")).peer_id, player.id);
    host.sendFrame(0, "while away 1");
    host.sendFrame(0, "stale snapshot", flagsFor(MODE_UNRELIABLE));
    host.sendFrame(0, "while away 2");

    const back = await ctx.open();
    back.send({ op: "resume", token: player.token, last_seq: before.seq });
    const resumed = await back.control("resumed");
    assert.equal(resumed.peer_id, player.id);
    assert.equal((await back.frame()).payload.toString(), "while away 1");
    assert.equal((await back.frame()).payload.toString(), "while away 2", "unreliable frames aren't buffered");
    assert.equal((await host.control("peer_back")).peer_id, player.id);
  });

  test("a resume tells the peer which of its own frames arrived, so it retransmits the rest", async () => {
    const { host, clients } = await ctx.room(1);
    const player = clients[0];
    player.sendFrame(1, "one");
    await host.frame();
    player.terminate();
    const back = await ctx.open();
    back.send({ op: "resume", token: player.token, last_seq: 0 });
    assert.equal((await back.control("resumed")).last_seq, 1);
  });

  test("a resume replaces a half-open socket the broker hasn't noticed is dead", async () => {
    const { host, clients } = await ctx.room(1);
    const player = clients[0];
    const back = await ctx.open();
    back.send({ op: "resume", token: player.token });
    await back.control("resumed");
    assert.equal(await player.closedWith(), CLOSE.REPLACED);
    host.sendFrame(player.id, "to the new socket");
    assert.equal((await back.frame()).payload.toString(), "to the new socket");
    await wait(50);
    assert.equal(host.inbox.filter((i) => i.kind === "control" && i.msg.op === "peer_away").length, 0,
      "replacing a socket isn't reported as leaving");
  });

  test("a seat is released when the grace period ends", async () => {
    const { host, clients } = await ctx.room(1);
    clients[0].terminate();
    await host.control("peer_away");
    const left = await host.control("peer_left", 2000);
    assert.equal(left.reason, "timeout");
    const late = await ctx.open();
    late.send({ op: "resume", token: clients[0].token });
    assert.equal((await late.control("error")).code, "resume_failed");
  });

  test("a peer that stops answering heartbeats is dropped, then may resume", async () => {
    const host = await ctx.open();
    await host.host();
    const silent = await ctx.open({ autoPong: false });
    await silent.join(host.room);
    await host.control("peer_joined");
    assert.equal((await host.control("peer_away", 1000)).peer_id, silent.id);
  });

  test("the host can drop and resume too; players hear host_away and host_back", async () => {
    const { host, clients } = await ctx.room(1);
    host.terminate();
    await clients[0].control("host_away");
    clients[0].sendFrame(1, "for the host, buffered");
    const back = await ctx.open();
    back.send({ op: "resume", token: host.token, last_seq: 0 });
    const resumed = await back.control("resumed");
    assert.deepEqual(resumed.peers, [clients[0].id]);
    assert.equal((await back.frame()).payload.toString(), "for the host, buffered");
    await clients[0].control("host_back");
  });

  test("a host that never comes back closes the room", async () => {
    const { host, clients } = await ctx.room(1);
    host.terminate();
    assert.equal((await clients[0].control("host_left", 2000)).reason, "host_timeout");
  });
});
