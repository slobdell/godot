"""Round 32 (R32.7): pinned_table.py's STUCK reading restarts on a NEW goal. Run by tests/test_manoeuvre_tables.gd."""
import pathlib
import importlib.util
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("pinned_table", HERE / "pinned_table.py")
pinned_table = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pinned_table)


def _line(f, goal, throttle=0.8, unit="Green_X_1"):
    return ("MANOEUVRE_STATE f %d %s gang_tank order move_to from  v 5.00 moved 5.00 cmd %.2f/0.00 face 0/0.0 "
            "blocked false retry 0 touch false stuck 0.0 pivot false esc 0.0 goal %.1f real 5.00" % (f, unit, throttle, goal))


def _stuck(text):
    with tempfile.TemporaryDirectory() as d:
        log = pathlib.Path(d) / "run.log"
        log.write_text(text)
        return pinned_table.run_pinned(log)["stuck"]


class StuckReading(unittest.TestCase):
    def test_the_s303_green_s0_4_leg_change_is_not_stuck(self):
        # Terminus rigs seed 303, H1b arm (builder0, 9c46002a): 6.6 m from its goal at f 1740, the next leg's order at
        # f 1770 (69.8 m), then real progress down the new street to 7.0 m by f 2130. The old reader counted 13 s.
        text = (HERE / "fixtures" / "stuck_s303_green_s0_4.txt").read_text()
        self.assertEqual(_stuck(text), 0)

    def test_a_crew_pressing_without_progress_is_still_stuck(self):
        text = "\n".join(_line(30 * i, 20.0) for i in range(15))
        self.assertEqual(_stuck(text), 15)

    def test_a_new_goal_mid_press_ends_the_run_there(self):
        # 12 s pressing at 20 m (a run), then a new goal 60 m off driven down with progress every line.
        lines = [_line(30 * i, 20.0) for i in range(12)] + [_line(30 * (12 + i), 60.0 - 2.0 * i) for i in range(10)]
        self.assertEqual(_stuck("\n".join(lines)), 12)

    def test_a_small_slide_of_the_goal_is_the_same_approach(self):
        # A slot sliding back 2 m (< 3 m) is not a new goal: a press without progress stays one run.
        lines = [_line(30 * i, 20.0 + (2.0 if i == 6 else 0.0)) for i in range(14)]
        self.assertEqual(_stuck("\n".join(lines)), 14)


if __name__ == "__main__":
    unittest.main()
