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
import pathlib
import re
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
    """One layout's grids, built once: each is a second or two of work.

    `ar.use_extent()` sets MODULE globals (HALF, DRIVABLE, FIELD_Z), because every geometry helper reads them —
    so a cached grid is only valid while its own extent is the active one. Getting a `Prepared` re-activates its
    extent, which is what makes the cache safe to share between tests that use differently-sized arenas. Without
    that, a test touching a 140 m layout silently corrupted every later test on a 120 m one.
    """

    _cache = {}

    def __new__(cls, name, half=None):
        key = (name, half)
        if key not in cls._cache:
            self = object.__new__(cls)
            self.layout = load(name)
            if half is not None:
                self.layout["half_size"] = half
            ar.use_extent(self.layout)
            self.boxes = ar.boxes_of(self.layout)
            self.blocked, self.n = ar.occupancy(self.boxes)
            self.grid, self.gn = ar.sight_grid(self.boxes)
            cls._cache[key] = self
        cached = cls._cache[key]
        ar.use_extent(cached.layout)  # re-arm the globals this instance's grids were built under
        return cached


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
        """Not a failure of the metric — the diagnosis. With one thing worth holding every route is the same route,
        and no amount of terrain can change that.

        **This test said "every arena we ship is in this state" and named yard, which stopped being true the moment
        objective pairs shipped (`0f18710a`).** It had been red ever since and nobody saw it.

        **CORRECTION, and the first explanation I gave was wrong.** I wrote in `daa6bb70` that it was hidden behind
        two earlier failing targets in `make check`. It was not: **`arena-pytest` is deliberately not in `make check`
        at all** (see the note above its recipe in `mk/arena.mk` — it guards an instrument only this stream reads,
        and 14 s on every stream's check is a bad trade). So nothing masked it. **`make arena-test` is the gate, my
        own brief requires it on every layout change, and I changed the layouts and did not run it.** The mechanism
        was not subtle and the miss was mine — which is worth more than the tidier story about nested reds.

        The fix is to state the property instead of a roster: a layout with ONE objective has no decision to offer.
        `foundry` is chosen because it is `Arena.DEFAULT_LAYOUT` and the sim baseline runs on it, so if it ever
        gains a pair, a lot more than this test wants to know."""
        for name in ("foundry", "scrapyard"):
            d = self.decision(name)
            self.assertEqual(d["objectives"], 1, "%s has one objective today" % name)
            self.assertEqual(d["decision_spread"], 0.0,
                             "%s: one objective can only produce one (cost, reward) point" % name)
        # And the other half of the property, on a map that DOES have a pair: two objectives, a real spread.
        paired = self.decision("yard")
        self.assertEqual(paired["objectives"], 2, "yard ships a mirrored pair (0f18710a)")
        self.assertGreater(paired["decision_spread"], 0.0, "two objectives can differ in cost")

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


class TestTheExposureLatticeIsAnchored(unittest.TestCase):
    """The bug this guards produced a perfectly plausible wrong answer on every hexagonal map.

    `_exposure_at` looks a route point up by rounding to a multiple of EXPOSURE_STEP, so the field's own keys have
    to be multiples of it. Once the measurement window followed the layout, a half_size of 140 gave a depth of 98
    and z ran -98, -94, -90 ... so every lookup missed and returned the default 0.0. Exposure read **0.000 across
    both hexagonal maps** -- a believable figure for an arena full of shipping containers, and completely wrong.
    A square's depth of 84 is a multiple of 4, which is why it never showed until an arena changed size.
    """

    def test_field_keys_land_on_the_lattice_exposure_is_looked_up_on(self):
        for name, half in (("yard", 140.0), ("foundry", 120.0)):
            p = Prepared(name, half)
            for x, z in ar.field_points(p.blocked, p.n)[:200]:
                self.assertEqual(int(x) % int(ar.EXPOSURE_STEP), 0, "%s: x=%s is off the lattice" % (name, x))
                self.assertEqual(int(z) % int(ar.EXPOSURE_STEP), 0, "%s: z=%s is off the lattice" % (name, z))

    def test_a_map_full_of_containers_is_not_reported_as_perfectly_covered(self):
        """The symptom, asserted directly: yard has real exposure, and a zero here means the lookup missed."""
        p = Prepared("yard")
        watchers = ar.defending_positions(p.boxes, p.layout)
        fields = ar.exposure_cost_field(p.grid, p.gn, p.blocked, p.n, watchers, ar.WATCHER_REACH_M)
        green = tuple(p.layout["spawns"]["green"][0])
        rust = tuple(p.layout["spawns"]["rust"][0])
        path = ar.covered_route(p.blocked, p.n, fields["idle"], green, rust, 0.0)
        self.assertGreater(ar.route_exposure(fields["idle"], path), 0.0,
                           "the direct crossing of a shipping arena is exposed to something")


class TestTheToolAgreesWithTheGameItModels(unittest.TestCase):
    """Four checks that this tool has not drifted from the code it mirrors.

    **All four were written as module-level `def test_...()` functions and never ran once.** `make arena-pytest` is
    `unittest discover`, which collects `TestCase` subclasses and silently ignores bare functions, so the suite
    reported the same 14 tests before and after they were added and they "passed" by not existing. Caught by the
    count not moving. A test that cannot fail is worse than no test: it is a green light wired to nothing.
    """

    def test_the_kit_table_still_matches_the_game(self):
        """arena_report.KIT is a hand copy of ArenaKit.PROPS and nothing used to check it.

        Round 8, and it is not hypothetical: `block` (40 x 24 x 40) shipped in `game/arena/arena_kit.gd` in round 7
        and was missing here until a map tried to place one. That failure was loud -- a KeyError -- so it cost
        minutes. **A prop whose SIZE drifted would not be loud.** Every distance, exposure and clearance this tool
        reports is computed from these boxes, so a stale size produces numbers that are wrong, plausible and
        published. This test is the cheap version of the dependency the comment asks for.
        """
        source = (pathlib.Path(__file__).resolve().parent.parent / "game/arena/arena_kit.gd").read_text()
        body = source.split("const PROPS := {", 1)[1].split("\n}", 1)[0]
        game = {}
        for name, fields in re.findall(r'"(\w+)":\s*\{([^}]*)\}', body):
            size = re.search(r'"size":\s*\[([^\]]*)\]', fields)
            cover = re.search(r'"cover":\s*"(\w+)"', fields)
            if not size or not cover:
                continue
            game[name] = ([float(v) for v in size.group(1).split(",")], cover.group(1),
                          "\"collides\": false" not in fields)
        assert game, "could not parse ArenaKit.PROPS -- the test is broken, not the tables"
        assert set(game) == set(ar.KIT), (
            "arena_report.KIT and ArenaKit.PROPS list different props: only in the game %s, only here %s"
            % (sorted(set(game) - set(ar.KIT)), sorted(set(ar.KIT) - set(game))))
        for name, (size, cover, collides) in game.items():
            assert ar.KIT[name] == (size, cover, collides), (
                "%s disagrees: the game says %s, arena_report.KIT says %s" % (name, (size, cover, collides), ar.KIT[name]))


    def test_the_closed_end_watch_flags_the_map_nobody_has_ruled_on(self):
        """`centre_sees_share` has a target at the open end and nothing at the closed end, so a map can be too closed
        and pass everything.

        The property that matters here is not the thresholds — it is that the reference excludes terminus. My first
        version calibrated the range over every shipping map, terminus included, so the newest and most closed map
        defined the low end and could never trip its own flag: a guard calibrated on the thing it watches. This test
        fails if anyone recalibrates it that way again.
        """
        terminus = ar.analyze(json.loads((pathlib.Path(__file__).resolve().parent.parent / "arenas" / "terminus.json").read_text()))
        yard = ar.analyze(json.loads((pathlib.Path(__file__).resolve().parent.parent / "arenas" / "yard.json").read_text()))
        assert ar.openness_notes(terminus), "terminus is outside the judged range on both measures and must be flagged"
        assert not ar.openness_notes(yard), "yard is a map the lead KEPT and must not be flagged"


    def test_cover_is_a_step_function_of_hull_length_at_the_longest_prop(self):
        """Round 8, combat: the arena kit's longest prop is `container_40` at 12.19 m, so a hull longer than that has
        nothing on yard or pit to hide behind — and **cover fails silently**: the hull still drives to cover, still
        counts as near cover, and is not covered.

        The property worth locking down is that this is a CLIFF, not a gradient. Yard covers 0.99 of the field for any
        hull up to 12.19 m and 0.00 for anything past it. That is what makes the rig's length a binary question rather
        than a styling one, and it is the number the lead needs to rule on 12 m vs 14 m.
        """
        yard = json.loads((pathlib.Path(__file__).resolve().parent.parent / "arenas" / "yard.json").read_text())
        boxes = ar.boxes_of(yard)
        assert ar.hull_cover_reach(yard, boxes, 12.19) > 0.9, "yard covers a hull up to the container's own length"
        assert ar.hull_cover_reach(yard, boxes, 12.5) == 0.0, "and nothing at all past it — a cliff, not a slope"
        terminus = json.loads((pathlib.Path(__file__).resolve().parent.parent / "arenas" / "terminus.json").read_text())
        assert ar.hull_cover_reach(terminus, ar.boxes_of(terminus), 14.0) > 0.85, \
            "the cityscape's 40 m blocks cover a 14 m hull where the container maps cannot"


    def test_the_hull_cover_warning_actually_reaches_the_reader(self):
        """The measure was right and the WARNING WAS DEAD. `hull_cover_reach` correctly returned 0.00 for yard the
        moment the 14 m rig landed, and no WATCH line appeared, because the note read a `_longest_hull` key that
        `main()` strips along with every other "_"-prefixed private key before the notes are built.

        **Second dead guard of the same session** — after four tests that `unittest discover` never collected. Both
        were green by absence. So this test exercises the NOTE, not the number behind it: a measurement nobody is
        ever shown is not a warning.
        """
        root = pathlib.Path(__file__).resolve().parent.parent
        yard = json.loads((root / "arenas" / "yard.json").read_text())
        boxes = ar.boxes_of(yard)
        hulls = ar.hull_lengths()
        longest = max(hulls, key=lambda k: hulls[k])
        report = {"ambush": {"centre_sees_share": 0.2}, "drivable_share": 0.51, "mean_view_m": 54.3,
                  "hull_cover": {"longest_hull": longest, "longest_hull_m": hulls[longest],
                                 "reach": ar.hull_cover_reach(yard, boxes, hulls[longest]),
                                 "longest_prop_m": 12.19}}
        notes = ar.openness_notes(report)
        # Round 9 (A3): the note no longer says "hide the longest hull" -- that sentence was TRUE under
        # centre-point registration and is FALSE under `Arena.cover_fraction`, so it was rewritten rather than
        # deleted (the lead's ruling: a WATCH line that is confidently wrong is worse than silence). This guard
        # keys on the reach reaching the reader, not on a form of words, so rewording it again cannot kill it.
        def flagged(report_dict):
            return [n for n in ar.openness_notes(report_dict) if "longest hull" in n]

        if report["hull_cover"]["reach"] < 0.01:
            hit = flagged(report)
            assert hit, "reach is %.2f and the reader is told nothing: %s" % (report["hull_cover"]["reach"], notes)
            assert "SUPERSEDED" in hit[0], "and the reader is told which definition produced it: %s" % hit[0]
            assert "arena-cover" in hit[0], "and where the live figure comes from: %s" % hit[0]
        # And the same report with a hull everything can hide must stay quiet.
        report["hull_cover"] = dict(report["hull_cover"], longest_hull_m=4.0,
                                    reach=ar.hull_cover_reach(yard, boxes, 4.0))
        assert not flagged(report), "a 4 m hull hides fine on yard and must not be flagged"

    def test_hull_lengths_are_read_from_the_game_not_copied(self):
        """If this file carried its own table of hull sizes it would be a third copy to keep in step, and the rig's
        length is being argued about right now (12 m vs 14 m). Reading the catalog means the cover check re-answers
        itself the moment combat changes a number, with nobody remembering to update the tool."""
        hulls = ar.hull_lengths()
        assert len(hulls) > 10, "the catalog parsed: %d hulls" % len(hulls)
        assert "gang_tank" in hulls, "the War Rig is in there under its catalog name"
        assert all(0.5 < v < 60.0 for v in hulls.values()), "lengths are metres, not some other field: %s" % hulls
