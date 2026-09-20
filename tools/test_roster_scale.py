"""The roster tools' own guards (scale, round 9): the catalog reader, and that it REFUSES instead of falling back.

Invariant 0's three clauses, as tests: a reader must pick up a value that is added, it must refuse when the source
it reads is renamed, and it must never fall back to a remembered list. Round 8 shipped two guards in one session
that could not fire; both were green by absence. So each of these is checked in both directions.
"""

import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import roster_scale
import units_catalog


def catalog_text():
    return units_catalog.UNITS_GD.read_text()


def written(text):
    path = pathlib.Path(tempfile.mkdtemp()) / "units.gd"
    path.write_text(text)
    return path


class ReaderTest(unittest.TestCase):
    def test_it_reads_the_real_catalog(self):
        profiles = units_catalog.load()
        self.assertEqual(len(profiles), 21, "the catalog has 21 units")
        for unit_id, profile in profiles.items():
            self.assertEqual(len(profile["hull_size"]), 3, unit_id)
            self.assertIn("scale_reference", profile, "%s carries a reference vehicle (contract S1)" % unit_id)

    def test_a_blurb_with_a_hash_or_a_colon_in_it_is_not_mistaken_for_syntax(self):
        # `#` starts a comment and `:` separates a key -- except inside a string, which is where blurbs live.
        text = catalog_text().replace(
            '"blurb": "The armored prison-bus dozer.',
            '"blurb": "#1: the armored prison-bus dozer.', 1)
        profiles = units_catalog.load(written(text))
        self.assertTrue(profiles["tank"]["blurb"].startswith("#1: "))
        self.assertEqual(len(profiles), 21, "and nothing else was swallowed")

    def test_a_unit_added_to_the_catalog_is_picked_up(self):
        # The direction a reader usually gets right, checked anyway: a table that silently omits a new unit would
        # look complete (Invariant 0's faction_matrix.py row).
        addition = '\t"test_unit": {\n\t\t"hull_size": [1.0, 2.0, 3.0],\n\t\t"faction": "law",\n\t},\n}\n'
        text = catalog_text().replace('\t\t"designates": true,\n\t},\n}\n',
                                      '\t\t"designates": true,\n\t},\n' + addition, 1)
        profiles = units_catalog.load(written(text))
        self.assertIn("test_unit", profiles)
        self.assertEqual(profiles["test_unit"]["hull_size"], [1.0, 2.0, 3.0])

    def test_renaming_the_constant_it_reads_raises_rather_than_returning_a_default(self):
        text = catalog_text().replace("const PROFILES :=", "const VEHICLES :=", 1)
        with self.assertRaises(units_catalog.CatalogError):
            units_catalog.load(written(text))

    def test_a_value_it_cannot_parse_raises_rather_than_being_skipped(self):
        text = catalog_text()
        first = text.index('"hull_size": [')
        end = text.index("],", first) + 2
        text = text[:first] + '"hull_size": SOME_CONSTANT * 2,' + text[end:]
        with self.assertRaises(units_catalog.CatalogError):
            units_catalog.load(written(text))

    def test_a_missing_constant_raises(self):
        text = catalog_text().replace("const RIG_LENGTH_M := 14.0", "const RIG_METRES := 14.0", 1)
        with self.assertRaises(units_catalog.CatalogError):
            units_catalog.const_float("RIG_LENGTH_M", written(text))


class ScaleTest(unittest.TestCase):
    def test_k_is_the_ruled_rig_length_over_its_reference(self):
        profiles = units_catalog.load()
        rig_length = units_catalog.const_float("RIG_LENGTH_M")
        k = roster_scale.scale_k(profiles, rig_length, "gang_tank")
        self.assertAlmostEqual(k, rig_length / profiles["gang_tank"]["scale_reference"]["length_m"])
        self.assertTrue(0.6 < k < 0.8, "the world is drawn at roughly three quarters of real size (K=%.3f)" % k)

    def test_every_hull_length_in_the_catalog_is_its_reference_times_k(self):
        # The same assertion tests/test_units_scale.gd makes, from Python, so `make roster-scale` can never print a
        # table that disagrees with the catalog it was derived from.
        profiles = units_catalog.load()
        k = roster_scale.scale_k(profiles, units_catalog.const_float("RIG_LENGTH_M"), "gang_tank")
        for unit_id, profile in profiles.items():
            wanted = round(profile["scale_reference"]["length_m"] * k, 2)
            self.assertAlmostEqual(profile["hull_size"][2], wanted, delta=0.011,
                                   msg="%s: catalog %.2f m, rule %.2f m" % (unit_id, profile["hull_size"][2], wanted))

    def test_it_refuses_to_invent_k_when_the_anchor_loses_its_reference(self):
        profiles = units_catalog.load()
        del profiles["gang_tank"]["scale_reference"]
        with self.assertRaises(units_catalog.CatalogError):
            roster_scale.scale_k(profiles, 14.0, "gang_tank")

    def test_it_refuses_when_the_anchor_unit_is_renamed(self):
        profiles = units_catalog.load()
        with self.assertRaises(units_catalog.CatalogError):
            roster_scale.scale_k(profiles, 14.0, "war_rig")

    def test_a_mismatch_is_reported_as_a_fraction_of_the_mesh(self):
        self.assertAlmostEqual(roster_scale.worst_mismatch([2.0, 1.0, 3.0], [1.0, 1.0, 3.0]), 1.0)
        self.assertEqual(roster_scale.worst_mismatch([2.0, 1.0, 3.0], None), 0.0, "no mesh is not a disagreement")


if __name__ == "__main__":
    unittest.main()
