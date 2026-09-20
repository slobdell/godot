#!/usr/bin/env python3
"""tools/shell_console.py's own tests. Round 8's lesson: a guard that has never been run end to end is not a guard --
two shipped that round, one crashed every run it was meant to protect and the other exited 0 while refusing."""
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

import shell_console


LOG = """
Godot Engine v4.7.2.stable.official
SHELL_PLAYTEST {"step": "title"}
ERROR: Texture with GL ID 4127 leaked 5460 bytes
   at: (drivers/gles3/storage/texture_storage.cpp:1421)
ERROR: Texture with GL ID 9033 leaked 5460 bytes
WARNING: MultiMesh interpolation is being triggered from _process
SHELL_PLAYTEST_DONE ok=true
"""


class TestClasses(unittest.TestCase):
    def test_the_same_fault_with_different_numbers_is_one_class(self) -> None:
        found = shell_console.classes(LOG)
        leaks = [text for text in found if "leaked" in text]
        self.assertEqual(len(leaks), 1, f"two leaks with different GL ids are one class, got {leaks}")
        self.assertEqual(found[leaks[0]], 2, "counted twice")

    def test_ordinary_output_is_not_a_fault(self) -> None:
        found = shell_console.classes(LOG)
        self.assertTrue(all("SHELL_PLAYTEST" not in text for text in found), found)
        self.assertTrue(all("Godot Engine" not in text for text in found), found)

    def test_a_clean_console_has_no_classes(self) -> None:
        self.assertEqual(shell_console.classes("SHELL_PLAYTEST_DONE ok=true\n"), {})


class TestRoundTrip(unittest.TestCase):
    def _files(self, directory: str, log: str) -> tuple[Path, Path]:
        log_path = Path(directory, "run.log")
        log_path.write_text(log)
        return log_path, Path(directory, "baseline.txt")

    def test_a_written_baseline_compares_equal_to_its_own_log(self) -> None:
        with TemporaryDirectory() as directory:
            log_path, baseline = self._files(directory, LOG)
            baseline.write_text(shell_console.render(shell_console.classes(log_path.read_text())))
            self.assertEqual(shell_console.parse(baseline.read_text()), shell_console.classes(log_path.read_text()))

    def test_a_new_fault_is_a_change_and_a_fixed_one_is_too(self) -> None:
        expected = shell_console.classes(LOG)
        worse = shell_console.classes(LOG + "ERROR: Something entirely new went wrong\n")
        self.assertNotEqual(worse, expected, "a new fault must not compare equal")
        better = shell_console.classes(LOG.replace("ERROR: Texture with GL ID 9033 leaked 5460 bytes\n", ""))
        self.assertNotEqual(better, expected, "a fault that STOPPED happening is news too, not a silent pass")


if __name__ == "__main__":
    unittest.main()
