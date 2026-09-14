// Wire format shared by the broker and its clients (game/network/relay_protocol.gd mirrors it).
//
// Text frames carry JSON control messages: {"op": "...", ...}.
// Binary frames carry relayed game packets with a 9-byte little-endian header:
//
//   offset 0  int32   peer   client → broker: target (0 = everyone, N = peer N, -N = everyone but N)
//                            broker → client: the sender's peer id
//   offset 4  uint8   flags  bits 0-1 Godot transfer mode (0 unreliable, 1 unreliable ordered,
//                            2 reliable); bits 2-7 channel
//   offset 5  uint32  seq    per-direction sequence number, starts at 1. Reliable frames are kept
//                            until acknowledged so a reconnecting peer loses nothing.
//   offset 9  payload        opaque (Godot's SceneMultiplayer packet)

export const PROTOCOL_VERSION = 1;
export const HEADER_BYTES = 9;
export const HOST_ID = 1;
export const MAX_PEER_ID = 0x7fffffff;

export const MODE_UNRELIABLE = 0;
export const MODE_UNRELIABLE_ORDERED = 1;
export const MODE_RELIABLE = 2;

// No 0/O or 1/I: codes are read aloud and typed on phones.
export const ROOM_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
export const ROOM_CODE_LENGTH = 5;

// WebSocket close codes the broker uses (4000-4999 is the application range).
export const CLOSE = Object.freeze({
  REPLACED: 4000, // a resume took over this peer from another socket
  ROOM_CLOSED: 4001, // the host left or the room was shut down
  HANDSHAKE_TIMEOUT: 4002,
  PROTOCOL_ERROR: 4003,
  KICKED: 4004,
  LEFT: 4005, // the peer asked to leave
  TOO_LARGE: 4007,
  RATE_LIMITED: 4008,
  RESUME_FAILED: 4009,
  OVERFLOW: 4010, // the peer stopped acknowledging and its retransmit buffer filled
});

export function encodeFrame(peer, flags, seq, payload) {
  const frame = Buffer.allocUnsafe(HEADER_BYTES + payload.length);
  frame.writeInt32LE(peer, 0);
  frame.writeUInt8(flags, 4);
  frame.writeUInt32LE(seq, 5);
  payload.copy(frame, HEADER_BYTES);
  return frame;
}

export function decodeHeader(frame) {
  return { peer: frame.readInt32LE(0), flags: frame.readUInt8(4), seq: frame.readUInt32LE(5) };
}

export function flagsFor(mode, channel = 0) {
  return (mode & 0b11) | ((channel & 0b111111) << 2);
}

export function modeOf(flags) {
  return flags & 0b11;
}

export function isReliable(flags) {
  return modeOf(flags) === MODE_RELIABLE;
}

export function isRoomCode(text) {
  if (typeof text !== "string" || text.length !== ROOM_CODE_LENGTH) return false;
  for (const ch of text) if (!ROOM_ALPHABET.includes(ch)) return false;
  return true;
}
