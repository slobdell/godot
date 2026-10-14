#!/usr/bin/env python3
"""Known-answer tests for tools/judge/stats.py. An instrument's bugs arrive disguised as results (tools/test_compare_arms.py),
and this instrument sets every bar's n, so each function is checked against a value computed another way."""
import math
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stats  # noqa: E402


class Normal(unittest.TestCase):
    def test_ppf_inverts_cdf_at_the_textbook_points(self):
        self.assertAlmostEqual(stats.norm_ppf(0.95), 1.6449, places=4)
        self.assertAlmostEqual(stats.norm_ppf(0.975), 1.9600, places=4)
        self.assertAlmostEqual(stats.norm_ppf(0.8), 0.8416, places=4)
        for p in (0.001, 0.01, 0.3, 0.5, 0.7, 0.99, 0.999):
            self.assertAlmostEqual(stats.norm_cdf(stats.norm_ppf(p)), p, places=8)


class PairedNoise(unittest.TestCase):
    def test_se_of_a_total_is_sd_root_n(self):
        d = [1, -1, 2, -2, 3, -3]  # sd = sqrt(28/5)
        self.assertAlmostEqual(stats.paired_sd(d), math.sqrt(5.6), places=9)
        self.assertAlmostEqual(stats.paired_se_total(d), math.sqrt(5.6) * math.sqrt(6), places=9)
        self.assertAlmostEqual(stats.paired_se_mean(d), math.sqrt(5.6) / math.sqrt(6), places=9)

    def test_hull_rest_table_se_is_reproduced(self):
        # hull_rest_ab.py prints se = stdev(diffs) * n / sqrt(n) = stdev * sqrt(n): the same number.
        d = [0, 0, 1, -1, 3, 0, 2, 0, 0, -2]
        self.assertAlmostEqual(stats.paired_se_total(d), stats.paired_sd(d) * len(d) / math.sqrt(len(d)), places=12)

    def test_identical_arms_have_no_noise_and_are_not_acted(self):
        self.assertEqual(stats.paired_sd([0.0] * 18), 0.0)
        self.assertEqual(stats.acted([0.0, 0.0, 2.0, -1.0, 0.0]), [2.0, -1.0])

    def test_variance_components_balanced_anova(self):
        # Two seeds, three ticks each; seed means 0 and 6, within-seed deviations +-1, 0.
        groups = {1: [-1.0, 0.0, 1.0], 2: [5.0, 6.0, 7.0]}
        vc = stats.variance_components(groups)
        # ms_within = (1+0+1+1+0+1)/(6-2) = 1; ms_between = 3*((0-3)^2+(6-3)^2)/1 = 54; between = (54-1)/3
        self.assertAlmostEqual(vc["within"], 1.0, places=9)
        self.assertAlmostEqual(vc["between"], 53.0 / 3.0, places=9)
        self.assertGreater(vc["icc"], 0.9)
        # with the seed variance dominant, 6 seeds x 1 tick beats 2 x 3 for the same six runs
        self.assertLess(vc["alternatives"]["6 seeds x 1 ticks"], vc["alternatives"]["2 seeds x 3 ticks"])

    def test_variance_components_with_no_seed_effect_prefer_nothing(self):
        groups = {1: [-1.0, 1.0, 0.0], 2: [1.0, -1.0, 0.0], 3: [0.0, 1.0, -1.0]}
        vc = stats.variance_components(groups)
        self.assertEqual(vc["between"], 0.0)
        self.assertAlmostEqual(vc["alternatives"]["9 seeds x 1 ticks"], vc["alternatives"]["3 seeds x 3 ticks"], places=9)


class Sizing(unittest.TestCase):
    def test_n_paired_matches_the_textbook_formula(self):
        # (1.645 + 0.842)^2 * (sd/delta)^2 with sd/delta = 4 -> 98.9 -> 99
        self.assertEqual(stats.n_paired(4.0, 1.0), 99)
        # two-sided: (1.96 + 0.842)^2 * 16 = 125.6 -> 126
        self.assertEqual(stats.n_paired(4.0, 1.0, one_sided=False), 126)

    def test_n_paired_edge_cases(self):
        self.assertIsNone(stats.n_paired(1.0, 0.0))
        self.assertEqual(stats.n_paired(0.0, 1.0), 1)
        self.assertEqual(stats.n_paired(0.1, 10.0), 2)

    def test_mde_inverts_n(self):
        sd, n = 31.0, 18
        delta = stats.mde(sd, n)
        self.assertAlmostEqual(stats.n_paired(sd, delta), n, delta=1)

    def test_guard_line_is_base_plus_k_se_total(self):
        self.assertAlmostEqual(stats.guard_line(90, 2.0, 25, k=2.0), 90 + 2.0 * 2.0 * 5.0, places=9)
        self.assertAlmostEqual(stats.guard_line(90, 2.0, 25, k=2.0, worse_is_up=False), 90 - 20.0, places=9)

    def test_false_pass_and_power_are_the_normal_tails(self):
        # a line at one se of the mean: a null passes 15.9 %; a true effect exactly at the line passes 50 %
        sd, n = 10.0, 25  # se of the mean = 2
        self.assertAlmostEqual(stats.false_pass_at_null(2.0, sd, n), 1 - stats.norm_cdf(1.0), places=9)
        self.assertAlmostEqual(stats.power_at(2.0, 2.0, sd, n), 0.5, places=9)
        self.assertAlmostEqual(stats.power_at(-6.0, -2.0, sd, n), stats.norm_cdf(2.0), places=9)


class Medians(unittest.TestCase):
    def test_bootstrap_interval_covers_a_clear_shift_and_excludes_zero(self):
        base = [float(i) for i in range(1, 19)]
        arm = [v + 10.0 for v in base]
        point, lo, hi, sd = stats.bootstrap_median_diff(base, arm, reps=500)
        self.assertEqual(point, 10.0)
        self.assertLessEqual(lo, 10.0)
        self.assertGreaterEqual(hi, 10.0)
        self.assertGreater(lo, 0.0)

    def test_bootstrap_is_deterministic_for_a_seed(self):
        base = [1.0, 4.0, 2.0, 8.0, 5.0, 7.0]
        arm = [2.0, 3.0, 5.0, 9.0, 4.0, 9.0]
        self.assertEqual(stats.bootstrap_median_diff(base, arm, reps=200, seed=3),
                         stats.bootstrap_median_diff(base, arm, reps=200, seed=3))


class Counts(unittest.TestCase):
    def test_binomial_tails(self):
        self.assertAlmostEqual(stats.binom_tail(12, 18, 0.5), 0.1189, places=4)
        self.assertAlmostEqual(stats.binom_cdf(18, 18, 0.5), 1.0, places=12)
        self.assertAlmostEqual(stats.binom_pmf(0, 4, 0.5), 1 / 16, places=12)

    def test_fisher_known_answers(self):
        # n/n v 0/n: two-sided p = 2 / C(2n, n)
        for n in (4, 5, 6):
            two, one = stats.fisher_exact(n, 0, 0, n)
            self.assertAlmostEqual(two, 2.0 / math.comb(2 * n, n), places=12)
            self.assertAlmostEqual(one, 1.0 / math.comb(2 * n, n), places=12)
        # the Lady tasting tea: 3/4 v 1/4 -> two-sided 0.486, one-sided 0.243
        two, one = stats.fisher_exact(3, 1, 1, 3)
        self.assertAlmostEqual(two, 0.4857, places=4)
        self.assertAlmostEqual(one, 0.2429, places=4)

    def test_mcnemar_known_answers(self):
        self.assertAlmostEqual(stats.mcnemar_exact(10, 0), 2.0 / 1024, places=12)
        self.assertEqual(stats.mcnemar_exact(0, 0), 1.0)
        self.assertEqual(stats.mcnemar_exact(1, 0), 1.0)
        self.assertAlmostEqual(stats.mcnemar_exact(5, 0), 0.0625, places=12)

    def test_sign_test(self):
        neg, nz, p = stats.sign_test([-1, -3, -2, -6, -1, -4])
        self.assertEqual((neg, nz), (6, 6))
        self.assertAlmostEqual(p, 1 / 64, places=12)
        self.assertEqual(stats.sign_test([0, 0])[2], 1.0)

    def test_fisher_min_n_grows_as_the_gap_shrinks(self):
        big = stats.fisher_min_n(0.0, 1.0)
        small = stats.fisher_min_n(0.4, 1.0)
        # 3/3 v 0/3: one-sided p = 1 / C(6, 3) = 0.05, exactly at the line, so a perfect separation is decided at n = 3
        self.assertEqual(big, 3)
        self.assertGreater(small, big)
        self.assertIsNone(stats.fisher_min_n(0.5, 0.5))

    def test_mcnemar_min_n_for_the_arrive_series_shape(self):
        # an arm that never loses a cell the base won, and wins 11 % of cells the base lost
        n = stats.mcnemar_min_n(0.11, 0.0)
        self.assertTrue(50 <= n <= 90, n)
        self.assertIsNone(stats.mcnemar_min_n(0.1, 0.1))

    def test_poisson_diff_sd(self):
        self.assertAlmostEqual(stats.poisson_diff_sd(125, 75), math.sqrt(200), places=12)


if __name__ == "__main__":
    unittest.main()
