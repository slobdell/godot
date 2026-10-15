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

    def test_round_30_terminus_tables_read_to_the_quoted_se(self):
        """Round 30's `per seed arrived(contacts)` format: M1b's rigs 176 -> 179 (se 5.13), M2b's rigs 181 -> 172 (se 4.97),
        kturnarc's mixed 291 -> 288 (se 3.34); M4b run 2's rigs are byte-identical to their base (the gate)."""
        import stats
        t = rows.terminus_rows(os.path.join(REF, "round30/manoeuvre/m1b_judged.txt"))
        self.assertEqual(sorted(t), ["mixed", "rigs"])
        self.assertEqual(len(t["rigs"]), 13)
        self.assertEqual(t["rigs"][0], (36, {"arrived": 16, "crews": 16, "contacts": 134}, {"arrived": 15, "crews": 16, "contacts": 270}))
        self.assertEqual((sum(b["arrived"] for _s, b, _n in t["rigs"]), sum(n["arrived"] for _s, _b, n in t["rigs"])), (176, 179))
        self.assertAlmostEqual(stats.paired_se_total(rows.diffs(t["rigs"], "arrived")), 5.13, places=2)
        m2b = rows.terminus_rows(os.path.join(REF, "round30/manoeuvre/m2b_judged.txt"))["rigs"]
        self.assertAlmostEqual(stats.paired_se_total(rows.diffs(m2b, "arrived")), 4.97, places=2)
        kta = rows.terminus_rows(os.path.join(REF, "round30/manoeuvre/kturnarc_judged.txt"))["mixed"]
        self.assertEqual((sum(rows.values(kta, "arrived", "base")), sum(rows.values(kta, "arrived", "arm"))), (291, 288))
        self.assertAlmostEqual(stats.paired_se_total(rows.diffs(kta, "arrived")), 3.34, places=2)
        run2 = rows.terminus_rows(os.path.join(REF, "round30/manoeuvre/m4b_run2_judged.txt"))
        self.assertEqual(rows.diffs(run2["rigs"], "contacts"), [0] * 13)
        self.assertEqual((sum(rows.values(run2["mixed"], "contacts", "base")), sum(rows.values(run2["mixed"], "contacts", "arm"))), (2093, 1915))

    def test_guard_lines_read_fight_guard_and_pinned_in_both_rounds(self):
        r29 = rows.guard_lines(os.path.join(REF, "round29/manoeuvre/m4_judged.txt"), "FIGHT_GUARD")
        self.assertEqual((r29["kills"]["base"], r29["kills"]["new"], r29["kills"]["se"], r29["kills"]["n"]), (1001, 984, 21.5, 24))
        self.assertEqual((r29["hit rate"]["se"], r29["hit rate"]["mean"]), (0.012, True))
        r30 = rows.guard_lines(os.path.join(REF, "round30/manoeuvre/m4b_run2_judged.txt"), "PINNED")
        self.assertEqual((r30["all"]["base"], r30["all"]["new"], r30["all"]["diff"], r30["all"]["se"], r30["all"]["n"]), (2596, 658, -1938, 422.1, 144))
        self.assertEqual(r30["rigs"]["diff"], 102)  # a signed '+102'
        fights = rows.guard_lines(os.path.join(REF, "round30/manoeuvre/m4b_run2_judged.txt"), "FIGHT_GUARD")
        self.assertEqual((fights["deaths"]["diff"], fights["deaths"]["se"]), (0, 34.1))

    def test_b5c_v4_cells_and_arrive_series(self):
        import statistics
        import stats
        gate = os.path.join(REF, "round30/brains/b5c-v4-gate-series-19eca15a.jsonl")
        sumps = rows.cell_pairs(gate, "sumps")
        self.assertEqual(len(sumps), 12)
        self.assertEqual((round(statistics.median(rows.values(sumps, rows.all_in8_or_end, "base")), 1),
                          round(statistics.median(rows.values(sumps, rows.all_in8_or_end, "arm")), 1)), (37.5, 24.5))
        yard = rows.cell_pairs(gate, "yard")
        every = lambda r: r["arrived"] == r["crews"]  # noqa: E731
        self.assertEqual((sum(every(b) for _k, b, _a in yard), sum(every(a) for _k, _b, a in yard)), (1, 12))
        arrive = rows.arrive_pairs(os.path.join(REF, "round30/brains/b5c-v4-arrive-off-19eca15a.jsonl"),
                                   os.path.join(REF, "round30/brains/b5c-v4-arrive-on-19eca15a.jsonl"))
        self.assertEqual(len(arrive), 100)
        within = lambda r: r.get("all_in8_s") is not None  # noqa: E731
        self.assertEqual((sum(within(o) for _k, o, _n in arrive), sum(within(n) for _k, _o, n in arrive)), (91, 99))
        b = sum(1 for _k, o, n in arrive if within(n) and not within(o))
        c = sum(1 for _k, o, n in arrive if within(o) and not within(n))
        self.assertEqual((b, c), (8, 0))
        complete = [(k, o, n) for k, o, n in arrive if within(o) and within(n)]
        self.assertEqual(len(complete), 91)
        self.assertEqual((round(statistics.median(rows.values(complete, "all_in8_s", "base")), 1),
                          round(statistics.median(rows.values(complete, "all_in8_s", "arm")), 1)), (29.6, 24.5))
        self.assertAlmostEqual(stats.paired_se_mean(rows.diffs(complete, "all_in8_s")), 1.57, places=2)  # the quoted se 1.6

    def test_bridge_108_cells_by_the_verdict_rule(self):
        control = rows.bridge_cells(os.path.join(REF, "round30/brains/b3b-bridge108-control-4bc708d7.jsonl"))
        on = rows.bridge_cells(os.path.join(REF, "round30/brains/b3b-bridge108-on-4bc708d7.jsonl"))
        self.assertEqual((len(control), sum(control.values()), sum(on.values())), (108, 106, 107))
        self.assertEqual(sorted(k for k, v in control.items() if not v), [("green", 2, 5), ("rust", 2, 9)])
        self.assertEqual(sorted(k for k, v in on.items() if not v), [("green", 3, 18)])

    def test_t3b_rows_carry_the_crossing_clock_and_older_rows_do_not(self):
        import stats
        import statistics
        base = os.path.join(REF, "round30/traffic/t3b_judged_base_cf124433_seeds313233.jsonl")
        arm = os.path.join(REF, "round30/traffic/t3b_judged_arm_cf124433_seeds313233.jsonl")
        cases = rows.traffic_pairs(base, arm)
        yc = cases["yard_open/cross"]
        d = rows.diffs(yc, "xclear")
        self.assertAlmostEqual(statistics.mean(d), 2.80, places=2)  # the verdict's +2.80 s
        self.assertAlmostEqual(stats.paired_se_mean(d), 0.22, places=2)
        self.assertEqual((sum(rows.values(yc, "xfast", "base")), sum(rows.values(yc, "xfast", "arm"))), (100, 46))
        old = rows.traffic_pairs(os.path.join(REF, "round29/traffic/t3_judged_base_d9b3339c_seeds222324.jsonl"),
                                 os.path.join(REF, "round29/traffic/t3_judged_arm_d9b3339c_seeds222324.jsonl"))
        self.assertIsNone(rows.TRAFFIC_METRICS["xclear"](old["yard_open/cross"][0][1]))

    def test_t1cb_census_and_approach_pairs(self):
        census = rows.jsonl_pairs(os.path.join(REF, "round30/traffic/t1cb_judged_census_base_16780030_seeds789_131415.jsonl"),
                                  os.path.join(REF, "round30/traffic/t1cb_judged_census_arm_16780030_seeds789_131415.jsonl"),
                                  ["arena", "seed", "credits", "units"])
        self.assertEqual(len(census), 9)
        self.assertEqual((sum(rows.values(census, "art_shots", "base")), sum(rows.values(census, "art_shots", "arm"))), (318, 163))
        self.assertEqual(sum(1 for _k, b, _a in census if b["repacks_while_firing"] > 0), 4)
        drawn = rows.jsonl_pairs(os.path.join(REF, "round30/traffic/t1cb_judged_approach_base_16780030_seeds789_131415.jsonl"),
                                 os.path.join(REF, "round30/traffic/t1cb_judged_approach_arm_16780030_seeds789_131415.jsonl"),
                                 ["seed", "start_tick", "approach"], where={"approach": "east"})
        self.assertEqual(len(drawn), 18)
        self.assertEqual((sum(rows.values(drawn, "repacks", "base")), sum(rows.values(drawn, "repacks", "arm"))), (8, 2))

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
