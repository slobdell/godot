#!/usr/bin/env python3
"""Command a Tank Squad tank through the agent bridge. See _agents/agent_bridge.md.

Built for an LLM at a terminal: every command prints compact text.

  agent.py state                      what I can see right now
  agent.py map                        arena bounds + obstacles (plan once)
  agent.py move X Z                   standing order: drive to (X, Z)
  agent.py stop
  agent.py drive THROTTLE TURN SECS   raw driving for a few seconds
  agent.py target NAME                engage one tank whenever it's visible
  agent.py fire-at-will               engage the nearest visible enemy
  agent.py hold-fire
  agent.py aim X Z
  agent.py watch SECONDS              wait, printing one line per second + events
  agent.py screenshot                 save the current frame (windowed client only)

Options: --port N (default 8765, or $AGENT_PORT)
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request


def call(port, method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(f"http://127.0.0.1:{port}{path}", data=data, method=method)
    if data is not None:
        request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as err:
        return json.loads(err.read() or b"{}") | {"http_status": err.code}
    except (urllib.error.URLError, ConnectionError) as err:
        sys.exit(f"agent bridge not reachable on port {port}: {err}. Is `make agent-client` running?")


def fmt_order(order):
    kind = order.get("type", "?")
    args = ",".join(f"{v:g}" if isinstance(v, (int, float)) else str(v) for k, v in order.items() if k != "type")
    return f"{kind}({args})" if args else kind


def fmt_tank(t, is_me=False):
    x, z = t["pos"]
    status = "ALIVE" if t["alive"] else "DEAD"
    line = f"{t['name']} ({t['team']}) pos ({x:.0f},{z:.0f}) hdg {t['heading']:.0f} turret {t['turret']:.0f} HP {t['health']} {status}"
    if is_me:
        line += f" reload {t['reload'] * 100:.0f}%"
    else:
        line += f" | dist {t['distance']:.0f} brg {t['bearing']:.0f} (rel {t['relative_bearing']:+.0f})"
        line += " VISIBLE" if t["visible"] else " hidden"
        if "exposed_face" in t:
            line += f" | shot would hit its {t['exposed_face'].upper()}"
        if t.get("aiming_at_me"):
            line += " | ITS GUN IS ON YOU"
    return line


def print_state(s):
    score = s["score"]
    print(f"t={s['time']:.1f}s  score Green {score['green']} : {score['rust']} Rust")
    if s["me"] is None:
        print("ME: no tank yet (not spawned / not connected)")
    else:
        print("ME " + fmt_tank(s["me"], is_me=True))
    orders = s["orders"]
    print(f"orders: move={fmt_order(orders['move'])} weapon={fmt_order(orders['weapon'])} engaged={s['engaged'] or '-'}")
    for t in s["tanks"]:
        print("  " + fmt_tank(t))


def watch(port, seconds):
    previous = call(port, "GET", "/state")
    end = time.time() + seconds
    while time.time() < end:
        time.sleep(1.0)
        s = call(port, "GET", "/state")
        events = []
        if s["score"] != previous["score"]:
            events.append(f"SCORE {s['score']['green']}:{s['score']['rust']}")
        before = {t["name"]: t for t in previous["tanks"]}
        if s["me"] and previous["me"]:
            if s["me"]["health"] < previous["me"]["health"]:
                events.append(f"I took {previous['me']['health'] - s['me']['health']} damage")
            if previous["me"]["alive"] and not s["me"]["alive"]:
                events.append("I WAS DESTROYED")
        for t in s["tanks"]:
            old = before.get(t["name"])
            if old and t["health"] < old["health"]:
                events.append(f"{t['name']} took {old['health'] - t['health']} damage")
            if old and old["alive"] and not t["alive"]:
                events.append(f"{t['name']} DESTROYED")
        me = s["me"]
        summary = f"t={s['time']:.0f}s"
        if me:
            summary += f" me ({me['pos'][0]:.0f},{me['pos'][1]:.0f}) HP {me['health']} reload {me['reload'] * 100:.0f}%"
        summary += f" engaged={s['engaged'] or '-'}"
        print(summary + ("  ** " + "; ".join(events) if events else ""))
        previous = s
    print_state(previous)


def main(argv):
    port = int(os.environ.get("AGENT_PORT", "8765"))
    if len(argv) >= 2 and argv[0] == "--port":
        port, argv = int(argv[1]), argv[2:]
    if not argv:
        sys.exit(__doc__)
    command, args = argv[0], argv[1:]

    def post(body):
        result = call(port, "POST", "/orders", body)
        if "error" in result:
            sys.exit(f"rejected: {result['error']}")
        print(f"ok: move={fmt_order(result['move'])} weapon={fmt_order(result['weapon'])}")

    if command == "state":
        print_state(call(port, "GET", "/state"))
    elif command == "map":
        m = call(port, "GET", "/map")
        print(m["coordinates"])
        print(f"bounds x{m['bounds']['x']} z{m['bounds']['z']}  bases {m['bases']}  shell speed {m['shell_speed']} range {m['shell_range']}  armor {m['armor_multipliers']}")
        print("obstacles (world-space footprints):")
        for o in m["obstacles"]:
            print(f"  {o['name']}: x {o['x'][0]:.1f}..{o['x'][1]:.1f}  z {o['z'][0]:.1f}..{o['z'][1]:.1f}  h {o['height']:.1f}")
    elif command == "move" and len(args) == 2:
        post({"move": {"type": "move_to", "x": float(args[0]), "z": float(args[1])}})
    elif command == "stop":
        post({"move": {"type": "stop"}})
    elif command == "drive" and len(args) == 3:
        post({"move": {"type": "drive", "throttle": float(args[0]), "turn": float(args[1]), "seconds": float(args[2])}})
    elif command == "target" and len(args) == 1:
        post({"weapon": {"type": "target", "name": args[0]}})
    elif command == "fire-at-will":
        post({"weapon": {"type": "fire_at_will"}})
    elif command == "hold-fire":
        post({"weapon": {"type": "hold_fire"}})
    elif command == "aim" and len(args) == 2:
        post({"weapon": {"type": "aim", "x": float(args[0]), "z": float(args[1])}})
    elif command == "watch" and len(args) == 1:
        watch(port, float(args[0]))
    elif command == "screenshot":
        print(call(port, "POST", "/screenshot", {}))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except ValueError as err:
        sys.exit(f"bad argument ({err})\n{__doc__}")
