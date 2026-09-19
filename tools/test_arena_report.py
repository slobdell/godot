#!/usr/bin/env python3
"""Tests for tools/arena_report.py's X2 ambush analysis (`make arena-pytest`, part of `make arena-test`).

These exist because the analysis is an INSTRUMENT: it produces numbers nobody can check by eye, about maps nobody
has played, and those numbers are meant to decide which arenas get changed. Every test below is a case whose answer
was known before the code ran, and two of them are bugs the instrument actually had:

  - `centre_sees_share` was 0.000 for foundry, the most OPEN arena in the game, because foundry has a crate on the
    exact centre and the observer was standing inside it.
  - the route optimiser minimised the grid-marched exposure field and the report printed `exposure()`'s independent
    box test, so a bigger penalty could produce a route the report called MORE exposed -- impossible for the
    quantity being optimised.

Both looked like plausible map facts in a JSON blob. Neither survives a map whose character you already know.
"""
import json
import math
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import arena_report as ar

ARENAS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "arenas")


def load(name):
    with open(os.path.join(ARENAS, name + ".json")) as f:
        return json.load(f)


class Prepared:
    """One layout's grids, built once: each is a second or two of work."""

    _cache = {}

    def __new__(cls, name):
        if name not in cls._cache:
            self = object.__new__(cls)
            self.layout = load(name)
            self.boxes = ar.boxes_of(self.layout)
            self.blocked, self.n = ar.occupancy(self.boxes)
            self.grid, self.gn = ar.sight_grid(self.boxes)
            cls._cache[name] = self
        return cls._cache[name]


class TestSightAgreesWithTheRestOfTheFile(unittest.TestCase):
    """`sees()` marches a grid; `clear()` tests boxes directly. They are used interchangeably, so they must agree."""

    def test_the_grid_march_agrees_with_the_box_test(self):
        p = Prepared("yard")
        disagreements = 0
        total = 0
        for iz in range(-6, 7):
            for ix in range(-6, 7):
                a = (ix * 16.0, iz * 16.0)
                b = (-ix * 16.0, -iz * 16.0 + 8.0)
                total += 1
                if ar.sees(p.grid, p.gn, a[0], a[1], b[0], b[1]) != ar.clear(p.boxes, a[0], a[1], b[0], b[1]):
                    disagreements += 1
        # A 1 m grid cannot match a continuous slab test exactly -- a ray clipping a corner falls either way. What
        # would matter is a systematic difference, so this is a tolerance, not an equality.
        self.assertLess(disagreements / total, 0.1,
                        "grid sight and box sight disagree on %d of %d lines" % (disagreements, total))


class TestTheObserverStandsSomewhereReal(unittest.TestCase):
    def test_the_centre_eye_is_not_inside_foundrys_centre_crate(self):
        p = Prepared("foundry")
        crate = [b for b in p.boxes if abs(b.x) < 0.01 and abs(b.z) < 0.01]
        self.assertTrue(crate, "setup: foundry still has an obstacle on the exact centre")
        spot = ar.standing_point(p.blocked, p.n, (0.0, 0.0))
        self.assertGreater(crate[0].distance(*spot), 0.0, "the centre eye at %s is inside the centre crate" % (spot,))

    def test_an_observer_inside_cover_would_see_nothing_at_all(self):
        """The bug this guards: standing in a box is not 'a very covered position', it is a broken measurement."""
        p = Prepared("foundry")
        points = ar.field_points(p.blocked, p.n, 12.0)
        inside = ar.visible_share(p.grid, p.gn, (0.0, 0.0), points)
        outside = ar.visible_share(p.grid, p.gn, ar.standing_point(p.blocked, p.n, (0.0, 0.0)), points)
        self.assertEqual(inside, 0.0, "setup: an eye inside the crate really does see nothing")
        self.assertGreater(outside, 0.3, "one metre away it sees most of an open arena (%.3f)" % outside)


class TestTheNumbersRankMapsTheWayTheirCharacterSays(unittest.TestCase):
    """The calibration. These are not thresholds pulled from the air: each is a map whose character is documented in
    _agents/arenas.md and was decided before this analysis existed."""

    def share(self, name):
        p = Prepared(name)
        return ar.visible_share(p.grid, p.gn, ar.standing_point(p.blocked, p.n, (0.0, 0.0)),
                                ar.field_points(p.blocked, p.n, 12.0))

    def test_an_open_arena_shows_more_from_the_centre_than_a_dense_one(self):
        foundry, yard = self.share("foundry"), self.share("yard")
        self.assertGreater(foundry, yard * 1.5,
                           "foundry ('mid-range with a little cover') should show far more from the centre than "
                           "yard ('dense lanes, short sightlines'): %.3f vs %.3f" % (foundry, yard))

    def test_the_maze_hides_the_most(self):
        """It is eight container walls; if anything shows less from the centre, the measure is upside down."""
        maze = self.share("maze")
        for other in ("foundry", "boulevard", "scrapyard"):
            self.assertLess(maze, self.share(other), "the maze should hide more than %s" % other)


class TestTheRouteOptimiserAndTheReportMeasureTheSameThing(unittest.TestCase):
    def test_a_bigger_cover_penalty_never_reports_a_more_exposed_route(self):
        p = Prepared("yard")
        watchers = ar.defending_positions(p.boxes, p.layout)
        field = ar.exposure_cost_field(p.grid, p.gn, p.blocked, p.n, watchers, ar.WATCHER_REACH_M)["idle"]
        green = tuple(p.layout["spawns"]["green"][0])
        rust = tuple(p.layout["spawns"]["rust"][0])
        last = None
        for _, penalty in ar.ROUTE_PENALTIES:
            path = ar.covered_route(p.blocked, p.n, field, green, rust, penalty)
            self.assertIsNotNone(path, "penalty %.1f still finds a way across" % penalty)
            value = ar.route_exposure(field, path)
            if last is not None:
                self.assertLessEqual(value, last + 1e-9,
                                     "penalty %.1f reported MORE exposure (%.3f) than the penalty below it (%.3f)"
                                     % (penalty, value, last))
            last = value


class TestTheTwoReachesAskDifferentQuestions(unittest.TestCase):
    """idle (a crew's own judgement) vs posted (a commander spent a support-by-fire task). The gap between them is
    the point: a map where they agree has no positions worth posting."""

    def fields(self, name):
        p = Prepared(name)
        watchers = ar.defending_positions(p.boxes, p.layout)
        return p, ar.exposure_cost_field(p.grid, p.gn, p.blocked, p.n, watchers, ar.WATCHER_REACH_M)

    def test_a_posted_element_never_covers_less_than_an_idle_one(self):
        """Same positions, same sightlines, strictly more reach. If posted < idle anywhere, the reach filter is
        inverted -- which is a one-character bug that would read as a map fact."""
        for name in ("yard", "foundry"):
            _, fields = self.fields(name)
            for key, idle in fields["idle"].items():
                self.assertLessEqual(idle, fields["posted"][key] + 1e-9,
                                     "%s at %s: idle %.3f exceeds posted %.3f" % (name, key, idle, fields["posted"][key]))

    def test_an_open_arena_rewards_posting_more_than_a_dense_one(self):
        """foundry is open ground with a little cover; yard is container walls. Posting an element on foundry should
        buy far more than posting one in the yard, or the measure is not about terrain at all."""
        gains = {}
        for name in ("foundry", "yard"):
            p, fields = self.fields(name)
            green = tuple(p.layout["spawns"]["green"][0])
            rust = tuple(p.layout["spawns"]["rust"][0])
            path = ar.covered_route(p.blocked, p.n, fields["idle"], green, rust, 0.0)
            gains[name] = ar.route_exposure(fields["posted"], path) - ar.route_exposure(fields["idle"], path)
        self.assertGreater(gains["foundry"], gains["yard"] * 2.0,
                           "posting buys %.3f on open foundry and %.3f in the dense yard" % (gains["foundry"], gains["yard"]))


class TestTheDecisionMetricSeesADilemmaAndItsAbsence(unittest.TestCase):
    """Round 7: cost AND reward. The lead — *"there generally has to be some compelling reason to cross the bridge
    to take some advantageous ground."* A route that is cheap and leads nowhere worth going is scenery."""

    def decision(self, name, objectives=None):
        p = Prepared(name)
        layout = dict(p.layout)
        if objectives is not None:
            layout["objectives"] = objectives
        watchers = ar.defending_positions(p.boxes, layout)
        fields = ar.exposure_cost_field(p.grid, p.gn, p.blocked, p.n, watchers, ar.WATCHER_REACH_M)
        return ar.decision_report(layout, p.boxes, p.blocked, p.n, p.grid, p.gn, fields["idle"], watchers)

    def test_one_central_objective_offers_no_decision_at_all(self):
        """Not a failure of the metric — the diagnosis. With one thing worth holding every route is the same
        route, and no amount of terrain can change that. Every arena we ship is in this state."""
        for name in ("yard", "foundry", "boulevard"):
            d = self.decision(name)
            self.assertEqual(d["objectives"], 1, "%s has one objective today" % name)
            self.assertEqual(d["decision_spread"], 0.0,
                             "%s: one objective can only produce one (cost, reward) point" % name)

    def test_a_mirrored_pair_gives_each_side_a_home_and_a_contest(self):
        """The case whose answer is known before running it: a mirrored pair puts one objective near green and its
        twin near rust, so green should see one cheap and one contested — which is exactly the dilemma the
        share-of-objectives scoring creates."""
        pair = [{"name": "west depot", "position": [-70.0, -30.0], "radius": 14.0},
                {"name": "east depot", "position": [70.0, 30.0], "radius": 14.0}]
        d = self.decision("yard", pair)
        quadrants = {r["objective"]: r["quadrant"] for r in d["routes"]}
        self.assertEqual(quadrants["east depot"], "dominant", "the one on green's side is cheap: %s" % quadrants)
        self.assertEqual(quadrants["west depot"], "the one we want",
                         "the one on rust's side is contested and worth taking: %s" % quadrants)
        self.assertGreater(d["decision_spread"], 0.2,
                           "and the map therefore offers a real decision (spread %.2f)" % d["decision_spread"])

    def test_two_objectives_at_the_same_distance_offer_no_contest(self):
        """The guard against reading 'more objectives' as 'more decision'. Two objectives equidistant from both
        bases are two ways to do the same thing."""
        symmetric = [{"name": "north gate", "position": [0.0, 40.0], "radius": 14.0},
                     {"name": "south gate", "position": [0.0, -40.0], "radius": 14.0}]
        paired = self.decision("yard", symmetric)
        d = self.decision("yard", [{"name": "east", "position": [40.0, 0.0], "radius": 14.0},
                                   {"name": "west", "position": [-40.0, 0.0], "radius": 14.0}])
        self.assertLess(d["decision_spread"], paired["decision_spread"] + 0.05,
                        "objectives equidistant from both bases spread less than an offset pair")


class TestTheFixtureIsNotTreatedAsAMap(unittest.TestCase):
    def test_the_maze_has_the_shortest_sightlines_of_anything_we_ship(self):
        maze = ar.longest_sightline(Prepared("maze").boxes)[0]
        yard = ar.longest_sightline(Prepared("yard").boxes)[0]
        self.assertLess(maze, yard, "the maze's longest sightline (%.0f m) should beat the densest arena's (%.0f m)"
                        % (maze, yard))


if __name__ == "__main__":
    unittest.main()
