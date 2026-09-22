"""paired_arms: the pairing, the discordant counts, the exact McNemar p, and the refusal of unpaired inputs."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paired_arms  # noqa: E402


def game(seed, green_first, winner, faction="gangs", other="law"):
    return {"faction": faction, "other": other, "seed": seed, "first_is_green": green_first, "winner": winner}


class PairedArms(unittest.TestCase):
    def test_mcnemar_is_exact_and_symmetric(self):
        self.assertEqual(paired_arms.mcnemar_p(0, 0), 1.0)
        self.assertAlmostEqual(paired_arms.mcnemar_p(5, 0), 2 * (1 / 32))  # all five discordant one way
        self.assertAlmostEqual(paired_arms.mcnemar_p(3, 7), paired_arms.mcnemar_p(7, 3))
        self.assertEqual(paired_arms.mcnemar_p(4, 4), 1.0)

    def test_games_pair_by_seed_and_colour_and_count_discordant(self):
        treatment = paired_arms.games_by_key({"games": [
            game(1, True, "green"), game(1, False, "rust"), game(2, True, "rust"), game(3, True, "green")]}, "t")
        control = paired_arms.games_by_key({"games": [
            game(1, True, "rust"), game(1, False, "rust"), game(2, True, "green"), game(4, True, "green")]}, "c")
        cell = paired_arms.paired_cells(treatment, control)[("gangs", "law")]
        # seed 3 and seed 4 have no partner; seed 1 green: t won, c lost (b); seed 1 rust: both won (concordant);
        # seed 2 green: c won, t lost (c).
        self.assertEqual(cell["pairs"], 3)
        self.assertEqual((cell["b"], cell["c"]), (1, 1))
        self.assertEqual((cell["treatment_wins"], cell["control_wins"]), (2, 2))

    def test_a_draw_is_not_a_win(self):
        treatment = paired_arms.games_by_key({"games": [game(1, True, "draw")]}, "t")
        control = paired_arms.games_by_key({"games": [game(1, True, "green")]}, "c")
        cell = paired_arms.paired_cells(treatment, control)[("gangs", "law")]
        self.assertEqual((cell["b"], cell["c"]), (0, 1))

    def test_a_file_without_games_is_refused(self):
        with self.assertRaises(SystemExit):
            paired_arms.games_by_key({"rows": []}, "old.json")


if __name__ == "__main__":
    unittest.main()
