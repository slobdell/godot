"""Known-answer tests for A12's four metrics and for the trajectory log reader.

Run by `make metrics-pytest`, which is part of `make metrics-check` and of `make check`.

**Every test lives in a unittest.TestCase.** arena shipped four bare `def test_*` functions that
`unittest discover` never ran and nobody noticed (`_agents/workstreams.md` Invariant 0), so `make metrics-pytest`
prints the collected count with `-v` and the Makefile asserts it is non-zero.

A "known answer" here means a value derived on paper or from an independent second implementation, never a value
copied out of a first run of the code under test. Where a number is pinned, the line above it says where the
number comes from.
"""

from __future__ import annotations

import contextlib
import gzip
import io
import json
import math
import os
import tempfile
import unittest

import make_fixtures
import metrics
import run_metrics
import trajlog
from metrics import (
    affine_residual_rms,
    cusp_density,
    displacement_efficiency,
    normalised_spectrum,
    oscillation,
    report,
    signed_speed,
    sparc_over_log,
    spectral_arc_length,
)
from trajlog import Header, Sample, TrajectoryLogError, read_lines

TICK_RATE = 30
## heading_rad for a hull facing +x, in the convention fight_probe.gd measures: heading = atan2(-fwd.x, -fwd.z).
FACING_X = -math.pi / 2.0


def make_sample(tick, x, z=0.0, heading=FACING_X, speed=0.0, unit="U1", unit_id="scout", **kwargs):
    row = dict(
        tick=tick,
        unit=unit,
        unit_id=unit_id,
        team=0,
        x=float(x),
        z=float(z),
        heading_rad=float(heading),
        speed_mps=float(speed),
        gear=0,
        goal_x=None,
        goal_z=None,
        order_verb=None,
        element=None,
        slot_x=None,
        slot_z=None,
    )
    row.update(kwargs)
    return Sample(**row)


def track(xs, zs=None, headings=None, speeds=None, start_tick=0, **kwargs):
    """A unit's samples along a list of x (and optionally z) positions, one tick apart."""
    zs = zs if zs is not None else [0.0] * len(xs)
    return [
        make_sample(
            start_tick + i,
            xs[i],
            zs[i],
            heading=(headings[i] if headings else FACING_X),
            speed=(speeds[i] if speeds else 0.0),
            **kwargs,
        )
        for i in range(len(xs))
    ]


# ==================================================================================================
# The log format and its reader
# ==================================================================================================


class LogFormatTest(unittest.TestCase):
    """Item 1's acceptance: a 10-tick fixture round-trips, and a line missing a required field is refused."""

    def header(self):
        return Header(commit="deadbeef", machine="testhost", tick_rate=TICK_RATE, producer="synthetic",
                      arena="yard", seed=3, command="pytest", knobs={"time_limit": 10.0})

    def fixture(self):
        return [
            make_sample(
                t, x=float(t), z=1.5, speed=1.0, unit="Green_alpha_1", unit_id="scout",
                goal_x=100.0, goal_z=1.5, order_verb="attack_move", element=3, slot_x=99.0, slot_z=1.0,
            )
            for t in range(10)
        ]

    def test_ten_tick_fixture_round_trips(self):
        samples = self.fixture()
        lines = [trajlog.header_line("deadbeef", "testhost", TICK_RATE, "synthetic", "yard", 3, "pytest", {})]
        lines += [trajlog.sample_line(s) for s in samples]
        log = read_lines(lines, "<fixture>")
        self.assertEqual(log.header.commit, "deadbeef")
        self.assertEqual(log.header.tick_rate, TICK_RATE)
        self.assertEqual(log.sample_count(), 10)
        self.assertEqual(list(log.units), ["Green_alpha_1"])
        back = log.units["Green_alpha_1"]
        for before, after in zip(samples, back):
            self.assertEqual(before, after)

    def test_round_trips_through_a_real_file_and_through_gzip(self):
        with tempfile.TemporaryDirectory() as tmp:
            for name in ("fixture.jsonl", "fixture.jsonl.gz"):
                path = os.path.join(tmp, name)
                trajlog.write_log(path, self.header(), self.fixture())
                log = trajlog.read_log(path)
                self.assertEqual(log.sample_count(), 10, name)
                self.assertEqual(log.units["Green_alpha_1"][3].x, 3.0, name)

    def test_samples_are_sorted_by_tick_whatever_order_they_were_written(self):
        samples = self.fixture()
        lines = [trajlog.header_line("c", "m", TICK_RATE, "synthetic")]
        lines += [trajlog.sample_line(s) for s in reversed(samples)]
        log = read_lines(lines, "<fixture>")
        self.assertEqual([s.tick for s in log.units["Green_alpha_1"]], list(range(10)))

    def _refuses(self, lines, needle):
        with self.assertRaises(TrajectoryLogError) as caught:
            read_lines(lines, "<fixture>")
        self.assertIn(needle, str(caught.exception))

    def test_a_line_missing_a_required_field_is_refused_loudly(self):
        head = trajlog.header_line("c", "m", TICK_RATE, "synthetic")
        for field in trajlog.REQUIRED_FIELDS:
            row = json.loads(trajlog.sample_line(self.fixture()[0]))
            row.pop(field)
            with self.subTest(field=field):
                self._refuses([head, json.dumps(row)], "missing required field %r" % field)

    def test_a_null_in_a_field_that_does_not_allow_it_is_refused(self):
        head = trajlog.header_line("c", "m", TICK_RATE, "synthetic")
        for field in ("tick", "unit", "x", "heading_rad", "speed_mps", "gear", "team"):
            row = json.loads(trajlog.sample_line(self.fixture()[0]))
            row[field] = None
            with self.subTest(field=field):
                self._refuses([head, json.dumps(row)], "is null")

    def test_a_half_set_goal_is_refused(self):
        head = trajlog.header_line("c", "m", TICK_RATE, "synthetic")
        row = json.loads(trajlog.sample_line(self.fixture()[0]))
        row["goal_z"] = None
        self._refuses([head, json.dumps(row)], "must be null together")

    def test_a_goal_without_a_verb_is_refused(self):
        head = trajlog.header_line("c", "m", TICK_RATE, "synthetic")
        row = json.loads(trajlog.sample_line(self.fixture()[0]))
        row["order_verb"] = None
        self._refuses([head, json.dumps(row)], "must be null together")

    def test_a_non_finite_number_is_refused(self):
        head = trajlog.header_line("c", "m", TICK_RATE, "synthetic")
        row = json.loads(trajlog.sample_line(self.fixture()[0]))
        self._refuses([head, json.dumps(row).replace('"x": 0.0', '"x": NaN')], "would be silently meaningless")

    def test_a_missing_header_is_refused(self):
        self._refuses([trajlog.sample_line(self.fixture()[0])], "the first line must be the header")

    def test_an_unknown_version_is_refused(self):
        row = json.loads(trajlog.header_line("c", "m", TICK_RATE, "synthetic"))
        row["version"] = 2
        self._refuses([json.dumps(row)], "this reader knows version 1 only")

    def test_an_empty_log_is_refused(self):
        with self.assertRaises(TrajectoryLogError):
            read_lines([], "<fixture>")

    def test_a_malformed_line_names_its_line_number(self):
        head = trajlog.header_line("c", "m", TICK_RATE, "synthetic")
        with self.assertRaises(TrajectoryLogError) as caught:
            read_lines([head, trajlog.sample_line(self.fixture()[0]), "{not json"], "run.jsonl")
        self.assertIn("run.jsonl:3", str(caught.exception))

    def test_the_cause_columns_are_all_or_nothing(self):
        head = trajlog.header_line("c", "m", TICK_RATE, "synthetic")
        with_cause = trajlog.sample_line(self.fixture()[0], with_cause=True)
        without = trajlog.sample_line(self.fixture()[1], with_cause=False)
        self._refuses([head, with_cause, without], "all-or-nothing")
        self._refuses([head, without, with_cause], "all-or-nothing")
        log = read_lines([head, with_cause, trajlog.sample_line(self.fixture()[1], with_cause=True)], "<f>")
        self.assertTrue(log.has_cause)

    def test_a_log_may_carry_a_SUBSET_of_the_optional_columns(self):
        # Per-column, not per-group: `facing_ordered` arrived after logs existed with the other three, and a
        # harness that can answer three of four must not be forced to fake the fourth.
        head = trajlog.header_line("c", "m", TICK_RATE, "synthetic")
        subset = ["order_reverse", "phase"]
        lines = [head] + [trajlog.sample_line(s, subset) for s in self.fixture()]
        log = read_lines(lines, "<f>")
        self.assertEqual(log.columns, frozenset(subset))
        self.assertTrue(log.has_cause)
        self.assertIsNone(log.units["Green_alpha_1"][0].facing_ordered)

    def test_a_log_that_adds_a_column_halfway_through_is_refused(self):
        head = trajlog.header_line("c", "m", TICK_RATE, "synthetic")
        first = trajlog.sample_line(self.fixture()[0], ["order_reverse", "phase"])
        later = trajlog.sample_line(self.fixture()[1], ["order_reverse", "phase", "creeping"])
        self._refuses([head, first, later], "all-or-nothing")
        self._refuses([head, later, first], "all-or-nothing")

    def test_facing_ordered_round_trips(self):
        head = trajlog.header_line("c", "m", TICK_RATE, "synthetic")
        samples = self.fixture()
        for s in samples:
            s.facing_ordered = True
        lines = [head] + [trajlog.sample_line(s, True) for s in samples]
        log = read_lines(lines, "<f>")
        self.assertIn("facing_ordered", log.columns)
        self.assertTrue(log.units["Green_alpha_1"][4].facing_ordered)

    def test_two_samples_on_one_tick_are_refused(self):
        head = trajlog.header_line("c", "m", TICK_RATE, "synthetic")
        one = trajlog.sample_line(self.fixture()[0])
        with self.assertRaises(TrajectoryLogError) as caught:
            read_lines([head, one, one], "<f>")
        self.assertIn("two samples on one tick", str(caught.exception))


# ==================================================================================================
# 1. Windowed displacement efficiency
# ==================================================================================================


class DisplacementEfficiencyTest(unittest.TestCase):
    def test_a_straight_line_at_constant_speed_is_one_in_every_window(self):
        samples = track([i * 2.0 for i in range(40)])
        out = displacement_efficiency(samples, span=5)
        self.assertEqual(out.windows, 36)
        for value in out.values:
            self.assertAlmostEqual(value, 1.0, places=12)
        self.assertAlmostEqual(out.mean, 1.0, places=12)

    def test_the_eight_out_two_back_shuffle_is_its_hand_computed_value(self):
        # Every 3-sample window covers one 8 m leg and one 2 m leg: path 10 m, net 6 m -> 0.6 exactly.
        xs = [0.0, 8.0, 6.0, 14.0, 12.0, 20.0, 18.0, 26.0]
        out = displacement_efficiency(track(xs), span=3)
        self.assertEqual(out.windows, 6)
        for value in out.values:
            self.assertAlmostEqual(value, 0.6, places=12)

    def test_a_semicircle_is_its_chord_over_its_arc(self):
        # A polyline semicircle of n segments has chord 2r and path n * 2r * sin(pi / 2n), so the efficiency is
        # exactly 1 / (n * sin(pi / 2n)) -- which tends to the continuous answer 2/pi as n grows.
        for n in (12, 100, 1000):
            radius = 7.0
            xs = [radius * math.cos(math.pi * i / n) for i in range(n + 1)]
            zs = [radius * math.sin(math.pi * i / n) for i in range(n + 1)]
            out = displacement_efficiency(track(xs, zs), span=n + 1)
            expected = 1.0 / (n * math.sin(math.pi / (2 * n)))
            self.assertEqual(out.windows, 1)
            self.assertAlmostEqual(out.values[0], expected, places=12, msg="n=%d" % n)
        self.assertAlmostEqual(out.values[0], 2.0 / math.pi, places=5)

    def test_going_out_and_straight_back_is_zero(self):
        out = displacement_efficiency(track([0.0, 5.0, 10.0, 5.0, 0.0]), span=5)
        self.assertEqual(out.windows, 1)
        self.assertAlmostEqual(out.values[0], 0.0, places=12)

    def test_a_window_never_spans_a_tick_gap(self):
        left = track([0.0, 1.0, 2.0, 3.0], start_tick=0)
        right = track([100.0, 101.0, 102.0, 103.0], start_tick=50)
        out = displacement_efficiency(left + right, span=4)
        self.assertEqual(out.windows, 2)  # not 5: the 100 m jump is absence, not a straight line
        self.assertEqual(out.gaps, 1)

    def test_a_parked_unit_is_refused_not_scored_one(self):
        out = displacement_efficiency(track([4.0] * 10), span=5)
        self.assertEqual(out.windows, 0)
        self.assertEqual(out.refused_zero_path, 6)
        self.assertIsNone(out.mean)

    def test_the_quantiles_are_measured_values(self):
        out = displacement_efficiency(track([0.0, 8.0, 6.0, 14.0, 12.0, 20.0]), span=3)
        self.assertIn(out.quantile(0.5), out.values)


class OscillationSpecialCaseTest(unittest.TestCase):
    """The round-8 threshold is a special case of the continuous metric: path >= 8 m and efficiency < 0.25.

    The gating is `fight_probe.gd`'s verbatim; these tests pin each clause of it.
    """

    def ordered(self, xs, goal=(1000.0, 0.0), start_tick=0):
        return track(xs, start_tick=start_tick, goal_x=goal[0], goal_z=goal[1], order_verb="attack_move")

    def test_the_threshold_is_the_continuous_metric_at_0_25(self):
        # A window of path 10 m and net 6 m (efficiency 0.6) is NOT oscillating; path 10 m and net 2 m (0.2) is.
        calm = self.ordered([0.0, 8.0, 6.0, 14.0])
        out = oscillation(calm, span=3)
        self.assertEqual(out.windows, 2)
        self.assertEqual(out.oscillating_ticks, 0)
        shuffle = self.ordered([0.0, 5.0, 1.0, 6.0, 2.0])
        out = oscillation(shuffle, span=3)
        self.assertEqual(out.windows, 3)  # each window: path 9 m, net 1 m -> 0.111 < 0.25
        self.assertEqual(out.oscillating_ticks, 3)
        self.assertEqual(out.units_that_ever_oscillated, 1)

    def test_a_short_path_is_not_oscillating_however_bad_the_ratio(self):
        # Net 0 over a 4 m path: ratio 0, but under OSCILLATE_PATH_M. That is the blocked case, counted elsewhere.
        out = oscillation(self.ordered([0.0, 2.0, 0.0, 2.0, 0.0]), span=3)
        self.assertEqual(out.windows, 0)
        self.assertEqual(out.oscillating_ticks, 0)

    def test_the_denominator_is_every_under_way_tick_including_unfilled_windows(self):
        # This is the clause that reproduces round 8's share: 5 under-way ticks, 3 full windows, all oscillating.
        out = oscillation(self.ordered([0.0, 5.0, 1.0, 6.0, 2.0]), span=3)
        self.assertEqual(out.under_way_ticks, 5)
        self.assertEqual(out.oscillating_ticks, 3)
        self.assertAlmostEqual(out.share, 3.0 / 5.0, places=12)

    def test_a_unit_at_its_goal_is_not_under_way(self):
        # AT_GOAL_M is 8: a unit within 8 m of its goal is excluded from numerator and denominator alike.
        out = oscillation(self.ordered([0.0, 1.0, 2.0], goal=(3.0, 0.0)), span=3)
        self.assertEqual(out.under_way_ticks, 0)
        self.assertEqual(out.share, 0.0)

    def test_a_unit_under_no_orders_is_not_under_way(self):
        out = oscillation(track([0.0, 5.0, 1.0, 6.0, 2.0]), span=3)
        self.assertEqual(out.under_way_ticks, 0)

    def test_a_re_order_resets_the_window(self):
        # The goal jumps > GOAL_MOVED_M on the third sample, so no window spans the change.
        far = self.ordered([0.0, 5.0, 1.0, 6.0, 2.0])
        for sample in far[2:]:
            sample.goal_x = -1000.0
        out = oscillation(far, span=3)
        self.assertEqual(out.under_way_ticks, 5)
        self.assertEqual(out.windows, 1)  # only the window that is wholly after the reset

    def test_the_verb_filter_is_fight_probes_stall_verb(self):
        # Round 8's headline counts ATTACK-MOVING units only. Without the filter the denominator gains every
        # `move` tick and the share falls for free -- which would look like a metric that cannot reproduce it.
        attacking = self.ordered([0.0, 5.0, 1.0, 6.0, 2.0])
        for sample in attacking:
            sample.order_verb = "attack_move"
        moving = self.ordered([100.0, 101.0, 102.0, 103.0, 104.0], start_tick=10)
        for sample in moving:
            sample.order_verb = "move"
        both = attacking + moving
        self.assertEqual(oscillation(both, span=3).under_way_ticks, 10)
        filtered = oscillation(both, span=3, order_verb="attack_move")
        self.assertEqual(filtered.under_way_ticks, 5)
        self.assertAlmostEqual(filtered.share, 3.0 / 5.0, places=12)

    def test_net_over_path_is_the_round_eight_travelled_quantity(self):
        out = oscillation(self.ordered([0.0, 5.0, 1.0, 6.0, 2.0]), span=3)
        # Three windows, each path 9 m and net 1 m.
        self.assertAlmostEqual(out.path_m, 27.0, places=9)
        self.assertAlmostEqual(out.net_m, 3.0, places=9)
        self.assertAlmostEqual(out.net_over_path, 1.0 / 9.0, places=12)


# ==================================================================================================
# 2. Signed cusp density
# ==================================================================================================


class SignedSpeedTest(unittest.TestCase):
    def test_the_sign_is_read_from_the_body_not_from_the_gear(self):
        forward = signed_speed(make_sample(0, 0.0), make_sample(1, 1.0), dt=1.0)
        self.assertAlmostEqual(forward, 1.0, places=12)
        backward = signed_speed(make_sample(0, 1.0), make_sample(1, 0.0), dt=1.0)
        self.assertAlmostEqual(backward, -1.0, places=12)
        # Same motion, hull facing the other way: the same displacement is now a reversal.
        turned = signed_speed(
            make_sample(0, 0.0, heading=FACING_X + math.pi),
            make_sample(1, 1.0, heading=FACING_X + math.pi),
            dt=1.0,
        )
        self.assertAlmostEqual(turned, -1.0, places=12)

    def test_the_gear_field_is_never_consulted(self):
        a = make_sample(0, 0.0, gear=1)
        b = make_sample(1, 1.0, gear=-1)  # a lying gear field
        self.assertAlmostEqual(signed_speed(a, b, dt=1.0), 1.0, places=12)


class CuspDensityTest(unittest.TestCase):
    def test_a_straight_line_has_no_cusps(self):
        out = cusp_density(track([i * 1.0 for i in range(60)]), TICK_RATE)
        self.assertEqual(out.cusps, 0)
        self.assertEqual(out.per_agent_minute, 0.0)

    def test_a_k_turn_is_exactly_two_cusps(self):
        # forward 10 m, reverse 5 m, forward 10 m: two sign changes, no more.
        xs = [i * 1.0 for i in range(11)] + [10.0 - i * 1.0 for i in range(1, 6)] + [5.0 + i * 1.0 for i in range(1, 11)]
        out = cusp_density(track(xs), TICK_RATE)
        self.assertEqual(out.cusps, 2)

    def test_the_shuffle_is_one_cusp_per_leg(self):
        # Four legs (out, back, out, back) -> three sign changes.
        xs = [0.0, 4.0, 8.0, 6.0, 4.0, 8.0, 12.0, 10.0, 8.0]
        out = cusp_density(track(xs), TICK_RATE)
        self.assertEqual(out.cusps, 3)

    def test_jitter_below_the_speed_floor_is_not_a_cusp(self):
        # +-0.01 m per tick at 30 Hz is 0.3 m/s, under CUSP_SPEED_MPS: a parked hull trembling is not reversing.
        xs = [0.0, 0.01, 0.0, 0.01, 0.0, 0.01, 0.0, 0.01]
        self.assertEqual(cusp_density(track(xs), TICK_RATE).cusps, 0)
        # The same pattern at 0.04 m per tick is 1.2 m/s and IS counted.
        xs = [0.0, 0.04, 0.0, 0.04, 0.0, 0.04, 0.0, 0.04]
        self.assertEqual(cusp_density(track(xs), TICK_RATE).cusps, 6)

    def test_the_density_is_per_agent_minute(self):
        xs = [i * 1.0 for i in range(11)] + [10.0 - i * 1.0 for i in range(1, 6)] + [5.0 + i * 1.0 for i in range(1, 11)]
        samples = track(xs)
        out = cusp_density(samples, TICK_RATE)
        self.assertAlmostEqual(out.agent_minutes, len(samples) / 30.0 / 60.0, places=12)
        self.assertAlmostEqual(out.per_agent_minute, 2.0 / out.agent_minutes, places=9)

    def test_a_tick_gap_does_not_manufacture_a_cusp(self):
        left = track([0.0, 1.0, 2.0, 3.0], start_tick=0)
        right = track([3.0, 2.0, 1.0, 0.0], start_tick=90)
        out = cusp_density(left + right, TICK_RATE)
        self.assertEqual(out.cusps, 0)

    def test_without_the_cause_columns_every_cusp_is_unclassified(self):
        xs = [0.0, 4.0, 8.0, 6.0, 4.0]
        out = cusp_density(track(xs), TICK_RATE)
        self.assertEqual(out.cusps, 1)
        self.assertEqual(out.unclassified, 1)
        self.assertEqual(out.ordered + out.creep + out.unexplained, 0)

    def test_a_LIVE_arrival_arc_is_ORDERED_and_never_unexplained(self):
        """control + the orchestrator, 2026-09-20: a unit flying an ordered arrival facing is off-corridor BY
        CONSTRUCTION, and that is the unit OBEYING. A reversal inside that arc must land in `ordered`, because
        `unexplained` is the bucket A6's falsifier reads -- charging it for the obedience control just shipped
        would fail the contract for doing the right thing."""
        xs = [0.0, 4.0, 8.0, 6.0, 4.0]
        kw = dict(order_reverse=False, phase="none", creeping=False, facing_ordered=False, facing_arc=False)
        plain = cusp_density(track(xs, **kw), TICK_RATE)
        self.assertEqual((plain.cusps, plain.unexplained, plain.ordered), (1, 1, 0))
        samples = track(xs, **kw)
        for s in samples:
            s.facing_arc = True
        arc = cusp_density(samples, TICK_RATE)
        self.assertEqual((arc.cusps, arc.unexplained, arc.ordered), (1, 0, 1))

    def test_an_order_that_merely_CARRIES_a_facing_excuses_nothing(self):
        """The other direction of the same mistake, and the harder one to catch. An order carries its facing from
        the moment it is issued, so treating `facing_ordered` as obedience would excuse every real reversal on the
        long drive to the gate -- a metric that stops seeing the thing it exists to see."""
        xs = [0.0, 4.0, 8.0, 6.0, 4.0]
        samples = track(xs, order_reverse=False, phase="none", creeping=False,
                        facing_ordered=True, facing_arc=False)
        out = cusp_density(samples, TICK_RATE)
        self.assertEqual((out.cusps, out.unexplained, out.ordered), (1, 1, 0))

    def test_both_facing_tallies_are_reported_BESIDE_the_counts_not_inside_them(self):
        # Separate tallies, not subtractions from anything: a reader must be able to see how much of the run was
        # under an order carrying a facing, how much had the arc live, and judge a fraction for themselves.
        xs = [0.0, 4.0, 8.0, 6.0, 4.0, 8.0]
        samples = track(xs, order_reverse=False, phase="none", creeping=False,
                        facing_ordered=True, facing_arc=False)
        for s in samples[4:]:
            s.facing_arc = True
        out = cusp_density(samples, TICK_RATE)
        self.assertEqual(out.ticks, 6)
        self.assertEqual(out.facing_ordered_ticks, 6)
        self.assertEqual(out.facing_arc_ticks, 2)

    def test_with_the_cause_columns_the_cusps_are_split(self):
        xs = [0.0, 4.0, 8.0, 6.0, 4.0, 8.0, 12.0]
        samples = track(xs, order_reverse=False, phase="none", creeping=False)
        samples[3].order_reverse = True   # the first reversal was ordered
        samples[5].creeping = True        # the second was the wheeled creep
        out = cusp_density(samples, TICK_RATE)
        self.assertEqual(out.cusps, 2)
        self.assertEqual((out.ordered, out.creep, out.unexplained, out.unclassified), (1, 1, 0, 0))


# ==================================================================================================
# 3. Spectral arc length
# ==================================================================================================


def naive_dft_magnitudes(profile, nfft):
    """A second, independent implementation: the definition, O(n^2), used only to check ours."""
    padded = list(profile) + [0.0] * (nfft - len(profile))
    out = []
    for k in range(nfft // 2 + 1):
        real = sum(padded[n] * math.cos(-2.0 * math.pi * k * n / nfft) for n in range(nfft))
        imag = sum(padded[n] * math.sin(-2.0 * math.pi * k * n / nfft) for n in range(nfft))
        out.append(math.hypot(real, imag))
    return out


class FftTest(unittest.TestCase):
    """The transform is ours, so it is checked against the definition and against a closed form."""

    def test_it_agrees_with_the_definition(self):
        profile = [math.sin(0.3 * n) + 0.5 * math.cos(0.11 * n) + 2.0 for n in range(37)]
        nfft = 128
        ours = normalised_spectrum(profile, nfft)
        theirs = naive_dft_magnitudes(profile, nfft)
        dc = theirs[0]
        for k, (a, b) in enumerate(zip(ours, theirs)):
            self.assertAlmostEqual(a, b / dc, places=10, msg="bin %d" % k)

    def test_a_constant_profile_is_the_closed_form_dirichlet_kernel(self):
        # A constant c over W samples zero-padded to N has |X_k| = c * |sin(pi k W / N) / sin(pi k / N)|, so the
        # DC-normalised magnitude is |sin(pi k W / N)| / (W * |sin(pi k / N)|). Pen and paper, not a first run.
        width, nfft = 64, 256
        ours = normalised_spectrum([3.25] * width, nfft)
        for k in range(1, nfft // 2 + 1):
            expected = abs(math.sin(math.pi * k * width / nfft)) / (width * abs(math.sin(math.pi * k / nfft)))
            self.assertAlmostEqual(ours[k], expected, places=12, msg="bin %d" % k)
        self.assertAlmostEqual(ours[0], 1.0, places=12)

    def test_a_parked_unit_has_no_normalised_spectrum(self):
        with self.assertRaises(ValueError):
            normalised_spectrum([0.0] * 64, 128)

    def test_the_length_must_be_a_power_of_two(self):
        with self.assertRaises(ValueError):
            metrics._fft([complex(1.0)] * 6)


class SparcTest(unittest.TestCase):
    """SPARC's window (256 samples), transform (256 points, no padding), taper (periodic Hann) and cutoff
    (20 rad/s = 3.18 Hz) are all fixed, so every answer below is derivable on paper.

    The taper's transform is exactly three bins, which is what makes them derivable: a constant profile's
    normalised spectrum is (1, 0.5, 0, 0, ...) and a cosine at m whole cycles adds (a/4c, a/2c, a/4c) at
    m-1, m, m+1. Everything here is that arithmetic.
    """

    WIDTH = metrics.SPARC_WINDOW_SAMPLES

    def bin_step(self):
        """dw: one frequency bin as a fraction of the cutoff. The horizontal step of the arc length."""
        bin_rad_s = 2.0 * math.pi * TICK_RATE / self.WIDTH
        return bin_rad_s / metrics.SPARC_CUTOFF_RAD_S, int(metrics.SPARC_CUTOFF_RAD_S / bin_rad_s)

    def tone(self, cycles, depth=0.5, offset=2.0):
        return [offset + depth * math.cos(2.0 * math.pi * cycles * n / self.WIDTH) for n in range(self.WIDTH)]

    def test_a_constant_speed_is_its_hand_computed_value(self):
        # V = (1, 0.5, 0, 0, ...): two rises of 0.5 and then a flat run to the cutoff.
        dw, last = self.bin_step()
        expected = -(2.0 * math.hypot(dw, 0.5) + (last - 2) * dw)
        self.assertAlmostEqual(spectral_arc_length([2.0] * self.WIDTH, TICK_RATE), expected, places=9)
        # And the pin, so the window, the transform length, the taper or the cutoff cannot change unnoticed.
        self.assertAlmostEqual(expected, -1.9231, places=4)

    def test_one_cosine_at_one_frequency_is_its_hand_computed_value(self):
        # On top of the constant's (1, 0.5), a cosine of depth a on an offset c adds a/4c, a/2c, a/4c at
        # m-1, m, m+1 -- four rises of a/4c, and four fewer flat bins.
        dw, last = self.bin_step()
        depth, offset = 0.5, 2.0
        step = depth / (4.0 * offset)
        expected = -(2.0 * math.hypot(dw, 0.5) + 4.0 * math.hypot(dw, step) + (last - 6) * dw)
        for cycles in (6, 10, 20):  # far enough from DC that the two kernels do not overlap, and m+1 <= last
            with self.subTest(cycles=cycles):
                self.assertAlmostEqual(
                    spectral_arc_length(self.tone(cycles), TICK_RATE), expected, places=9
                )
        self.assertAlmostEqual(expected, -2.0660, places=4)

    def test_a_constant_speed_is_the_smoothest_profile_there_is(self):
        smoothest = spectral_arc_length([2.0] * self.WIDTH, TICK_RATE)
        for name, profile in self.jerkier_profiles().items():
            with self.subTest(profile=name):
                self.assertLess(spectral_arc_length(profile, TICK_RATE), smoothest)

    def jerkier_profiles(self):
        width = self.WIDTH
        return {
            "one tone": self.tone(8),
            "three tones": [
                2.0 + 0.3 * math.cos(2.0 * math.pi * 5 * n / width)
                + 0.3 * math.cos(2.0 * math.pi * 11 * n / width)
                + 0.3 * math.cos(2.0 * math.pi * 17 * n / width)
                for n in range(width)
            ],
            "square wave in band": [2.0 + (0.5 if (n // 16) % 2 else -0.5) for n in range(width)],
        }

    def test_more_spectral_content_is_jerkier(self):
        # The thing SPARC actually ranks: how many things the speed is doing at once.
        one = spectral_arc_length(self.jerkier_profiles()["one tone"], TICK_RATE)
        three = spectral_arc_length(self.jerkier_profiles()["three tones"], TICK_RATE)
        square = spectral_arc_length(self.jerkier_profiles()["square wave in band"], TICK_RATE)
        self.assertLess(three, one)
        self.assertLess(square, one)

    def test_a_deeper_wobble_is_jerkier(self):
        previous = None
        for depth in (0.05, 0.2, 0.5, 0.9):
            value = spectral_arc_length(self.tone(8, depth=depth), TICK_RATE)
            if previous is not None:
                self.assertLess(value, previous, "depth %g should be jerkier than the step before" % depth)
            previous = value

    def test_a_pure_tone_scores_the_same_at_any_frequency_in_the_band(self):
        """WHAT IT CANNOT SEE, asserted so nobody reads a ranking into it that is not there.

        SPARC is the total variation of the normalised spectrum: sliding one peak along the frequency axis does
        not change the length of the curve. A single clean wobble at 1 Hz and at 2 Hz score identically. Real
        jerk is broadband, which is why the metric works in practice -- but a falsifier that says 'the wobble got
        faster' must not be read from this number. Use cusp density for that.
        """
        values = {cycles: spectral_arc_length(self.tone(cycles), TICK_RATE) for cycles in (6, 10, 15, 20)}
        for cycles, value in values.items():
            self.assertAlmostEqual(value, values[6], places=9, msg="%d cycles" % cycles)

    def test_content_above_the_cutoff_is_invisible(self):
        """Also asserted: the band is 0 to 20 rad/s (3.18 Hz). A 14 m truck does not change speed six times a
        second, and per-tick physics jitter that fast is not what the lead is watching."""
        dw, last = self.bin_step()
        above = self.tone(last + 6)  # a tone whose whole kernel sits beyond the cutoff
        self.assertAlmostEqual(
            spectral_arc_length(above, TICK_RATE),
            spectral_arc_length([2.0] * self.WIDTH, TICK_RATE),
            places=9,
        )

    def test_it_does_not_depend_on_how_fast_the_unit_was_going(self):
        # V is normalised by its own DC term, so the metric is amplitude-scale-free -- analytic, exact.
        base = [1.0 + math.sin(0.4 * n) * 0.3 for n in range(self.WIDTH)]
        one = spectral_arc_length(base, TICK_RATE)
        for factor in (0.01, 3.7, 1000.0):
            scaled = spectral_arc_length([v * factor for v in base], TICK_RATE)
            self.assertAlmostEqual(one, scaled, places=10, msg="factor %g" % factor)

    def test_it_barely_depends_on_the_direction_of_time(self):
        """|DFT(x reversed)| == |DFT(x)| bin for bin, so a trajectory played backwards would be EXACTLY as jerky
        if not for the taper: the periodic Hann satisfies w[N-k] == w[k], which is one sample off the reversal
        w[N-1-k]. That leaves a residue of order 1e-5, recorded here rather than papered over, because a reader
        who finds two runs differing in the fifth decimal deserves to know which decimals mean anything."""
        base = [1.0 + 0.4 * math.sin(0.23 * n) + 0.2 * math.cos(1.1 * n) for n in range(self.WIDTH)]
        forwards = spectral_arc_length(base, TICK_RATE)
        backwards = spectral_arc_length(list(reversed(base)), TICK_RATE)
        self.assertAlmostEqual(forwards, backwards, delta=1e-4)

    def test_the_same_input_gives_the_same_bits_every_time(self):
        profile = [1.0 + 0.3 * math.sin(0.17 * n) for n in range(self.WIDTH)]
        first = spectral_arc_length(profile, TICK_RATE)
        for _ in range(4):
            self.assertEqual(spectral_arc_length(profile, TICK_RATE), first)

    def test_a_profile_that_is_not_a_power_of_two_long_is_refused(self):
        with self.assertRaises(ValueError):
            spectral_arc_length([1.0] * 100, TICK_RATE)

    def test_over_a_log_it_refuses_rather_than_scoring_a_parked_unit(self):
        samples = track([0.0] * self.WIDTH, speeds=[0.0] * self.WIDTH)
        out = sparc_over_log(samples, TICK_RATE)
        self.assertEqual(out.windows, 0)
        self.assertEqual(out.refused_parked, 1)
        self.assertIsNone(out.mean)

    def test_over_a_log_it_refuses_a_run_shorter_than_one_window(self):
        out = sparc_over_log(track([0.0, 1.0, 2.0], speeds=[1.0, 1.0, 1.0]), TICK_RATE)
        self.assertEqual(out.windows, 0)
        self.assertEqual(out.refused_short, 1)

    def test_over_a_log_a_window_never_spans_a_tick_gap(self):
        width = self.WIDTH
        left = track([float(i) for i in range(width + 44)], speeds=[1.0] * (width + 44), start_tick=0)
        right = track([float(i) for i in range(width)], speeds=[1.0] * width, start_tick=10_000)
        out = sparc_over_log(left + right, TICK_RATE)
        self.assertEqual(out.windows, 1)       # only the first window is 256 contiguous ticks
        self.assertEqual(out.refused_short, 1)  # the one straddling the gap


# ==================================================================================================
# 4. Affine formation residual
# ==================================================================================================


WEDGE = [(0.0, 0.0), (-4.0, -6.0), (4.0, -6.0), (-8.0, -12.0), (8.0, -12.0), (0.0, -18.0)]
SQUARE = [(1.0, 1.0), (1.0, -1.0), (-1.0, 1.0), (-1.0, -1.0)]


def affine(points, a=1.0, b=0.0, c=0.0, d=1.0, tx=0.0, tz=0.0):
    return [(a * x + b * z + tx, c * x + d * z + tz) for x, z in points]


class AffineFormationResidualTest(unittest.TestCase):
    def test_a_translated_wedge_is_zero(self):
        moved = affine(WEDGE, tx=137.5, tz=-62.25)
        self.assertAlmostEqual(affine_residual_rms(WEDGE, moved), 0.0, places=9)

    def test_a_rotated_wedge_is_zero(self):
        angle = 0.9
        turned = affine(WEDGE, a=math.cos(angle), b=-math.sin(angle), c=math.sin(angle), d=math.cos(angle))
        self.assertAlmostEqual(affine_residual_rms(WEDGE, turned), 0.0, places=9)

    def test_a_sheared_wedge_is_zero(self):
        sheared = affine(WEDGE, b=0.6)
        self.assertAlmostEqual(affine_residual_rms(WEDGE, sheared), 0.0, places=9)

    def test_a_stretched_wedge_is_zero(self):
        # An element squeezed through a corridor is still in formation; it is what "affine" buys us.
        self.assertAlmostEqual(affine_residual_rms(WEDGE, affine(WEDGE, a=2.5, d=0.4)), 0.0, places=9)

    def test_one_unit_displaced_three_metres_is_its_hand_computed_value(self):
        # On the unit square the regressors (nx, nz, 1) are mutually orthogonal with |v|^2 = 4, so the fit absorbs
        # (d/4) * (3, 1, 1, -1) of a displacement d and leaves residuals (d/4) * (1, -1, -1, 1): every vertex is
        # out by exactly d/4, so the RMS is d/4. For the brief's 3 m that is 0.75 m.
        actual = list(SQUARE)
        actual[0] = (SQUARE[0][0] + 3.0, SQUARE[0][1])
        self.assertAlmostEqual(affine_residual_rms(SQUARE, actual), 0.75, places=12)

    def test_the_hand_value_scales_with_the_displacement(self):
        for displacement in (0.5, 2.0, 12.0):
            actual = list(SQUARE)
            actual[0] = (SQUARE[0][0] + displacement, SQUARE[0][1])
            self.assertAlmostEqual(affine_residual_rms(SQUARE, actual), displacement / 4.0, places=12)

    def test_a_displacement_the_affine_map_cannot_explain_survives_any_deformation(self):
        # The same 3 m displacement, on top of a rotation and a shear: the residual is unchanged, because the
        # deformation is exactly what the fit removes.
        angle = 0.4
        base = affine(SQUARE, a=math.cos(angle), b=-math.sin(angle) + 0.3, c=math.sin(angle), d=math.cos(angle))
        actual = list(base)
        actual[0] = (base[0][0] + 3.0, base[0][1])
        self.assertAlmostEqual(affine_residual_rms(SQUARE, actual), 0.75, places=9)

    def test_the_reference_is_the_LEADER_S_SLOT_so_a_NON_AFFINE_deformation_is_free(self):
        """squad, 2026-09-20: A8 narrows a formation to fit a corridor with a *file morph* that is deliberately
        NOT affine -- no 2x2 can separate two slots at the same depth while squeezing that axis toward zero, so
        "a wedge becomes a column" is false for an affine map. If the residual's reference were the nominal shape,
        a wedge that had correctly filed through a defile -- every unit exactly where its leader put it -- would
        read as a large residual: a false positive on the one manoeuvre A8 exists to produce.

        It does not, because the reference is whatever the producer logged in `slot_x`/`slot_z`, and that is
        `Element.slots` -- the slot the leader ASSIGNED this tick, deformation included. The residual measures
        departure from the element's own intent, and every deformation the leader commanded is free, affine or
        not. This test is the guarantee squad asked for."""
        wedge = WEDGE[:5]
        # The file morph: the pairs that shared a depth in the wedge are pulled apart ALONG the heading while the
        # shape closes ACROSS it, until the element is in single file.
        filed = [(0.0, -3.0 * i) for i in range(5)]
        # No affine map takes the wedge to that file -- confirm the fit genuinely cannot reproduce it.
        self.assertGreater(affine_residual_rms(wedge, filed), 0.5)
        # And confirm that is irrelevant, because the reference is the COMMANDED slot and the units are on it.
        self.assertAlmostEqual(affine_residual_rms(filed, filed), 0.0, places=9)
        # A unit 3 m out of the file is still measured, in the middle of that same non-affine deformation --
        # which is only true because the fit is an orthogonal projection: a file's slots are COLLINEAR, and the
        # normal-equations solve this replaced refused them outright.
        strayed = list(filed)
        strayed[0] = (filed[0][0] + 3.0, filed[0][1])
        self.assertGreater(affine_residual_rms(filed, strayed), 0.5)
        self.assertEqual(metrics.reference_rank(filed), 2)
        self.assertEqual(metrics.reference_rank(wedge), 3)

    def test_three_members_are_refused_because_three_points_fit_exactly(self):
        with self.assertRaises(ValueError) as caught:
            affine_residual_rms(WEDGE[:3], [(9.0, 9.0), (1.0, 2.0), (3.0, 4.0)])
        self.assertIn("3 points determine it exactly", str(caught.exception))

    def test_a_single_FILE_still_measures_departure_across_the_line(self):
        """A8's headline manoeuvre files an element into a line, and a line's slots are COLLINEAR. The affine
        COEFFICIENTS are then ambiguous, but the residual is not, so refusing these elements would blind the
        metric exactly where squad needs it. Rank 2 is reported so a reader knows why."""
        line = [(0.0, 0.0), (1.0, 0.0), (2.0, 0.0), (3.0, 0.0)]
        self.assertEqual(metrics.reference_rank(line), 2)
        self.assertAlmostEqual(affine_residual_rms(line, line), 0.0, places=12)
        # Sliding along the line is free (it is a scale, which is affine); stepping off it is not.
        self.assertAlmostEqual(
            affine_residual_rms(line, [(0.0, 0.0), (2.0, 0.0), (4.0, 0.0), (6.0, 0.0)]), 0.0, places=12)
        self.assertGreater(affine_residual_rms(line, [(0.0, 0.0), (1.0, 3.0), (2.0, 0.0), (3.0, 0.0)]), 0.5)

    def test_slots_all_in_one_place_measure_the_spread_around_it(self):
        """Rank 1. Still not a refusal: if the leader put every slot in one spot, how far the element is from
        being in one spot is exactly the question, and it is the spread about the mean."""
        point = [(5.0, 5.0)] * 4
        self.assertEqual(metrics.reference_rank(point), 1)
        self.assertAlmostEqual(affine_residual_rms(point, point), 0.0, places=12)
        spread = [(5.0, 6.0), (5.0, 4.0), (6.0, 5.0), (4.0, 5.0)]
        self.assertAlmostEqual(affine_residual_rms(point, spread), 1.0, places=12)

    def test_it_is_reported_per_element_from_a_log(self):
        lines = [trajlog.header_line("c", "m", TICK_RATE, "synthetic")]
        for tick in range(3):
            for i, (nx, nz) in enumerate(SQUARE):
                x, z = nx, nz
                if i == 0:
                    x += 3.0
                lines.append(
                    trajlog.sample_line(
                        make_sample(tick, x, z, unit="U%d" % i, element=7, slot_x=nx, slot_z=nz)
                    )
                )
            # A second element of three, which must be refused rather than reported as perfect.
            for i in range(3):
                lines.append(
                    trajlog.sample_line(
                        make_sample(tick, float(i), 0.0, unit="V%d" % i, element=8, slot_x=float(i), slot_z=0.0)
                    )
                )
        log = read_lines(lines, "<fixture>")
        out = metrics.formation_residual_by_element(log)
        self.assertAlmostEqual(out[7].mean, 0.75, places=12)
        self.assertEqual(out[7].ticks, 3)
        self.assertEqual(out[7].min_rank, 3)
        self.assertEqual(out[8].ticks, 0)
        self.assertEqual(out[8].refused_too_small, 3)
        self.assertIsNone(out[8].mean)


# ==================================================================================================
# Hull turn between events (combat's A2 bearing read)
# ==================================================================================================


class TurnBetweenEventsTest(unittest.TestCase):
    """The unwrapped heading pays for itself here: a 201 degree turn must read as 201, not as -159.
    Round 8's 20.7 degree "overshoot", which justified a whole technique, was exactly that wrap bug."""

    def turning(self, degrees_per_tick, ticks=200):
        return [
            make_sample(t, x=float(t), heading=FACING_X + math.radians(degrees_per_tick * t))
            for t in range(ticks)
        ]

    def test_a_steady_turn_gives_the_turn_it_actually_made(self):
        samples = self.turning(1.0)                       # 1 degree a tick
        turns, missed = metrics.turns_between_events(samples, [10, 40, 100])
        self.assertEqual(missed, 0)
        self.assertAlmostEqual(turns[0], 30.0, places=6)
        self.assertAlmostEqual(turns[1], 60.0, places=6)

    def test_a_turn_past_180_degrees_is_not_wrapped(self):
        # THE test. 201 degrees must read as 201. A wrapped heading would report 159.
        samples = self.turning(1.0, ticks=260)
        turns, _ = metrics.turns_between_events(samples, [0, 201])
        self.assertAlmostEqual(turns[0], 201.0, places=6)

    def test_driving_straight_between_two_events_is_zero(self):
        # The honest answer to "did the hull have to turn" for a unit that switched targets while driving
        # straight -- and NOT an answer to "were the targets far apart", which no trajectory log knows.
        turns, _ = metrics.turns_between_events(track([float(i) for i in range(50)]), [5, 25, 45])
        for turn in turns:
            self.assertAlmostEqual(turn, 0.0, places=9)

    def test_events_outside_the_log_are_counted_not_guessed(self):
        turns, missed = metrics.turns_between_events(self.turning(1.0, ticks=50), [10, 20, 9999])
        self.assertEqual(missed, 1)
        self.assertEqual(len(turns), 1)

    def test_events_are_deduplicated_and_sorted(self):
        samples = self.turning(1.0)
        a, _ = metrics.turns_between_events(samples, [100, 10, 40, 10])
        b, _ = metrics.turns_between_events(samples, [10, 40, 100])
        self.assertEqual(a, b)

    def test_the_cli_accepts_a_bare_map_or_a_wrapper_with_the_events_beside_it(self):
        import json as _json
        import tempfile as _tempfile
        import run_metrics
        with _tempfile.TemporaryDirectory() as tmp:
            bare = os.path.join(tmp, "bare.json")
            wrapped = os.path.join(tmp, "wrapped.json")
            with open(bare, "w") as handle:
                _json.dump({"U1": [1, 2]}, handle)
            with open(wrapped, "w") as handle:
                _json.dump({"switches": {"U1": [1, 2]},
                            "events": [{"tick": 1, "angle_deg": 137.4}]}, handle)
            log_path = os.path.join(tmp, "run.jsonl")
            header = Header(commit="c", machine="m", tick_rate=TICK_RATE, producer="synthetic")
            trajlog.write_log(log_path, header, [
                make_sample(t, float(t), speed=6.0) for t in range(metrics.SPARC_WINDOW_SAMPLES)])
            for path in (bare, wrapped):
                captured = io.StringIO()
                with contextlib.redirect_stdout(captured):
                    status = run_metrics.main([log_path, "--switches", path])
                self.assertEqual(status, 0, path)
                self.assertIn("hull TURN between consecutive events", captured.getvalue(), path)

    def test_the_report_splits_by_unit_type_and_flags_a_mismatched_arm(self):
        lines = [trajlog.header_line("c", "m", TICK_RATE, "synthetic")]
        for t in range(60):
            lines.append(trajlog.sample_line(make_sample(
                t, float(t), unit="Tank_1", unit_id="tank", heading=FACING_X + math.radians(2.0 * t))))
            lines.append(trajlog.sample_line(make_sample(
                t, float(t), z=20.0, unit="Ifv_1", unit_id="ifv", heading=FACING_X)))
        log = read_lines(lines, "<f>")
        out = metrics.turn_report(log, {"Tank_1": [0, 10, 20], "Ifv_1": [0, 30], "Ghost_9": [0, 5]})
        self.assertAlmostEqual(out["by_unit_id"]["tank"]["turn_deg_mean"], 20.0, places=1)
        self.assertAlmostEqual(out["by_unit_id"]["ifv"]["turn_deg_mean"], 0.0, places=6)
        self.assertEqual(out["by_unit_id"]["ifv"]["share_under_15_deg"], 1.0)
        # A unit whose events are not in this log is named, not silently dropped: it usually means the events
        # came from the other arm of an A/B.
        self.assertEqual(out["unknown_units"], ["Ghost_9"])


# ==================================================================================================
# The report
# ==================================================================================================


class ReportTest(unittest.TestCase):
    def build(self, with_cause=False):
        lines = [trajlog.header_line("aa984edd", "builder0", TICK_RATE, "nav-fight", "yard", 3, "cmd", {"busy": 0})]
        width = metrics.SPARC_WINDOW_SAMPLES
        for unit, unit_id, step in (("Green_a_1", "scout", 1.0), ("Green_a_2", "war_rig", 0.5)):
            for tick in range(width + 20):
                extra = dict(order_reverse=False, phase="none", creeping=False) if with_cause else {}
                lines.append(
                    trajlog.sample_line(
                        make_sample(
                            tick, tick * step, 0.0, speed=step * TICK_RATE, unit=unit, unit_id=unit_id,
                            goal_x=10_000.0, goal_z=0.0, order_verb="attack_move", **extra
                        ),
                        with_cause=with_cause,
                    )
                )
        return read_lines(lines, "<fixture>")

    def test_it_reports_per_unit_type_with_its_window_and_its_counts(self):
        out = report(self.build())
        self.assertEqual(out["commit"], "aa984edd")
        self.assertEqual(out["machine"], "builder0")
        self.assertIn("commit=aa984edd", out["provenance"])
        self.assertEqual(out["window_ticks"], int(metrics.WINDOW_S * TICK_RATE))
        self.assertEqual(sorted(out["by_unit_id"]), ["scout", "war_rig"])
        for unit_id, row in out["by_unit_id"].items():
            self.assertEqual(row["units"], 1, unit_id)
            self.assertAlmostEqual(row["efficiency_mean"], 1.0, places=6)  # both drive straight
            self.assertEqual(row["cusps"], 0, unit_id)
        self.assertEqual(out["all"]["units"], 2)

    def test_it_counts_the_units_that_actually_held_an_order(self):
        # A log holds BOTH armies and only one is under orders. Without this column the ordered side's row reads
        # as though it did nothing, diluted by the enemy's vehicles standing in the same unit_id bucket.
        lines = [trajlog.header_line("c", "m", TICK_RATE, "nav-fight")]
        width = metrics.SPARC_WINDOW_SAMPLES
        for tick in range(width):
            lines.append(trajlog.sample_line(make_sample(
                tick, tick * 1.0, unit="Green_1", unit_id="tank", team=0,
                goal_x=10_000.0, goal_z=0.0, order_verb="attack_move")))
            lines.append(trajlog.sample_line(make_sample(tick, tick * 1.0, z=50.0, unit="Rust_1", unit_id="tank",
                                                         team=1)))
        out = report(read_lines(lines, "<f>"))
        self.assertEqual(out["by_unit_id"]["tank"]["units"], 2)
        self.assertEqual(out["by_unit_id"]["tank"]["units_ordered"], 1)
        self.assertEqual(out["teams"], [0, 1])
        # The enemy contributes to neither side of the oscillating share: it has no goal, so it is never under way.
        self.assertEqual(out["all"]["under_way_seconds"], round(width / float(TICK_RATE), 1))

    def test_an_ABSENT_facing_column_reports_null_and_never_a_zero(self):
        """nav, 2026-09-20: a log written before `facing_arc` was published printed `arc_live=0.0s` in BOTH arms
        of an A/B -- which reads exactly like a measurement of behaviour and was an unpublished field. A zero
        that means "no data" is the one thing this tool exists to refuse, and it was in the renderer."""
        out = report(self.build())                      # no optional columns at all
        self.assertIsNone(out["all"]["facing_arc_seconds"])
        self.assertIsNone(out["all"]["facing_ordered_seconds"])
        captured = io.StringIO()
        run_metrics.print_report(out, captured)
        self.assertIn("arc_live=null", captured.getvalue())
        self.assertNotIn("arc_live=0.0s", captured.getvalue())

    def test_a_PRESENT_facing_column_with_no_arc_time_reports_a_real_zero(self):
        # The other half: once the column exists, 0.0 s IS a measurement and must not read as absent.
        out = report(self.build(with_cause=True))
        self.assertEqual(out["all"]["facing_arc_seconds"], 0.0)
        captured = io.StringIO()
        run_metrics.print_report(out, captured)
        self.assertNotIn("arc_live=null", captured.getvalue())

    def test_it_says_whether_the_cause_columns_were_there(self):
        self.assertFalse(report(self.build())["cause_columns"])
        self.assertTrue(report(self.build(with_cause=True))["cause_columns"])

    def test_the_report_is_json_serialisable(self):
        json.dumps(report(self.build()))


class FixtureTest(unittest.TestCase):
    """The synthetic fixtures `make metrics-fixtures` writes, and the answers their README claims.

    The README is a promise to the next reader; this makes it a checked one. A fixture whose printed number stops
    matching its row is a regression, not a re-baselining exercise.
    """

    def report_for(self, name):
        builder = make_fixtures.FIXTURES[name][0]
        lines = [trajlog.header_line("c", "m", TICK_RATE, "synthetic")]
        with_cause = False
        lines += [trajlog.sample_line(s, with_cause) for s in builder()]
        return report(read_lines(lines, "<%s>" % name))

    def test_straight_is_perfectly_efficient_and_the_smoothest_sparc(self):
        row = self.report_for("straight")["all"]
        self.assertAlmostEqual(row["efficiency_mean"], 1.0, places=4)
        self.assertEqual(row["cusps"], 0)
        self.assertEqual(row["oscillating_share"], 0.0)
        self.assertAlmostEqual(row["sparc_mean"], -1.9231, places=4)

    def test_shuffle_is_zero_point_six_and_the_threshold_cannot_see_it(self):
        # The argument for A12 in one fixture: a unit visibly shuffling, that round 8's counter scores as clean.
        row = self.report_for("shuffle")["all"]
        self.assertAlmostEqual(row["efficiency_mean"], 0.600, places=3)
        self.assertEqual(row["oscillating_share"], 0.0)
        self.assertEqual(row["cusps"], 19)
        self.assertAlmostEqual(row["cusps_per_agent_minute"], 57.0, places=1)

    def test_pinned_reproduces_the_round_eight_denominator(self):
        row = self.report_for("pinned")["all"]
        self.assertAlmostEqual(row["efficiency_mean"], 0.200, places=3)
        # 481 full windows out of 600 under-way ticks: the 119 ticks before the first window closes are in the
        # denominator and not in the numerator, which is exactly how `fight_probe.gd` counts.
        self.assertAlmostEqual(row["oscillating_share"], 481.0 / 600.0, places=3)
        self.assertEqual(row["oscillating_units"], 1)

    def test_wedge_is_the_hand_computed_formation_residual(self):
        out = self.report_for("wedge")
        self.assertAlmostEqual(out["by_element"]["1"]["residual_rms_mean"], 0.750, places=6)
        self.assertAlmostEqual(out["all"]["efficiency_mean"], 1.0, places=4)
        self.assertEqual(out["all"]["cusps"], 0)  # out of your slot is not the same as jerky

    def test_jerky_is_invisible_to_the_position_metrics_and_loud_in_sparc(self):
        row = self.report_for("jerky")["all"]
        self.assertAlmostEqual(row["efficiency_mean"], 1.0, places=4)
        self.assertEqual(row["cusps"], 0)
        self.assertLess(row["sparc_mean"], self.report_for("straight")["all"]["sparc_mean"])

    def test_every_fixture_in_the_table_is_covered_by_a_test_above(self):
        # The table is the README's source; a fixture added without an answer is the failure mode this catches.
        covered = {"straight", "shuffle", "pinned", "wedge", "jerky"}
        self.assertEqual(set(make_fixtures.FIXTURES), covered)


if __name__ == "__main__":
    unittest.main()
