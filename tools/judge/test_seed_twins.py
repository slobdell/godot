#!/usr/bin/env python3
"""seed_twins (R34.15): the random-arena twin of a fixed-arena fight is dropped, nothing else is."""
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import seed_twins  # noqa: E402


class SeedTwins(unittest.TestCase):
    def test_traffics_count_on_the_real_table(self):
        dealt, rot = seed_twins.load()
        self.assertIn("locks", rot)
        twins = [s for s in range(1200, 1248) if dealt[s] in ("locks", "terminus")]
        self.assertEqual(len(twins), 14)  # traffic's finding: 14 of 48 random seeds dealt the Locks or the Terminus

    def test_only_a_random_row_whose_dealt_map_is_in_the_series_on_that_seed_goes(self):
        dealt = {1: "locks", 2: "pit", 3: "terminus"}
        rows = [{"arena": "locks", "seed": 1}, {"arena": "random", "seed": 1},  # twin of the Locks 1: dropped
                {"arena": "terminus", "seed": 2}, {"arena": "random", "seed": 2},  # dealt the Pit: kept
                {"arena": "random", "seed": 3},  # dealt the Terminus, but the Terminus 3 is not in the series: kept
                {"arena": "random", "seed": 99}]  # outside the table: kept
        kept, dropped = seed_twins.drop_twins(rows, dealt)
        self.assertEqual(dropped, [{"arena": "random", "seed": 1}])
        self.assertEqual(len(kept), 5)

    def test_a_table_for_another_rotation_is_refused(self):
        path = os.path.join(tempfile.mkdtemp(), "t.txt")
        with open(path, "w") as handle:
            handle.write('# Arena.ROTATION ["yard", "pit"]\nRANDOM_ARENA 1 pit\n')
        with self.assertRaises(ValueError):
            seed_twins.load(path, rotation=["yard", "pit", "locks"])


def write_log(folder, name, census_arena=None, prefix="FAR_CENSUS"):
    path = os.path.join(folder, name)
    with open(path, "w") as handle:
        handle.write("noise\n")
        if census_arena is not None:
            handle.write('%s {"seed": 1, "arena": "%s"}\n' % (prefix, census_arena))
    return path


class TwinLogs(unittest.TestCase):
    """Round 35 (C35.9): a series folder of <arena>-<seed>.log files drops the random log that twins a fixed one."""

    def test_the_random_logs_own_census_names_the_dealt_map(self):
        d = tempfile.mkdtemp()
        files = [write_log(d, "locks-1200.log", "locks"), write_log(d, "random-1200.log", "locks"),  # twin: dropped
                 write_log(d, "terminus-1201.log", "terminus"), write_log(d, "random-1201.log", "pit"),  # kept
                 write_log(d, "random-1202.log", "locks")]  # dealt the Locks, no Locks 1202 in the series: kept
        kept, dropped = seed_twins.drop_twin_logs(files, dealt={})
        self.assertEqual([os.path.basename(f) for f, _s, _m in dropped], ["random-1200.log"])
        self.assertEqual(len(kept), 4)

    def test_the_census_beats_the_table_and_the_table_covers_a_log_without_one(self):
        d = tempfile.mkdtemp()
        files = [write_log(d, "locks-5.log", "locks"), write_log(d, "random-5.log", "pit", prefix="JAM_CENSUS"),
                 write_log(d, "pit-6.log", "pit"), write_log(d, "random-6.log")]  # no census: the table says pit
        kept, dropped = seed_twins.drop_twin_logs(files, dealt={5: "locks", 6: "pit"})
        self.assertEqual([os.path.basename(f) for f, _s, _m in dropped], ["random-6.log"])

    def test_other_names_and_folders_pass_through(self):
        d = tempfile.mkdtemp()
        sub = os.path.join(d, "x")
        os.mkdir(sub)
        files = [write_log(d, "summary.log"), write_log(sub, "locks-1.log", "locks"), write_log(d, "random-1.log", "locks")]
        kept, dropped = seed_twins.drop_twin_logs(files, dealt={})
        self.assertEqual(dropped, [])  # the fixed Locks 1 is in another folder: another series
        self.assertEqual(kept, files)

    def test_say_prints_one_line_per_drop_and_a_count(self):
        d = tempfile.mkdtemp()
        files = [write_log(d, "locks-1.log", "locks"), write_log(d, "random-1.log", "locks")]
        kept, lines = seed_twins.filter_logs(files, dealt={})
        self.assertEqual(len(kept), 1)
        self.assertTrue(lines[0].startswith("SEED_TWIN dropped random seed 1 (dealt locks"), lines)
        self.assertEqual(lines[-1], "SEED_TWINS kept 1 of 2 logs, dropped 1")


if __name__ == "__main__":
    unittest.main()
