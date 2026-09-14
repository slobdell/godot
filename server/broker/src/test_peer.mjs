// A minimal broker client for tests and the smoke script (the game's client is
// game/network/relay_peer.gd). Collects control messages and frames so tests can await them.
import WebSocket from "ws";
import { HEADER_BYTES, PROTOCOL_VERSION, decodeHeader, encodeFrame, flagsFor, MODE_RELIABLE } from "./protocol.mjs";

export class TestPeer {
  static async open(url, wsOptions = {}) {
    const peer = new TestPeer(new WebSocket(url, wsOptions));
    await new Promise((resolve, reject) => {
      peer.ws.once("open", resolve);
      peer.ws.once("error", reject);
    });
    return peer;
  }

  constructor(ws) {
    this.ws = ws;
    this.inbox = []; // {kind: "control", msg} | {kind: "frame", from, flags, seq, payload}
    this.waiters = [];
    this.closed = null; // {code, reason}
    this.outSeq = 0;
    this.id = 0;
    this.token = "";
    this.room = "";
    ws.on("message", (data, isBinary) => {
      if (isBinary) {
        const { peer, flags, seq } = decodeHeader(data);
        this.#push({ kind: "frame", from: peer, flags, seq, payload: data.subarray(HEADER_BYTES) });
      } else {
        this.#push({ kind: "control", msg: JSON.parse(data.toString("utf8")) });
      }
    });
    ws.on("close", (code, reason) => {
      this.closed = { code, reason: reason.toString() };
      this.#push({ kind: "closed", code });
    });
    ws.on("error", () => {});
  }

  #push(item) {
    this.inbox.push(item);
    for (const waiter of [...this.waiters]) waiter();
  }

  // Resolve with (and remove) the first inbox item matching `match`.
  next(match, timeoutMs = 2000, label = "message") {
    return new Promise((resolve, reject) => {
      const check = () => {
        const index = this.inbox.findIndex(match);
        if (index < 0) return false;
        const [item] = this.inbox.splice(index, 1);
        cleanup();
        resolve(item);
        return true;
      };
      const timer = setTimeout(() => {
        cleanup();
        reject(new Error(`timed out waiting for ${label}; inbox: ${JSON.stringify(this.inbox.map(summary))}`));
      }, timeoutMs);
      const cleanup = () => {
        clearTimeout(timer);
        this.waiters = this.waiters.filter((w) => w !== check);
      };
      if (!check()) this.waiters.push(check);
    });
  }

  async control(op, timeoutMs) {
    return (await this.next((item) => item.kind === "control" && item.msg.op === op, timeoutMs, `op ${op}`)).msg;
  }

  async frame(timeoutMs) {
    return this.next((item) => item.kind === "frame", timeoutMs, "frame");
  }

  async closedWith(timeoutMs) {
    return (await this.next((item) => item.kind === "closed", timeoutMs, "close")).code;
  }

  send(msg) {
    this.ws.send(JSON.stringify({ version: PROTOCOL_VERSION, ...msg }));
  }

  sendFrame(target, payload, flags = flagsFor(MODE_RELIABLE), seq = ++this.outSeq) {
    this.ws.send(encodeFrame(target, flags, seq, Buffer.from(payload)));
  }

  async host(extra = {}) {
    this.send({ op: "host", ...extra });
    const msg = await this.control("hosted");
    Object.assign(this, { id: msg.peer_id, token: msg.token, room: msg.room });
    return msg;
  }

  async join(room, extra = {}) {
    this.send({ op: "join", room, ...extra });
    const msg = await this.control("joined");
    Object.assign(this, { id: msg.peer_id, token: msg.token, room: msg.room });
    return msg;
  }

  close() {
    this.ws.close();
  }

  terminate() {
    this.ws.terminate();
  }
}

function summary(item) {
  if (item.kind === "control") return item.msg;
  if (item.kind === "frame") return { from: item.from, seq: item.seq, bytes: item.payload.length };
  return item;
}
