"""`tools/make_arenas.py`'s own guards (scale, round 9).

The generator writes `arenas/*.json` from scratch, so **any top-level key it does not know about is deleted on the
next `make arenas`**. The show stream authors a `show` key in those files by hand; this is what stops a routine
regeneration from silently reverting it. Both directions are checked: a preserved key survives, and a key that is
NOT on the allowlist does not -- otherwise the allowlist would be decoration.
"""

import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))


def regenerate(out_dir):
    return subprocess.run([sys.executable, "tools/make_arenas.py", str(out_dir)],
                          cwd=ROOT, capture_output=True, text=True)


class PreservedKeysTest(unittest.TestCase):
    def setUp(self):
        self.out = pathlib.Path(tempfile.mkdtemp())
        first = regenerate(self.out)
        self.assertEqual(first.returncode, 0, first.stderr)
        self.layouts = sorted(p.name for p in self.out.glob("*.json"))
        self.assertEqual(len(self.layouts), 10, "every shipped layout is generated (%s)" % self.layouts)

    def test_a_preserved_key_survives_regeneration_and_is_reported(self):
        # NOT `import make_arenas`: the module reads `sys.argv[1]` as its output directory and generates every
        # layout at import time, so importing it from a test writes ten files into a directory called "discover".
        # A tool whose import has side effects is a tool you read rather than import.
        source = (ROOT / "tools" / "make_arenas.py").read_text()
        self.assertIn('PRESERVED_KEYS = ("show",)', source,
                      "the allowlist is one named constant and it names the key the show stream authors")
        target = self.out / "terminus.json"
        planted = {"channels": {"rim": {"programme": "breathe", "period": 24.0}}, "patch": []}
        data = json.loads(target.read_text())
        data["show"] = planted
        target.write_text(json.dumps(data, indent=1) + "\n")

        again = regenerate(self.out)
        self.assertEqual(again.returncode, 0, again.stderr)
        self.assertEqual(json.loads(target.read_text()).get("show"), planted,
                         "the show patch survived `make arenas`")
        self.assertIn("ARENA_KEPT terminus: show", again.stdout, "and the generator said which key it carried")
        # The other nine must not have grown one.
        for name in self.layouts:
            if name != "terminus.json":
                self.assertNotIn("show", json.loads((self.out / name).read_text()),
                                 "%s did not inherit terminus's patch" % name)

    def test_a_key_not_on_the_allowlist_is_still_dropped(self):
        # The direction that makes the allowlist mean something. If everything survived, `PRESERVED_KEYS` would be
        # decoration and a stale hand-edit could outlive the value it was copied from.
        target = self.out / "yard.json"
        data = json.loads(target.read_text())
        data["lighting_rig"] = {"left_over": True}
        target.write_text(json.dumps(data, indent=1) + "\n")
        self.assertEqual(regenerate(self.out).returncode, 0)
        self.assertNotIn("lighting_rig", json.loads(target.read_text()),
                         "a key the generator does not preserve is regenerated away")

    def test_regeneration_is_otherwise_byte_stable(self):
        # A generator that is not idempotent makes every unrelated commit look like a layout change.
        before = {name: (self.out / name).read_text() for name in self.layouts}
        self.assertEqual(regenerate(self.out).returncode, 0)
        for name in self.layouts:
            self.assertEqual((self.out / name).read_text(), before[name], "%s regenerated identically" % name)


class SpawnGridTest(unittest.TestCase):
    def test_the_generated_spawn_grid_is_read_from_match_gd(self):
        # Invariant 0: this used to be a COPY of Match.SLOT_X behind a comment saying "must mirror", and the copy
        # won, because Arena.spawn_spot beats the constants. Mutation-checked from the source side: change the
        # constant and the generated list has to move with it.
        import gdscript_source
        match_gd = gdscript_source.GAME / "match" / "match.gd"
        columns = gdscript_source.const(match_gd, "SLOT_X")
        rows = int(gdscript_source.const(match_gd, "SPAWN_ROWS"))
        spacing = gdscript_source.const_float(match_gd, "SPAWN_ROW_SPACING")
        base_z = gdscript_source.const_float(match_gd, "BASE_Z")
        out = pathlib.Path(tempfile.mkdtemp())
        self.assertEqual(regenerate(out).returncode, 0)
        green = json.loads((out / "yard.json").read_text())["spawns"]["green"]
        self.assertEqual(len(green), len(columns) * rows, "one slot per column per row")
        self.assertEqual(sorted({z for _, z in green}),
                         sorted({base_z + r * spacing for r in range(rows)}), "the rows are where match.gd says")
        self.assertEqual(sorted({x for x, _ in green}), sorted(float(c) for c in columns),
                         "and the columns are match.gd's, not a copy of them")


if __name__ == "__main__":
    unittest.main()
