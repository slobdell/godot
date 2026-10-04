"""Round 18 (maps, M2): the room / chokepoint / ambush instrument must read the maps the lead has played as he
described them, or the measure is wrong. His words: *"with the narrow corridors that exist on all the maps currently
I never get to just have vehicles move line abreast"*. So the corridor maps score near zero room for a line of four
and no flank-ambush ground for a line crossing the centre; the cut open map (foundry) scores room; the candidate he
asked for scores room AND ambush ground on the base-to-base axis."""

import json
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import arena_room  # noqa: E402

ARENAS = pathlib.Path(__file__).resolve().parent.parent / "arenas"
_CACHE = {}


def measured(name):
    if name not in _CACHE:
        with open(ARENAS / (name + ".json")) as f:
            _CACHE[name] = arena_room.measure(json.load(f), with_report=False)
    return _CACHE[name]


class ArenaRoomTest(unittest.TestCase):
    def test_the_frontages_are_read_from_the_formation(self):
        # A line of four at 12 m: hull centres 36 m apart end to end, plus the corridor margin each side.
        self.assertAlmostEqual(arena_room.LINE_FRONTAGE, 3 * arena_room.SPACING + 2 * arena_room.CORRIDOR_MARGIN)
        self.assertGreater(arena_room.LINE_FRONTAGE, arena_room.WEDGE_FRONTAGE)

    def test_the_corridor_maps_have_no_room_for_a_line(self):
        for name in ("yard", "terminus"):
            m = measured(name)
            self.assertLess(m["room"]["line_share"], 0.15, "%s reads as open: %s" % (name, m["room"]))
            self.assertEqual(m["ambush"]["base_to_base"]["hulls"], 0, "%s: a line cannot cross its centre" % name)

    def test_the_open_maps_read_open(self):
        self.assertGreater(measured("foundry")["room"]["line_share"], 0.7)
        parade = measured("parade")
        self.assertGreater(parade["room"]["line_share"], 0.4)
        self.assertGreaterEqual(parade["room"]["widest_frontage_m"], 110.0, "three squads abreast")
        # His map: a line crossing the middle base to base can be shot down its length from hidden cover.
        self.assertEqual(parade["ambush"]["base_to_base"]["stations"], len(arena_room.STATIONS_M))
        self.assertGreater(parade["ambush"]["base_to_base"]["hulls"], 4)

    def test_sealing_a_neck_finds_the_way_round(self):
        # A synthetic map: a wall across the middle with one 16 m gap; sealing it leaves no way round.
        layout = {"name": "neck", "half_size": 120.0, "obstacles": [
            {"type": "wall", "position": [-66.0, 0.0], "size": [116.0, 3.0, 2.0], "rotation_deg": 0.0},
            {"type": "wall", "position": [66.0, 0.0], "size": [116.0, 3.0, 2.0], "rotation_deg": 0.0}],
            "spawns": {"green": [[0.0, 100.0]], "rust": [[0.0, -100.0]]}}
        found, _ = arena_room.chokepoints(*arena_room.ground(layout)[1:], layout,
                                          [("base to base", (0.0, 100.0), (0.0, -100.0))])
        self.assertEqual(len(found), 1, found)
        self.assertFalse(found[0]["way_round"])
        self.assertLess(found[0]["width_m"], 20.0)


if __name__ == "__main__":
    unittest.main()
