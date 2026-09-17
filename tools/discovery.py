#!/usr/bin/env python3
"""Offline tactics discovery (round-5 ai X5, _agents/unit_ai.md "Offline discovery"): drive one side's elements from
outside the game, in lockstep, and keep a (state, decision, outcome) log to distil into deterministic rules later.
NOTHING HERE RUNS IN LIVE PLAY: it launches a headless match of its own.

The game side is DiscoveryBridge (game/agent/discovery_bridge.gd): every --every seconds of simulated time it prints
DISCOVERY_STATE <json> (what that side knows) and waits for one JSON line of tasks on stdin.

Policies:
    hold            never change a task (a baseline: the elements run their SOP where they formed)
    push            every element attacks the nearest known contact, or moves on the control point
    pin_and_flank   the biggest element supports by fire on the nearest contact while the others swing wide round it
    cmd:<command>   any process that reads a state line on stdin and writes a decision line on stdout (a search, a
                    script, a language model behind a wrapper): offline only

Usage: discovery.py --godot PATH [--side rust] [--policy pin_and_flank] [--opponent x4t9:standard] [--army combined_arms]
                    [--arena foundry] [--seed 1] [--every 5] [--time-limit 240] [--log build/discovery/run.jsonl]
"""
import argparse
import json
import math
import os
import shlex
import subprocess
import sys


def nearest(point, items):
    best = None
    for item in items:
        d = math.dist(point, item["at"])
        if best is None or d < best[0]:
            best = (d, item)
    return best[1] if best else None


def policy_hold(state):
    return {"tasks": []}


def policy_push(state):
    tasks = []
    for element in state["elements"]:
        target = nearest(element["at"], [c for c in state["contacts"] if c["age_seconds"] < 20])
        if target:
            tasks.append({"element": element["id"], "verb": "attack", "target": target["name"]})
        elif state.get("control"):
            tasks.append({"element": element["id"], "verb": "move", "to": state["control"]["at"]})
    return {"tasks": tasks}


def policy_pin_and_flank(state):
    elements = sorted(state["elements"], key=lambda e: (-e["units"], e["id"]))
    fresh = [c for c in state["contacts"] if c["age_seconds"] < 20]
    if not elements:
        return {"tasks": []}
    if not fresh:
        goal = state["control"]["at"] if state.get("control") else [0.0, 0.0]
        return {"tasks": [{"element": e["id"], "verb": "move", "to": goal} for e in elements]}
    base = elements[0]
    target = nearest(base["at"], fresh)
    tasks = [{"element": base["id"], "verb": "support_by_fire", "to": target["at"], "target": target["name"]}]
    for i, element in enumerate(elements[1:]):
        # Swing wide: a point beside the target, perpendicular to the base's line of fire, alternating sides.
        dx, dz = target["at"][0] - base["at"][0], target["at"][1] - base["at"][1]
        length = math.hypot(dx, dz) or 1.0
        side = 1 if i % 2 == 0 else -1
        limit = state.get("half_size", 120.0) - 8.0
        wide = [max(-limit, min(limit, target["at"][0] - dz / length * 45.0 * side)),
                max(-limit, min(limit, target["at"][1] + dx / length * 45.0 * side))]
        if math.dist(element["at"], wide) > 20.0 and element.get("task", {}).get("verb") != "attack":
            tasks.append({"element": element["id"], "verb": "move", "to": wide})
        else:
            tasks.append({"element": element["id"], "verb": "attack", "target": target["name"]})
    return {"tasks": tasks}


POLICIES = {"hold": policy_hold, "push": policy_push, "pin_and_flank": policy_pin_and_flank}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--side", default="rust", choices=["green", "rust"])
    parser.add_argument("--policy", default="pin_and_flank")
    parser.add_argument("--opponent", default="x4t9:standard", help="brain[:doctrine table] for the other side")
    parser.add_argument("--brain", default="x5p", help="brain variant for the discovery side")
    parser.add_argument("--army", default="combined_arms")
    parser.add_argument("--arena", default="foundry")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--every", type=float, default=5.0)
    parser.add_argument("--time-limit", type=int, default=240)
    parser.add_argument("--log", default="build/discovery/run.jsonl")
    parser.add_argument("--extra", default="")
    args = parser.parse_args()

    other = "green" if args.side == "rust" else "rust"
    brain, colon, table = args.opponent.partition(":")
    army = args.army if args.army.startswith(("cpu", "res://")) else f"res://doctrines/{args.army}.json"
    os.makedirs(os.path.dirname(os.path.abspath(args.log)), exist_ok=True)
    command = [args.godot, "--headless", "--fixed-fps", "60", "--path", ".", "--", "--match", "--elimination",
               f"--green-doctrine={army}", f"--rust-doctrine={army}", f"--arena={args.arena}", f"--seed={args.seed}",
               f"--time-limit={args.time_limit}", f"--{args.side}-brain={args.brain}", f"--{other}-brain={brain}",
               f"--{args.side}-discovery={args.every}", f"--discovery-log={os.path.abspath(args.log)}", "--tactics-ledger"]
    if colon:
        command.append(f"--{other}-elements" + (f"={table}" if table else ""))
    command += args.extra.split()

    external = None
    if args.policy.startswith("cmd:"):
        external = subprocess.Popen(shlex.split(args.policy[4:]), stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        decide = None
    elif args.policy in POLICIES:
        decide = POLICIES[args.policy]
    else:
        sys.exit(f"unknown policy {args.policy} (have {', '.join(POLICIES)} or cmd:<command>)")

    game = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                            bufsize=1)
    steps = 0
    result = None
    for line in iter(game.stdout.readline, ""):
        if line.startswith("DISCOVERY_STATE "):
            state = json.loads(line[len("DISCOVERY_STATE "):])
            if external is not None:
                external.stdin.write(json.dumps(state) + "\n")
                external.stdin.flush()
                answer = external.stdout.readline().strip() or "{}"
            else:
                answer = json.dumps(decide(state))
            game.stdin.write(answer + "\n")
            game.stdin.flush()
            steps += 1
        elif line.startswith(("DISCOVERY_ERROR", "DISCOVERY_DONE", "MATCH_RESULT", "TACTICS_LEDGER")) or "SCRIPT ERROR" in line:
            print(line.rstrip()[:400])
            if line.startswith("MATCH_RESULT "):
                result = json.loads(line[len("MATCH_RESULT "):])
    game.wait()
    if external is not None:
        external.stdin.close()
        external.wait()
    print(f"DISCOVERY_SUMMARY policy={args.policy} side={args.side} steps={steps} "
          f"winner={result['winner'] if result else 'none'} log={args.log}")
    sys.exit(0 if result else 1)


if __name__ == "__main__":
    main()
