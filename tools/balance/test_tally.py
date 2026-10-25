#!/usr/bin/env python3
"""tools/balance/tally.py's own tests (`make balance-pytest`): a three-kill fixture whose tally is known by hand."""
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import tally  # noqa: E402

CATALOG = {
    "squads": {"tank": {"name": "Guns"}, "scout": {"name": "Eyes"}, "gangs/scout": {"name": "Spears"}},
    "units": {
        "gang_scout": {"display_name": "Rat Rod", "role": "scout", "faction": "gangs", "cost": 70, "squad_key": "gangs/scout"},
        "gang_tank": {"display_name": "War Rig", "role": "tank", "faction": "gangs", "cost": 175, "squad_key": "tank"},
        "syn_tank": {"display_name": "Railgun Platform", "role": "tank", "faction": "syndicate", "cost": 470,
                     "squad_key": "tank"},
    },
}


class TallyTest(unittest.TestCase):
    def test_kill_line_names(self):
        # Numbered squads (Guns2), renamed squads (Eyes II) and friendly fire all parse.
        for line, killer, victim in [
            ("Green_Guns2_3 destroyed Rust_Eyes_1 (score)", "Guns", "Eyes"),
            ("Rust_Spears_4 destroyed Green_Eyes II_6 (score Green 0 : 1 Rust)", "Spears", "Eyes"),
            ("Green_Guns_4 destroyed teammate Green_Eyes2_3 (friendly fire)", "Guns", "Eyes"),
        ]:
            m = tally.KILL.match(line)
            self.assertIsNotNone(m, line)
            self.assertEqual((m.group(2), m.group(6)), (killer, victim))

    def test_deal_parses_plurals(self):
        self.assertEqual(tally.parse_deal("2 rat rods, 1 war rig (315 pts)", CATALOG, "gangs"),
                         {"gang_scout": 2, "gang_tank": 1})

    def test_fixture_tally(self):
        with tempfile.TemporaryDirectory() as tmp:
            cat = pathlib.Path(tmp) / "catalog.json"
            cat.write_text(json.dumps(CATALOG))
            out = pathlib.Path(tmp) / "t.json"
            subprocess.run([sys.executable, str(HERE / "tally.py"), "--catalog", str(cat), str(HERE / "fixtures/run"),
                            "--json", str(out)], check=True, capture_output=True)
            data = json.loads(out.read_text())
        rows = {r["unit"]: r for r in data["units"] if r["kind"] == "all"}
        self.assertEqual(data["fights"], 1)
        self.assertEqual((rows["gang_scout"]["fielded"], rows["gang_scout"]["kills"], rows["gang_scout"]["losses"],
                          rows["gang_scout"]["friendly_kills"]), (2, 1, 1, 1))
        self.assertEqual((rows["gang_tank"]["kills"], rows["gang_tank"]["losses"]), (0, 1))
        self.assertEqual((rows["syn_tank"]["kills"], rows["syn_tank"]["losses"]), (1, 1))
        # The railgun's one kill was a 70-credit rat rod: 70 / 470 of its cost back.
        self.assertAlmostEqual(rows["syn_tank"]["kill_value_per_credit"], 70 / 470)


if __name__ == "__main__":
    unittest.main()
