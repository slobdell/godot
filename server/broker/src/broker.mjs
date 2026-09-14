// Tank Squad match broker (netcode stream, phase N0).
//
// It never simulates the game. It does three things, all in memory:
//   1. Lobbies: a host opens a room and gets a join code; players join with the code.
//   2. Relay: binary game packets flow host <-> players through the room (star topology:
//      players may only address the host, like Godot's server_relay = false).
//   3. Session survival: heartbeats find dead sockets; a dropped peer keeps its seat for a
//      grace period and resumes with its token; reliable frames sent meanwhile are retransmitted.
// Plus abuse limits: frame size, per-connection message/byte rates, room and peer caps.
//
// Design notes and the full message list: _agents/streams/netcode.md ("N0 broker").

import crypto from "node:crypto";
import http from "node:http";
import { WebSocketServer } from "ws";
import {
  CLOSE,
  HEADER_BYTES,
  HOST_ID,
  MAX_PEER_ID,
  PROTOCOL_VERSION,
  ROOM_ALPHABET,
  ROOM_CODE_LENGTH,
  decodeHeader,
  encodeFrame,
  isReliable,
  isRoomCode,
} from "./protocol.mjs";

export const DEFAULTS = Object.freeze({
  maxFrameBytes: 64 * 1024,
  maxControlBytes: 4 * 1024,
  maxRooms: 1000,
  maxPeersPerRoom: 16, // including the host
  handshakeTimeoutMs: 10_000,
  heartbeatMs: 5_000, // ping interval; a socket that misses two in a row is dropped
  graceMs: 30_000, // how long a dropped peer keeps its seat
  ackMs: 250, // how often the broker acknowledges received sequence numbers
  retainBytes: 4 * 1024 * 1024, // unacknowledged reliable bytes kept per peer
  maxBufferedBytes: 8 * 1024 * 1024, // socket send backlog before it counts as dead
  maxFailedJoins: 5, // wrong codes per connection before it's closed (slows code guessing)
  // Token buckets refill at the per-second rate and hold `burstSeconds` of it.
  hostRate: { msgsPerSec: 6000, bytesPerSec: 2 * 1024 * 1024 },
  clientRate: { msgsPerSec: 600, bytesPerSec: 256 * 1024 },
  burstSeconds: 2,
});

class TokenBucket {
  constructor(perSecond, burstSeconds, now) {
    this.rate = perSecond;
    this.capacity = perSecond * burstSeconds;
    this.tokens = this.capacity;
    this.last = now;
  }

  take(amount, now) {
    this.tokens = Math.min(this.capacity, this.tokens + ((now - this.last) / 1000) * this.rate);
    this.last = now;
    if (this.tokens < amount) return false;
    this.tokens -= amount;
    return true;
  }
}

export class Broker {
  constructor(options = {}) {
    this.config = { ...DEFAULTS, ...options };
    this.now = options.now ?? (() => Date.now());
    this.rooms = new Map(); // code -> room
    this.peersByToken = new Map(); // token -> peer
    this.totals = { roomsOpened: 0, framesRelayed: 0, bytesRelayed: 0, framesDropped: 0, resumes: 0, rateLimited: 0 };
    this.httpServer = http.createServer((req, res) => this.#handleHttp(req, res));
    this.wss = new WebSocketServer({ noServer: true, maxPayload: this.config.maxFrameBytes });
    this.httpServer.on("upgrade", (req, socket, head) => {
      this.wss.handleUpgrade(req, socket, head, (ws) => this.#onConnection(ws, req));
    });
    this.heartbeat = setInterval(() => this.#heartbeatTick(), this.config.heartbeatMs);
    this.acker = setInterval(() => this.#ackTick(), this.config.ackMs);
    this.heartbeat.unref();
    this.acker.unref();
  }

  listen(port = 0, host = "127.0.0.1") {
    return new Promise((resolve, reject) => {
      this.httpServer.once("error", reject);
      this.httpServer.listen(port, host, () => resolve(this.httpServer.address().port));
    });
  }

  async close() {
    clearInterval(this.heartbeat);
    clearInterval(this.acker);
    for (const room of [...this.rooms.values()]) this.#closeRoom(room, "broker_shutdown");
    for (const ws of this.wss.clients) ws.terminate();
    await new Promise((resolve) => this.wss.close(resolve));
    await new Promise((resolve) => this.httpServer.close(resolve));
  }

  stats() {
    let peers = 0;
    let away = 0;
    for (const room of this.rooms.values()) {
      for (const peer of room.peers.values()) {
        peers += 1;
        if (!peer.conn) away += 1;
      }
    }
    return { rooms: this.rooms.size, peers, away, connections: this.wss.clients.size, ...this.totals };
  }

  // ---- HTTP -------------------------------------------------------------------------------

  #handleHttp(req, res) {
    const path = (req.url ?? "/").split("?")[0];
    if (path === "/healthz") {
      res.writeHead(200, { "content-type": "text/plain" }).end("ok\n");
    } else if (path === "/stats") {
      // Counts only: listing room codes would let anyone join any room.
      res.writeHead(200, { "content-type": "application/json" }).end(JSON.stringify(this.stats()) + "\n");
    } else {
      res.writeHead(426, { "content-type": "text/plain" }).end("Tank Squad broker: connect with a WebSocket\n");
    }
  }

  // ---- Connections ------------------------------------------------------------------------

  #onConnection(ws, req) {
    const conn = { ws, peer: null, alive: true, failedJoins: 0, bucket: null, address: req.socket.remoteAddress };
    ws.conn = conn;
    const lobbyRate = this.config.clientRate;
    conn.bucket = {
      msgs: new TokenBucket(lobbyRate.msgsPerSec, this.config.burstSeconds, this.now()),
      bytes: new TokenBucket(lobbyRate.bytesPerSec, this.config.burstSeconds, this.now()),
    };
    conn.handshakeTimer = setTimeout(() => {
      if (!conn.peer) this.#fail(conn, CLOSE.HANDSHAKE_TIMEOUT, "handshake_timeout", "send host, join or resume first");
    }, this.config.handshakeTimeoutMs);
    ws.on("pong", () => (conn.alive = true));
    ws.on("message", (data, isBinary) => this.#onMessage(conn, data, isBinary));
    ws.on("close", () => this.#onSocketClosed(conn));
    ws.on("error", () => {}); // 'close' follows; errors like oversize frames are expected input
  }

  #onMessage(conn, data, isBinary) {
    const now = this.now();
    if (!conn.bucket.msgs.take(1, now) || !conn.bucket.bytes.take(data.length, now)) {
      this.totals.rateLimited += 1;
      this.#fail(conn, CLOSE.RATE_LIMITED, "rate_limited", "too many messages", true);
      return;
    }
    if (isBinary) {
      this.#onFrame(conn, data);
      return;
    }
    if (data.length > this.config.maxControlBytes) {
      this.#fail(conn, CLOSE.TOO_LARGE, "too_large", "control message too large", true);
      return;
    }
    let msg;
    try {
      msg = JSON.parse(data.toString("utf8"));
    } catch {
      this.#fail(conn, CLOSE.PROTOCOL_ERROR, "bad_request", "control messages must be JSON", true);
      return;
    }
    if (msg === null || typeof msg !== "object" || typeof msg.op !== "string") {
      this.#fail(conn, CLOSE.PROTOCOL_ERROR, "bad_request", "missing op", true);
      return;
    }
    this.#onControl(conn, msg);
  }

  #onControl(conn, msg) {
    const peer = conn.peer;
    if (!peer) {
      if (msg.op === "host") return this.#opHost(conn, msg);
      if (msg.op === "join") return this.#opJoin(conn, msg);
      if (msg.op === "resume") return this.#opResume(conn, msg);
      if (msg.op === "ping") return this.#sendJson(conn.ws, { op: "pong", t: msg.t });
      return this.#fail(conn, CLOSE.PROTOCOL_ERROR, "bad_request", `unexpected op '${msg.op}' before joining`, true);
    }
    switch (msg.op) {
      case "ack":
        return this.#opAck(peer, msg);
      case "ping":
        return this.#sendJson(conn.ws, { op: "pong", t: msg.t });
      case "leave":
        this.#removePeer(peer, "left", CLOSE.LEFT);
        return;
      case "kick":
        return this.#opKick(peer, msg);
      case "set_open":
        if (peer.isHost) peer.room.open = Boolean(msg.open);
        return;
      default:
        return this.#sendJson(conn.ws, { op: "error", code: "bad_request", message: `unknown op '${msg.op}'` });
    }
  }

  #checkVersion(conn, msg) {
    if (msg.version !== PROTOCOL_VERSION) {
      this.#fail(conn, CLOSE.PROTOCOL_ERROR, "version", `broker speaks protocol ${PROTOCOL_VERSION}`, true);
      return false;
    }
    return true;
  }

  #opHost(conn, msg) {
    if (!this.#checkVersion(conn, msg)) return;
    if (this.rooms.size >= this.config.maxRooms) {
      return this.#fail(conn, CLOSE.PROTOCOL_ERROR, "server_full", "no free rooms, try again later", true);
    }
    const requested = Number.isInteger(msg.max_peers) ? msg.max_peers : this.config.maxPeersPerRoom;
    const room = {
      code: this.#newRoomCode(),
      peers: new Map(),
      open: true,
      maxPeers: Math.max(2, Math.min(requested, this.config.maxPeersPerRoom)),
      openedAt: this.now(),
    };
    this.rooms.set(room.code, room);
    this.totals.roomsOpened += 1;
    const peer = this.#addPeer(conn, room, HOST_ID);
    this.#sendJson(conn.ws, {
      op: "hosted",
      room: room.code,
      peer_id: HOST_ID,
      token: peer.token,
      max_peers: room.maxPeers,
      heartbeat_ms: this.config.heartbeatMs,
      grace_ms: this.config.graceMs,
    });
  }

  #opJoin(conn, msg) {
    if (!this.#checkVersion(conn, msg)) return;
    const code = typeof msg.room === "string" ? msg.room.toUpperCase() : "";
    const room = isRoomCode(code) ? this.rooms.get(code) : undefined;
    const refuse = (errorCode, message) => {
      conn.failedJoins += 1;
      if (conn.failedJoins >= this.config.maxFailedJoins) {
        return this.#fail(conn, CLOSE.PROTOCOL_ERROR, errorCode, message, true);
      }
      this.#sendJson(conn.ws, { op: "error", code: errorCode, message });
    };
    if (!room) return refuse("room_not_found", `no room ${code}`);
    if (!room.open) return refuse("room_closed", `room ${code} isn't accepting players`);
    if (room.peers.size >= room.maxPeers) return refuse("room_full", `room ${code} is full`);
    let id = Number.isInteger(msg.peer_id) ? msg.peer_id : 0;
    if (id <= HOST_ID || id > MAX_PEER_ID || room.peers.has(id)) id = this.#newPeerId(room);
    const peer = this.#addPeer(conn, room, id);
    // An opaque key the client keeps across sessions, so the host can give a returning player
    // their old tank. Only the host ever sees it.
    peer.player = typeof msg.player === "string" && /^[A-Za-z0-9_-]{1,64}$/.test(msg.player) ? msg.player : "";
    this.#sendJson(conn.ws, {
      op: "joined",
      room: room.code,
      peer_id: id,
      token: peer.token,
      host_id: HOST_ID,
      heartbeat_ms: this.config.heartbeatMs,
      grace_ms: this.config.graceMs,
    });
    this.#notifyHost(room, { op: "peer_joined", peer_id: id, player: peer.player });
  }

  #opResume(conn, msg) {
    const peer = typeof msg.token === "string" ? this.peersByToken.get(msg.token) : undefined;
    if (!peer) {
      return this.#fail(conn, CLOSE.RESUME_FAILED, "resume_failed", "that seat is gone (grace period over or room closed)", true);
    }
    if (peer.conn) {
      // The old socket is half-open (a phone switched networks before we noticed). Take over.
      const old = peer.conn;
      old.peer = null;
      this.#closeSocket(old, CLOSE.REPLACED, "replaced by a resumed connection");
    }
    this.#attach(conn, peer);
    clearTimeout(peer.graceTimer);
    peer.graceTimer = null;
    this.totals.resumes += 1;
    const wasAway = peer.awaySince !== null;
    peer.awaySince = null;
    this.#sendJson(conn.ws, {
      op: "resumed",
      room: peer.room.code,
      peer_id: peer.id,
      last_seq: peer.inSeq, // the peer retransmits its reliable frames after this
      peers: peer.isHost ? [...peer.room.peers.keys()].filter((id) => id !== HOST_ID) : undefined,
      players: peer.isHost
        ? Object.fromEntries([...peer.room.peers.values()].filter((p) => !p.isHost).map((p) => [p.id, p.player]))
        : undefined,
    });
    const lastSeen = Number.isInteger(msg.last_seq) ? msg.last_seq : 0;
    peer.retained = peer.retained.filter((entry) => entry.seq > lastSeen);
    peer.retainedBytes = peer.retained.reduce((sum, entry) => sum + entry.frame.length, 0);
    for (const entry of peer.retained) conn.ws.send(entry.frame);
    if (wasAway) {
      if (peer.isHost) this.#notifyClients(peer.room, { op: "host_back" });
      else this.#notifyHost(peer.room, { op: "peer_back", peer_id: peer.id });
    }
  }

  #opAck(peer, msg) {
    if (!Number.isInteger(msg.seq)) return;
    let dropped = 0;
    while (dropped < peer.retained.length && peer.retained[dropped].seq <= msg.seq) {
      peer.retainedBytes -= peer.retained[dropped].frame.length;
      dropped += 1;
    }
    if (dropped) peer.retained.splice(0, dropped);
  }

  #opKick(peer, msg) {
    if (!peer.isHost) return this.#sendJson(peer.conn.ws, { op: "error", code: "not_host", message: "only the host can kick" });
    const target = peer.room.peers.get(msg.peer_id);
    if (target && target !== peer) this.#removePeer(target, "kicked", CLOSE.KICKED);
  }

  // ---- Relay --------------------------------------------------------------------------------

  #onFrame(conn, data) {
    const peer = conn.peer;
    if (!peer) return this.#fail(conn, CLOSE.PROTOCOL_ERROR, "bad_request", "join a room before sending frames", true);
    if (data.length < HEADER_BYTES) return this.#fail(conn, CLOSE.PROTOCOL_ERROR, "bad_request", "short frame", true);
    const { peer: target, flags, seq } = decodeHeader(data);
    peer.stats.framesIn += 1;
    peer.stats.bytesIn += data.length;
    if (seq <= peer.inSeq) return; // a retransmission we already have
    peer.inSeq = seq;
    const payload = data.subarray(HEADER_BYTES);
    const room = peer.room;
    if (!peer.isHost) {
      if (target !== HOST_ID) {
        this.totals.framesDropped += 1; // players talk only to the host
        return;
      }
      this.#deliver(room.peers.get(HOST_ID), peer.id, flags, payload);
      return;
    }
    if (target > 0) {
      const destination = room.peers.get(target);
      if (destination && destination !== peer) this.#deliver(destination, HOST_ID, flags, payload);
      else this.totals.framesDropped += 1; // that player just left
      return;
    }
    for (const destination of room.peers.values()) {
      if (destination === peer || destination.id === -target) continue;
      this.#deliver(destination, HOST_ID, flags, payload);
    }
  }

  #deliver(destination, senderId, flags, payload) {
    if (!destination) return;
    const reliable = isReliable(flags);
    if (!reliable && !destination.conn) {
      this.totals.framesDropped += 1; // stale by the time the peer is back; don't buffer
      return;
    }
    destination.outSeq += 1;
    const frame = encodeFrame(senderId, flags, destination.outSeq, payload);
    if (reliable) {
      destination.retained.push({ seq: destination.outSeq, frame });
      destination.retainedBytes += frame.length;
      if (destination.retainedBytes > this.config.retainBytes) {
        this.#removePeer(destination, "overflow", CLOSE.OVERFLOW);
        return;
      }
    }
    this.totals.framesRelayed += 1;
    this.totals.bytesRelayed += frame.length;
    destination.stats.framesOut += 1;
    destination.stats.bytesOut += frame.length;
    const ws = destination.conn?.ws;
    if (!ws) return;
    if (ws.bufferedAmount > this.config.maxBufferedBytes) {
      ws.terminate(); // can't keep up: treat as a dropped socket; the peer may resume
      return;
    }
    ws.send(frame);
  }

  // ---- Peers and rooms ------------------------------------------------------------------------

  #addPeer(conn, room, id) {
    const peer = {
      id,
      room,
      isHost: id === HOST_ID,
      token: crypto.randomBytes(18).toString("base64url"),
      conn: null,
      awaySince: null,
      graceTimer: null,
      outSeq: 0,
      inSeq: 0,
      lastAckedIn: 0,
      retained: [],
      retainedBytes: 0,
      stats: { framesIn: 0, bytesIn: 0, framesOut: 0, bytesOut: 0 },
    };
    room.peers.set(id, peer);
    this.peersByToken.set(peer.token, peer);
    this.#attach(conn, peer);
    return peer;
  }

  #attach(conn, peer) {
    clearTimeout(conn.handshakeTimer);
    conn.peer = peer;
    peer.conn = conn;
    peer.lastAckedIn = -1; // force an ack to the new socket
    const rate = peer.isHost ? this.config.hostRate : this.config.clientRate;
    const now = this.now();
    conn.bucket = {
      msgs: new TokenBucket(rate.msgsPerSec, this.config.burstSeconds, now),
      bytes: new TokenBucket(rate.bytesPerSec, this.config.burstSeconds, now),
    };
  }

  #onSocketClosed(conn) {
    clearTimeout(conn.handshakeTimer);
    const peer = conn.peer;
    if (!peer) return;
    conn.peer = null;
    peer.conn = null;
    peer.awaySince = this.now();
    if (peer.isHost) this.#notifyClients(peer.room, { op: "host_away" });
    else this.#notifyHost(peer.room, { op: "peer_away", peer_id: peer.id });
    peer.graceTimer = setTimeout(() => this.#removePeer(peer, "timeout"), this.config.graceMs);
  }

  #removePeer(peer, reason, closeCode = CLOSE.ROOM_CLOSED) {
    const room = peer.room;
    if (room.peers.get(peer.id) !== peer) return;
    if (peer.isHost) {
      this.#closeRoom(room, reason === "left" ? "host_left" : `host_${reason}`, peer, closeCode);
      return;
    }
    const conn = this.#forget(peer);
    if (conn) this.#closeSocket(conn, closeCode, reason);
    this.#notifyHost(room, { op: "peer_left", peer_id: peer.id, reason });
  }

  #closeRoom(room, reason, host = null, hostCloseCode = CLOSE.ROOM_CLOSED) {
    this.rooms.delete(room.code);
    for (const peer of [...room.peers.values()]) {
      const conn = this.#forget(peer);
      if (!conn) continue;
      if (peer === host) {
        this.#closeSocket(conn, hostCloseCode, reason);
      } else {
        this.#sendJson(conn.ws, { op: "host_left", reason });
        this.#closeSocket(conn, CLOSE.ROOM_CLOSED, reason);
      }
    }
  }

  // Remove a peer from every index and detach its socket (so closing it doesn't start a grace
  // period). Returns the detached connection, if any, for the caller to close.
  #forget(peer) {
    peer.room.peers.delete(peer.id);
    this.peersByToken.delete(peer.token);
    clearTimeout(peer.graceTimer);
    peer.retained = [];
    peer.retainedBytes = 0;
    const conn = peer.conn;
    peer.conn = null;
    if (conn) conn.peer = null;
    return conn;
  }

  #notifyHost(room, msg) {
    const host = room.peers.get(HOST_ID);
    if (host?.conn) this.#sendJson(host.conn.ws, msg);
  }

  #notifyClients(room, msg) {
    for (const peer of room.peers.values()) {
      if (!peer.isHost && peer.conn) this.#sendJson(peer.conn.ws, msg);
    }
  }

  #newRoomCode() {
    for (;;) {
      let code = "";
      const bytes = crypto.randomBytes(ROOM_CODE_LENGTH);
      for (const byte of bytes) code += ROOM_ALPHABET[byte % ROOM_ALPHABET.length];
      if (!this.rooms.has(code)) return code;
    }
  }

  #newPeerId(room) {
    for (;;) {
      const id = 2 + (crypto.randomBytes(4).readUInt32LE(0) % (MAX_PEER_ID - 2));
      if (!room.peers.has(id)) return id;
    }
  }

  // ---- Timers -----------------------------------------------------------------------------------

  #heartbeatTick() {
    for (const ws of this.wss.clients) {
      const conn = ws.conn;
      if (!conn) continue;
      if (!conn.alive) {
        ws.terminate(); // missed a whole interval: the peer goes "away" and may resume
        continue;
      }
      conn.alive = false;
      ws.ping();
    }
  }

  #ackTick() {
    for (const room of this.rooms.values()) {
      for (const peer of room.peers.values()) {
        if (peer.conn && peer.inSeq !== peer.lastAckedIn) {
          peer.lastAckedIn = peer.inSeq;
          this.#sendJson(peer.conn.ws, { op: "ack", seq: peer.inSeq });
        }
      }
    }
  }

  // ---- Helpers ----------------------------------------------------------------------------------

  #sendJson(ws, msg) {
    if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(msg));
  }

  // Refuse a connection: tell it why, close the socket, and (for abuse) drop its seat without grace.
  #fail(conn, closeCode, errorCode, message, dropSeat = false) {
    this.#sendJson(conn.ws, { op: "error", code: errorCode, message });
    const peer = conn.peer;
    if (peer && dropSeat) {
      this.#removePeer(peer, errorCode, closeCode);
      return;
    }
    this.#closeSocket(conn, closeCode, errorCode);
  }

  #closeSocket(conn, code, reason) {
    const ws = conn.ws;
    if (ws.readyState === ws.OPEN || ws.readyState === ws.CONNECTING) {
      ws.close(code, reason.slice(0, 120));
      // A peer that never completes the close handshake mustn't hold the socket open.
      setTimeout(() => ws.terminate(), 2000).unref();
    }
  }
}

export async function startBroker(options = {}) {
  const broker = new Broker(options);
  const port = await broker.listen(options.port ?? 0, options.host ?? "127.0.0.1");
  return { broker, port };
}
