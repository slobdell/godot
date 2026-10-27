#!/usr/bin/env python3
"""tools/balance/search.py's own tests (`make balance-pytest`): his +/-15 % bounds, shared weapons, the --tune string."""
import json
import sys
import pathlib
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import search  # noqa: E402

CATALOG = {
    "units": {
        "gang_tank": {"faction": "gangs", "role": "tank", "cost": 175, "max_health": 420, "max_shield": 0.0,
                      "weapon": "scrap_cannon", "armor": {"front": 7.0, "side": 4.0, "rear": 2.0}},
        "ifv": {"faction": "condemned", "cost": 150, "max_health": 220, "max_shield": 100, "weapon": "autocannon",
                "armor": {"front": 7.0, "side": 3.0, "rear": 2.0}},
        "law_ifv": {"faction": "law", "cost": 195, "max_health": 280, "max_shield": 120.0, "weapon": "autocannon",
                    "armor": {"front": 9.0, "side": 4.0, "rear": 2.0}},
    },
    "weapons": {"scrap_cannon": {"damage": 260.0}, "autocannon": {"damage": 15.0}},
}


class SearchTest(unittest.TestCase):
    def test_bounds(self):
        ok = {"units": {"gang_tank": {"max_health": 483, "armor": {"front": 8.05}}}, "weapons": {"scrap_cannon": {"damage": 299}}}
        self.assertEqual(search.check(ok, CATALOG), [])
        far = {"units": {"gang_tank": {"max_health": 484}}}
        self.assertEqual(len(search.check(far, CATALOG)), 1)
        self.assertEqual(len(search.check({"units": {"gang_tank": {"sight_radius": 12}}}, CATALOG)), 1)

    def test_levers_any_size_once_catalogued(self):
        # Round 41 (C41.5): his levers are not bounded, but the catalog must carry them (make balance-catalog).
        self.assertEqual(len(search.check({"units": {"gang_tank": {"max_forward_speed": 12}}}, CATALOG)), 1)
        cat = {"units": {"gang_tank": dict(CATALOG["units"]["gang_tank"], max_forward_speed=11.0, max_reverse_speed=5.0,
                                           hull_turn_rate_deg=70.0, turret_turn_rate_deg=60.0)}, "weapons": CATALOG["weapons"]}
        self.assertEqual(search.check({"units": {"gang_tank": {"turret_turn_rate_deg": 30, "max_forward_speed": 5.5}}}, cat), [])
        self.assertEqual(len(search.check({"units": {"gang_tank": {"turret_turn_rate_deg": 0}}}, cat)), 1)
        cand = search.scale("t50h25", ["role:tank:turret=0.5,speed=0.75,hturn=0.75"], cat)
        self.assertEqual(cand["units"]["gang_tank"], {"turret_turn_rate_deg": 30.0, "max_forward_speed": 8.25,
                                                      "max_reverse_speed": 3.75, "hull_turn_rate_deg": 52.5})
        self.assertEqual(search.check(cand, cat), [])
        self.assertIn("gang_tank.turret_turn_rate_deg=30", search.tune_string(cand))

    def test_shared_weapon_refused(self):
        problems = search.check({"weapons": {"autocannon": {"damage": 16}}}, CATALOG)
        self.assertTrue(any("shared" in p for p in problems))

    def test_tune_string_skips_cost(self):
        cand = {"units": {"gang_tank": {"max_health": 483, "cost": 160, "armor": {"front": 8.05}}},
                "weapons": {"scrap_cannon": {"damage": 299}}}
        self.assertEqual(search.tune_string(cand),
                         "gang_tank.armor.front=8.05,gang_tank.max_health=483,scrap_cannon.damage=299")
        self.assertTrue(search.moves_cost(cand))

    def test_scale_skips_shared_and_zero_shield(self):
        cand = search.scale("t", ["law:hp=1.1,dmg=1.1", "gangs:hp=1.15,dmg=1.15"], CATALOG)
        self.assertEqual(cand["units"]["gang_tank"], {"max_health": 483.0})  # no shield to scale
        self.assertEqual(cand["units"]["law_ifv"]["max_shield"], 132.0)
        self.assertNotIn("autocannon", cand["weapons"])
        self.assertEqual(cand["weapons"]["scrap_cannon"], {"damage": 299.0})
        self.assertEqual(search.check(cand, CATALOG), [])

    def test_flatness_zero_when_every_cell_equal(self):
        fights = []
        for i, (g, c) in enumerate([("gangs", "law"), ("law", "gangs")] * 2):
            fights.append({"guard": "blob", "side": "Green", "winner": "Green" if i < 2 else "Rust",
                           "factions": {"Green": g, "Rust": c}, "_key": ("blob", "a", i, "green")})
        self.assertAlmostEqual(search.flatness(fights), 0.0)

    def test_apply_rewrites_only_the_named_block(self):
        import tempfile
        units = ('const PROFILES := {\n\t"gang_tank": {\n\t\t"cost": 175,\n\t\t"max_health": 420,\n'
                 '\t\t"armor": {"front": 7.0, "side": 4.0, "rear": 2.0},\n\t},\n\t"gang_ifv": {\n\t\t"cost": 110,\n'
                 '\t\t"max_health": 170,\n\t},\n}\n')
        weapons = 'const PROFILES := {\n\t"scrap_cannon": {\n\t\t"damage": 260.0,\n\t},\n}\n'
        with tempfile.TemporaryDirectory() as tmp:
            u, w = pathlib.Path(tmp) / "u.gd", pathlib.Path(tmp) / "w.gd"
            u.write_text(units)
            w.write_text(weapons)
            search.apply({"units": {"gang_tank": {"max_health": 483, "cost": 160, "armor": {"front": 8.05}}},
                          "weapons": {"scrap_cannon": {"damage": 299}}}, u, w)
            out = u.read_text()
            self.assertIn('"cost": 160,\n\t\t"max_health": 483,', out)
            self.assertIn('"armor": {"front": 8.05, "side": 4.0, "rear": 2.0}', out)
            self.assertIn('"gang_ifv": {\n\t\t"cost": 110,\n\t\t"max_health": 170,', out)
            self.assertIn('"damage": 299.0,', w.read_text())

    def test_check_refuses_a_rear_that_breaks_the_from_behind_rule(self):
        cat = {"units": {"gang_tank": {"faction": "gangs", "cost": 175, "max_health": 420, "max_shield": 0.0,
                                       "weapon": "twin_mg", "armor": {"front": 7.0, "side": 4.0, "rear": 2.0}},
                         "syn_scout": {"faction": "syndicate", "cost": 210, "max_health": 150, "max_shield": 160.0,
                                       "weapon": "twin_mg", "armor": {"front": 2.0, "side": 2.0, "rear": 2.0}}},
               "weapons": {"twin_mg": {"damage": 3.0, "penetration": 2.5}}}
        self.assertEqual(search.check({}, cat), [], "today's catalog keeps the rule")
        # +15 % rear on a War Rig: the twin MG from behind falls under 0.4 (the ARM 494a3d33d failure).
        self.assertTrue(search.check({"units": {"gang_tank": {"armor": {"rear": 2.3}}}}, cat))
        # A cut front under an unmoved rear: the rear is now harder than the front (the ARM ad956031b failure).
        self.assertTrue(search.check({"units": {"syn_scout": {"armor": {"front": 1.7, "side": 1.7}}}}, cat))
        self.assertEqual(search.check({"units": {"syn_scout": {"armor": {"front": 1.7, "side": 1.7, "rear": 1.7}}}}, cat), [])

    def test_bar_b7_lists_and_judge(self):
        self.assertEqual([search.b7_arena(s) for s in (9901, 9908, 9909, 9933, 9940)],
                         ["terminus", "terminus", "locks", "parade", "parade"])
        on = search.b7_fights("on")
        self.assertEqual(len(on), 360, "320 deciding + 40 G1 an arm")
        self.assertEqual(len({tuple(x.split()[:3]) for x in on}), 360, "every fight its own (folder, arena, seed)")
        self.assertTrue(all(x.endswith("--cpu-counter=on") for x in on))
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            for arm in ("off", "on"):
                for line in search.b7_fights(arm):
                    folder, arena, seed = line.split()[:3]
                    seed = int(seed)
                    d = root / f"c0ffee-{folder}" / "none"
                    d.mkdir(parents=True, exist_ok=True)
                    mono_green = "-player " in f"{folder} " or folder.endswith("-player")
                    countered = arm == "on" and folder.startswith("b7-") and "-condemned-" in folder
                    # condemned's counter halves all-tanks' wins; every other fight is the same ON and OFF.
                    mono_won = (seed % 2 == 0) if countered else (seed % 5 != 0)
                    winner = ("Green" if mono_green else "Rust") if mono_won else ("Rust" if mono_green else "Green")
                    r = {"winner": winner, "seconds": 200 + seed % 7, "tanks": {"green": 9, "rust": 7}}
                    (d / f"{arena}-{seed}-green.log").write_text(
                        "ARMY_CAP preset=desktop squads=5 units=25\n" + ("CPU_COUNTER faction=condemned\n" if countered else "")
                        + "ARMY_CAP_FIELDED squads=5 green_squads=4 green=20 rust_squads=5 rust=25\n"
                        + "GUARD_RESULT " + json.dumps(r) + "\n")
            self.assertEqual(search.bar_b7(root, "c0ffee", ["condemned"]), 0, "condemned 80 -> 50 % passes")
            self.assertEqual(search.bar_b7(root, "c0ffee", ["condemned", "law"]), 1, "law did not move: fails")


if __name__ == "__main__":
    unittest.main()
