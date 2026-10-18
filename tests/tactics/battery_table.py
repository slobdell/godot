#!/usr/bin/env python3
"""Round 33 (brains battery stretch): the battery bar's census reader (workstreams *Bars (round 33)*, "Battery seats").
Usage: battery_table.py BUILD/battery-census ARM [ARM ...]  (the first arm is ON, the second the base it is judged on).
Per arm, from each run's census row, TRAFFIC_ASKER rows and BATTERY_* lines: never-past battery askers, set-ups more
than 8 m from the place ASSIGNED when the crew began to deploy, artillery shots, runs with a repack while firing,
friendly-stuck crew-s, and fire order -> first shot. The worst ON runs print FIRST, before any total (the bar's line 4)."""
import json, math, os, re, statistics, sys

SETUP = re.compile(r"^BATTERY_SETUP .* off ([0-9.]+) m")
SHOT = re.compile(r"^BATTERY_FIRST_SHOT team \d+ (\S+) order (\S+) (none )?after ([0-9.]+) s")
ORDER = re.compile(r"^BATTERY_FIRE_ORDER t=[0-9.]+ team \d+ (\S+) (\S+)")


def run(prefix):
    row = json.load(open(prefix + ".json")) if os.path.getsize(prefix + ".json") else {"missing": True}
    askers = [json.loads(l) for l in open(prefix + ".askers") if l.strip()] if os.path.exists(prefix + ".askers") else []
    setups, shots, orders, answered = [], [], 0, 0
    for line in open(prefix + ".battery") if os.path.exists(prefix + ".battery") else []:
        m = SETUP.match(line)
        if m:
            setups.append(float(m.group(1)))
        m = ORDER.match(line)
        if m:
            orders += 1
        m = SHOT.match(line)
        if m:
            answered += 1
            shots.append(float(m.group(4)) if not m.group(3) else None)
    shots += [None] * max(0, orders - answered)  # an order still unanswered when the run ended
    return {"missing": bool(row.get("missing")), "art_shots": int(row.get("art_shots", 0)),
            "repacks_while_firing": int(row.get("repacks_while_firing", 0)), "friend_s": float(row.get("stuck_friend_s", 0.0)),
            "never_past_battery": sum(1 for a in askers if "Battery" in str(a.get("asker", ""))),
            "setups": len(setups), "setups_far": sum(1 for d in setups if d > 8.0), "first_shot": shots}


def arm(root, tag):
    d = os.path.join(root, tag)
    return {f[:-5]: run(os.path.join(d, f[:-5])) for f in sorted(os.listdir(d)) if f.endswith(".json")}


def main():
    root, tags = sys.argv[1], sys.argv[2:]
    arms = {t: arm(root, t) for t in tags}
    on, base = tags[0], tags[1] if len(tags) > 1 else None
    keys = sorted(arms[on])
    if base:
        keys = [k for k in keys if k in arms[base]]
        print("worst %s runs v %s first (never-past battery askers, set-ups > 8 m, shots, friendly-stuck s):" % (on, base))
        def worse(k):
            a, b = arms[on][k], arms[base][k]
            return (a["never_past_battery"] - b["never_past_battery"], a["setups_far"] - b["setups_far"],
                    b["art_shots"] - a["art_shots"], a["friend_s"] - b["friend_s"])
        for k in sorted(keys, key=worse, reverse=True)[:5]:
            a, b = arms[on][k], arms[base][k]
            print("  %-12s askers %d v %d | far %d/%d v %d/%d | shots %d v %d | friend %.0f v %.0f s" % (k,
                    a["never_past_battery"], b["never_past_battery"], a["setups_far"], a["setups"], b["setups_far"],
                    b["setups"], a["art_shots"], b["art_shots"], a["friend_s"], b["friend_s"]))
    for t in tags:
        rs = [arms[t][k] for k in keys]
        answered = [x for r in rs for x in r["first_shot"] if x is not None]
        orders = sum(len(r["first_shot"]) for r in rs)
        print("BATTERY_CENSUS %-4s n %d (missing %d) | never-past battery askers %d | set-ups > 8 m %d of %d | art shots %d"
              " | runs with a repack while firing %d | friendly-stuck %.0f s | first shot median %s s (%d of %d orders answered)" % (
                  t, len(rs), sum(r["missing"] for r in rs), sum(r["never_past_battery"] for r in rs),
                  sum(r["setups_far"] for r in rs), sum(r["setups"] for r in rs), sum(r["art_shots"] for r in rs),
                  sum(1 for r in rs if r["repacks_while_firing"] > 0), sum(r["friend_s"] for r in rs),
                  "%.1f" % statistics.median(answered) if answered else "-", len(answered), orders))
    if base:
        n = len(keys)
        diff = [arms[on][k]["friend_s"] - arms[base][k]["friend_s"] for k in keys]
        limit = sum(arms[base][k]["friend_s"] for k in keys) + 1.645 * (statistics.pstdev(diff) if n > 1 else 0.0) * math.sqrt(n)
        print("BATTERY_CENSUS friendly-stuck %s %.0f v limit %.0f (%s + 1.645 se of the paired difference, round 32's line)" % (
            on, sum(arms[on][k]["friend_s"] for k in keys), limit, base))


if __name__ == "__main__":
    main()
