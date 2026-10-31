#!/usr/bin/env python3
"""Spotter S2 (round 48, C48.2): the fixed class rule. Each class A-E must catch a staged crew that shows it and must NOT catch
the near miss one second / one metre short of its threshold (lesson 350: every deciding line fails once on a case it must
catch). `make spotter-test` (stdlib unittest, no Godot)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools", "spotter"))
import classes as K  # noqa: E402

HEADER = {"t": "fight", "seed": 13121, "arena": "crossing"}


def row(s, crew="Green_Guns_1", **kw):
    r = {"t": "crew", "s": s, "tick": s * 30, "crew": crew, "team": 0, "unit": "gang_tank", "squad": "Guns", "x": 0.0, "z": 0.0,
         "yaw": 0.0, "speed": 6.0, "hp": 400.0, "order": "move", "choice": "MOVE", "intent": "MOVE - ordered", "move": "move_to",
         "phase": "driving", "blocked": "", "touch": False, "touch_cause": "", "touch_what": "", "range": 50.0, "shots": 0,
         "hit_dmg": 0.0, "fire_far": 0.0, "fire_off": 0.0, "to_go": 100.0 - s, "gain_5": 30.0, "route_off": 5.0,
         "squad_d": 8.0, "squad_n": 5}
    r.update(kw)
    return r


def staged(n_bad, **bad):
    """30 s of ordinary driving with seconds 10 .. 10+n_bad-1 replaced by the `bad` fields."""
    return [row(s, **(bad if 10 <= s < 10 + n_bad else {})) for s in range(1, 31)]


def classes_of(rows, crew="Green_Guns_1"):
    ms = K.classify_fight(HEADER, rows, "crossing-13121")
    return {m["cls"]: m for m in ms if m["crew"] == crew}


class ClassRuleTest(unittest.TestCase):
    def test_ordinary_driving_has_no_class(self):
        self.assertEqual(classes_of(staged(0)), {})

    def test_A_retreat_far_from_squad(self):
        got = classes_of(staged(6, choice="RETREAT", order="attack_move", squad_d=60.0, hp=20.0))
        self.assertIn("A", got)
        self.assertEqual(got["A"]["crew_seconds"], 6 - K.A_FAR_S + 1)
        self.assertNotIn("A", classes_of(staged(K.A_FAR_S - 1, choice="RETREAT", squad_d=60.0)))
        self.assertNotIn("A", classes_of(staged(6, choice="RETREAT", squad_d=K.A_SPREAD_M - 1)))

    def test_A_retreat_reversing(self):
        self.assertIn("A", classes_of(staged(K.A_REVERSE_S, choice="RETREAT", speed=-4.0)))
        self.assertNotIn("A", classes_of(staged(K.A_REVERSE_S - 1, choice="RETREAT", speed=-4.0)))

    def test_E_outranged_hits_in_a_window(self):
        hit = dict(hit_dmg=20.0, fire_far=80.0)
        got = classes_of(staged(K.E_HITS, **hit))
        self.assertIn("E", got)
        self.assertEqual(got["E"]["crew_seconds"], K.E_WINDOW_S - K.E_HITS + 1)  # from the second the window fills until it drains
        self.assertNotIn("E", classes_of(staged(K.E_HITS - 1, **hit)))
        self.assertNotIn("E", classes_of(staged(8, hit_dmg=20.0, fire_far=50.0)))  # inside its own reach
        # salvos: a hit every other second over the window still counts
        rows = [row(s, **(hit if 10 <= s < 20 and s % 2 == 0 else {})) for s in range(1, 31)]
        self.assertNotIn("E", classes_of(rows))  # 4 of 8
        rows = [row(s, **(hit if 10 <= s < 22 and s % 3 != 0 else {})) for s in range(1, 31)]
        self.assertIn("E", classes_of(rows))  # 5+ of 8
        closing = [row(s, **(dict(hit_dmg=20.0, fire_far=120.0 - 4.0 * s) if 10 <= s < 20 else {})) for s in range(1, 31)]
        self.assertNotIn("E", classes_of(closing))  # closing 4 m a second on its shooter: E10's answer
        slow = [row(s, **(dict(hit_dmg=20.0, fire_far=120.0 - 1.0 * s) if 10 <= s < 20 else {})) for s in range(1, 31)]
        self.assertIn("E", classes_of(slow))  # 1 m a second is not an answer

    def test_C_stuck_on_terrain(self):
        stuck = dict(phase="blocked", blocked="no_path", speed=0.0, gain_5=0.0)
        self.assertIn("C", classes_of(staged(K.C_RUN_S, **stuck)))
        self.assertNotIn("C", classes_of(staged(K.C_RUN_S - 1, **dict(stuck, gain_5=5.0))))  # blocked but gaining
        self.assertNotIn("C", classes_of(staged(K.STUCK_S - 1, **stuck)))
        wall = dict(touch=True, touch_cause="wall", touch_what="Barricade_45", speed=0.1)
        self.assertIn("C", classes_of(staged(K.C_RUN_S, **wall)))
        backing = dict(touch=True, touch_cause="wall", touch_what="Barricade_45", speed=-3.0)
        self.assertIn("C", classes_of(staged(K.C_RUN_S, **backing)))  # reversing into a prop (batch 1 #26)

    def test_B_give_way_loop(self):
        jam = dict(phase="yielding", blocked="Green_Guns_2", speed=-1.0)
        got = classes_of(staged(K.B_RUN_S, **jam))
        self.assertIn("B", got)
        self.assertNotIn("C", got)
        self.assertNotIn("B", classes_of(staged(K.B_RUN_S - 1, **jam)))

    def test_B_held_crew_gives_way_sooner(self):
        held = dict(order="hold", choice="HOLD", phase="yielding", blocked="Green_Guns_2")
        self.assertIn("B", classes_of(staged(K.B_HOLD_S, **held)))
        self.assertNotIn("B", classes_of(staged(K.B_HOLD_S - 1, **held)))

    def test_D_driving_away(self):
        away = dict(route_off=150.0)
        self.assertIn("D", classes_of(staged(K.D_WRONGWAY_S, **away)))
        self.assertNotIn("D", classes_of(staged(K.D_WRONGWAY_S - 1, **away)))

    def test_stuck_goes_to_its_cause(self):
        crawl = dict(gain_5=0.0, speed=3.0)
        self.assertIn("D", classes_of(staged(K.STUCK_S, **crawl)))
        self.assertNotIn("D", classes_of(staged(K.STUCK_S - 1, **crawl)))
        self.assertIn("B", classes_of(staged(K.STUCK_S, gain_5=0.0, phase="yielding", blocked="Green_Guns_2")))
        self.assertIn("C", classes_of(staged(K.STUCK_S, gain_5=0.0, phase="blocked", blocked="terrain")))

    def test_D_follower_reversing_or_spinning(self):
        fol = dict(order="follow", choice="FOLLOW", speed=-3.0, follow_live=True)
        self.assertIn("D", classes_of(staged(K.D_FOLLOW_S, **fol)))
        self.assertNotIn("D", classes_of(staged(K.D_FOLLOW_S - 1, **fol)))
        rows = [row(s, **(dict(order="follow", speed=0.0, yaw=60.0 * s) if 10 <= s < 10 + K.D_FOLLOW_S + 1 else {}))
                for s in range(1, 31)]
        self.assertIn("D", classes_of(rows))

    def test_F_holds_fire_in_range(self):
        hold = dict(near_enemy=30.0, shots=0, since_fire=300, weap="fire_at_will")
        self.assertIn("F", classes_of(staged(K.F_RUN_S, **hold)))
        self.assertNotIn("F", classes_of(staged(K.F_RUN_S - 1, **hold)))
        self.assertNotIn("F", classes_of(staged(12, **dict(hold, near_enemy=48.0))))  # beyond 0.9 x range
        self.assertNotIn("F", classes_of(staged(12, **dict(hold, near_enemy=-1.0))))  # nobody in sight
        self.assertNotIn("F", classes_of(staged(12, **dict(hold, weap="hold_fire"))))  # told to hold fire
        self.assertNotIn("F", classes_of(staged(12, **dict(hold, arc=True))))  # artillery
        self.assertNotIn("F", classes_of(staged(12, **dict(hold, since_fire=30))))  # it has just fired

    def test_F_cause(self):
        hold = dict(near_enemy=30.0, shots=0, since_fire=300)
        self.assertEqual(classes_of(staged(10, **dict(hold, intent="HOLD - base of fire, support by fire")))["F"]["f_cause"],
                         "support by fire")
        self.assertEqual(classes_of(staged(10, **dict(hold, intent="HOLD - spring ambush")))["F"]["f_cause"],
                         "ambush (holds fire on purpose)")
        self.assertEqual(classes_of(staged(10, **hold))["F"]["f_cause"], "moving")

    def test_F_is_last(self):
        both = dict(near_enemy=30.0, since_fire=300, hit_dmg=20.0, fire_far=80.0)
        got = classes_of(staged(12, **both))
        self.assertIn("E", got)
        self.assertNotIn("F", got.get("E", {}).get("cls", ""))

    def test_paired_compare(self):
        before = {"per_fight": {"crossing-1": {"B": [4, 40]}, "crossing-2": {"B": [6, 60]}, "locks-9": {"B": [9, 9]}}}
        after = {"per_fight": {"crossing-1": {"B": [1, 10]}, "crossing-2": {"B": [3, 20]}, "gorge-3": {"B": [0, 0]}}}
        cmp = K.compare(before, after)
        self.assertEqual(cmp["fights"], 2)  # only the fights both ran
        b = cmp["classes"]["B"]["moments"]
        self.assertEqual((b["before"], b["after"], b["diff"]), (5.0, 2.0, -3.0))
        self.assertEqual(cmp["classes"]["A"]["moments"]["diff"], 0.0)

    def test_precedence_A_over_D(self):
        got = classes_of(staged(8, choice="RETREAT", squad_d=60.0, route_off=150.0))
        self.assertIn("A", got)
        self.assertNotIn("D", got)

    def test_gap_breaks_a_run(self):
        rows = [r for r in staged(K.E_HITS, hit_dmg=20.0, fire_far=80.0) if r["s"] != 11]
        self.assertNotIn("E", classes_of(rows))

    def test_moment_has_repro_and_rows(self):
        m = classes_of(staged(6, choice="RETREAT", squad_d=60.0))["A"]
        self.assertIn("make spotter-clip SPOT_SEED=13121 SPOT_ARENA=crossing SPOT_CREW=Green_Guns_1", m["repro"])
        self.assertEqual(len(m["rows"]), 6 - K.A_FAR_S + 1)
        self.assertEqual((m["start_s"], m["run_start_s"], m["end_s"]), (10 + K.A_FAR_S - 1, 10, 15))

    def test_E_cause(self):
        hit = dict(hit_dmg=20.0, fire_far=80.0)
        self.assertEqual(classes_of(staged(8, **hit))["E"]["e_cause"], "no answer")
        ans = dict(hit, intent="HOLD - outranged: breaking line of sight")
        self.assertEqual(classes_of(staged(8, **ans))["E"]["e_cause"], "answering")

    def test_B_cause_parked_blocker(self):
        jam = dict(phase="blocked", blocked="Green_Guns_2", speed=0.0)
        mover = staged(K.B_RUN_S + 2, **jam)
        parked = [row(s, crew="Green_Guns_2", order="hold", choice="HOLD", move="face", phase="yielding", speed=0.0)
                  for s in range(1, 31)]
        moving = [row(s, crew="Green_Guns_2") for s in range(1, 31)]
        self.assertEqual(classes_of(mover + parked)["B"]["b_cause"], "parked blocker")
        self.assertEqual(classes_of(mover + moving)["B"]["b_cause"], "moving squadmates")
        held = staged(K.B_HOLD_S + 1, order="hold", choice="HOLD", phase="yielding", blocked="Green_Guns_2")
        self.assertEqual(classes_of(held)["B"]["b_cause"], "held crew gives way")


if __name__ == "__main__":
    unittest.main()
