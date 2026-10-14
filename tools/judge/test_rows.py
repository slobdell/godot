#!/usr/bin/env python3
"""tools/judge/rows.py against synthetic files AND the judged tables kept under references/ (the numbers the verdict
scripts printed in rounds 28-29 must come back out: a reader that disagrees with `turns_verdict.py` is wrong)."""
import json
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
REF = os.path.join(ROOT, "_agents", "streams", "references")
sys.path.insert(0, HERE)
import rows  # noqa: E402


def traffic_row(seed, tick, fast, xfast, arrived=10, arrive=None, end=60.0, which="both", kind="head"):
    return {"start_tick": tick, "seed": seed, "arena": "terminus", "kind": kind, "which": which,
            "contacts_fast": fast, "contacts_cross_fast": xfast, "arrived": arrived, "crews": 10,
            "arrive_s": arrive or {"A_%d" % i: 10.0 + i for i in range(10)}, "end_s": end,
            "friend_stuck_s": 1.0, "stuck_s": 2.0}


class Synthetic(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()

    def write(self, name, items):
        path = os.path.join(self.dir, name)
        with open(path, "w") as handle:
            for item in items:
                handle.write(json.dumps(item) + "\n")
        return path

    def test_traffic_pairs_follow_the_runner_order_and_skip_solo_and_missing(self):
        base = self.write("b.jsonl", [traffic_row(2, 1, 5, 2), traffic_row(1, 3, 7, 3), traffic_row(1, 1, 9, 4),
                                      traffic_row(1, 6, 1, 1, which="solo_a"), {"seed": 1, "start_tick": 8, "missing": True,
                                                                                 "arena": "terminus", "kind": "head", "which": "both"}])
        arm = self.write("a.jsonl", [traffic_row(1, 1, 4, 1), traffic_row(1, 3, 7, 3), traffic_row(2, 1, 5, 0),
                                     traffic_row(9, 9, 0, 0)])
        cases = rows.traffic_pairs(base, arm)
        self.assertEqual(list(cases), ["terminus/head"])
        keys = [k for k, _b, _a in cases["terminus/head"]]
        self.assertEqual(keys, [(1, 1), (1, 3), (2, 1)])  # seed-major, tick-minor; seed 9 has no base, the solo is out
        self.assertEqual(rows.diffs(cases["terminus/head"], "fast"), [-5, 0, 0])
        self.assertEqual(rows.diffs(cases["terminus/head"], rows.TRAFFIC_METRICS["xfast"]), [-3, 0, -2])
        self.assertEqual(rows.by_seed(cases["terminus/head"], "fast"), {1: [-5, 0], 2: [0]})

    def test_all_in_counts_a_crew_never_in_at_the_runs_end(self):
        r = traffic_row(1, 1, 0, 0, arrive={"a": 5.0, "b": -1.0}, end=88.5)
        self.assertEqual(rows.all_in_s(r), 88.5)
        self.assertEqual(rows.TRAFFIC_METRICS["missing"](r), 0)  # arrived is the row's own count, not derived

    def test_approach_pairs_match_east_to_none_by_seed_and_tick(self):
        path = self.write("ap.jsonl", [{"seed": 1, "start_tick": 1, "approach": "east", "alive": 2},
                                       {"seed": 1, "start_tick": 1, "approach": "none", "alive": 1},
                                       {"seed": 1, "start_tick": 3, "approach": "east", "alive": 3}])
        pairs = rows.approach_pairs(path)
        self.assertEqual(len(pairs), 1)
        self.assertEqual(rows.diffs(pairs, "alive"), [1])

    def test_census_pairs_read_the_tag_line_per_seed(self):
        off, on = os.path.join(self.dir, "off"), os.path.join(self.dir, "on")
        os.makedirs(off)
        os.makedirs(on)
        for seed in (13, 14):
            with open(os.path.join(off, "off-%d.log" % seed), "w") as handle:
                handle.write("noise\nCONTACT_CENSUS %s\n" % json.dumps({"under_move": 10 + seed}))
            with open(os.path.join(on, "on-%d.log" % seed), "w") as handle:
                handle.write("CONTACT_CENSUS %s\n" % json.dumps({"under_move": seed}))
        pairs = rows.census_pairs(off, on, "CONTACT_CENSUS")
        self.assertEqual([(s, a["under_move"], b["under_move"]) for s, a, b in pairs], [(13, 23, 13), (14, 24, 14)])


class References(unittest.TestCase):
    """The judged data on disk reads back to the verdicts the streams published."""

    def test_t3_judged_totals_match_turns_verdict(self):
        base = os.path.join(REF, "round29/traffic/t3_judged_base_d9b3339c_seeds222324.jsonl")
        arm = os.path.join(REF, "round29/traffic/t3_judged_arm_d9b3339c_seeds222324.jsonl")
        cases = rows.traffic_pairs(base, arm)
        self.assertEqual(sorted(cases), ["terminus/cross", "terminus/head", "yard_open/cross", "yard_open/head"])
        yc = cases["yard_open/cross"]
        self.assertEqual(len(yc), 18)
        self.assertEqual((sum(rows.values(yc, "arrived", "base")), sum(rows.values(yc, "arrived", "arm"))), (171, 167))
        xfast = rows.TRAFFIC_METRICS["xfast"]
        pooled_b = sum(sum(rows.values(cases[c], xfast, "base")) for c in ("terminus/cross", "yard_open/cross"))
        pooled_a = sum(sum(rows.values(cases[c], xfast, "arm")) for c in ("terminus/cross", "yard_open/cross"))
        self.assertEqual((pooled_b, pooled_a), (206, 95))

    def test_cp_t_terminus_head_matches_hold_verdict(self):
        base = os.path.join(REF, "round29/traffic/judged_base_3a94f38d_seeds131415.jsonl")
        arm = os.path.join(REF, "round29/traffic/judged_hold_3a94f38d_seeds131415.jsonl")
        th = rows.traffic_pairs(base, arm)["terminus/head"]
        xfast = rows.TRAFFIC_METRICS["xfast"]
        self.assertEqual((sum(rows.values(th, xfast, "base")), sum(rows.values(th, xfast, "arm"))), (475, 91))
        # the three untouched cases are byte-identical in every metric: the sim is deterministic per flags
        for case in ("terminus/cross", "yard_open/cross", "yard_open/head"):
            pairs = rows.traffic_pairs(base, arm)[case]
            self.assertEqual(rows.diffs(pairs, "fast"), [0] * 18)

    def test_m4_terminus_rows(self):
        table = rows.terminus_rows(os.path.join(REF, "round29/manoeuvre/m4_judged.txt"))
        self.assertEqual(sorted(table), ["mixed", "rigs"])
        self.assertEqual(sum(b["arrived"] for _s, b, _n in table["rigs"]), 81)
        self.assertEqual(sum(n["arrived"] for _s, _b, n in table["rigs"]), 64)
        self.assertEqual(sum(n["contacts"] for _s, _b, n in table["rigs"]), 8542)

    def test_m1_class_and_moving_lines(self):
        path = os.path.join(REF, "round29/manoeuvre/m1_judged.txt")
        lines = rows.class_lines(path)
        self.assertEqual(len(lines), 24)
        wt = [l for l in lines if l["task"] == "faced_attack_move" and l["klass"] == "wheels/turret"][0]
        self.assertEqual((wt["n"], wt["new"], wt["base"], wt["diff"], wt["se"]), (27, 85, 73, 12, 8.9))
        moving = rows.moving_lines(path)
        self.assertEqual([m["new_drawn"] - m["base_drawn"] for m in moving], [-3, 8, -4, 3, 2, 8])
        medians = rows.hull_medians(path, "M1_HULL")
        self.assertEqual(medians[("faced_support_by_fire", "wheels/turret", "new_clicked")], 45.1)

    def test_b1_round28_rows_pair_east_to_none(self):
        pairs = rows.approach_pairs(os.path.join(REF, "round28/brains_b1_judged_a_even.jsonl"))
        self.assertEqual(len(pairs), 18)
        on_side = sum(1 for _k, _n, e in pairs if 0 <= e["hit_off_median_deg"] <= 35)
        self.assertEqual(on_side, 10)

    def test_b3_census_pairs(self):
        pairs = rows.census_pairs(os.path.join(REF, "round28/b3_contact_census"), os.path.join(REF, "round28/b3_contact_census"),
                                  "CONTACT_CENSUS", pattern=r"off-(\d+)\.log$")
        self.assertEqual(len(pairs), 12)  # off against itself here: the reader, not the verdict
        off_on = rows.census_pairs(os.path.join(REF, "round28/b3_contact_census"), os.path.join(REF, "round28/b3_contact_census"),
                                   "CONTACT_CENSUS", pattern=r"on-(\d+)\.log$")
        self.assertEqual(sum(o["under_move"] for _s, o, _n in pairs), 111)
        self.assertEqual(sum(o["under_move"] for _s, o, _n in off_on), 28)


if __name__ == "__main__":
    unittest.main()
