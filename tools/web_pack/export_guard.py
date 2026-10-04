#!/usr/bin/env python3
"""Every file the game reaches for, against every export preset: is it in that pack? (ship W3, round 17)

Usage: export_guard.py [--presets export_presets.cfg] [--optional tools/web_pack/export_optional.json] [-v]

Lesson 239: the browser build was dead for eleven days because an export dropped something the game loads -- a
`FactionArt` script excluded with the art, and a `preload` of a `.gdignore`d `tools/` script -- and nothing looked.
This looks, statically, in about a second, with no Godot:

  REACHED  every game script (a `class_name` is global: excluding a script breaks whatever names it); every
           `res://` string literal in the game's scripts (game/**, assets/** minus the asset pipeline), with
           `%s`/`%d` read as wildcards and a directory read as everything under it; plus every `ext_resource` of the
           scenes and resources those reach (transitively).
  IN PACK  per preset, the way Godot's exporter decides it: not under a `.gdignore`d folder; not matched by
           `exclude_filter`; and either a resource Godot exports by itself (a script, scene, resource, shader, or a
           file with an `.import` sidecar) or matched by `include_filter` (trip-up 30: a JSON nobody listed is not
           exported). Filters match with Godot's `matchn`: case-insensitive, `*` crosses `/`, against the path with and
           without `res://`.

A reached file missing from a pack is a FAILURE unless `export_optional.json` declares it: which presets may drop it,
why, and the code that copes with its absence (a `handled_by` file and a snippet that must still be in it -- so a
declared fallback that is deleted turns the guard red too). A declared entry that no longer matches anything reached
is also reported, so the list cannot rot into a blanket pass.
"""
import argparse
import configparser
import fnmatch
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SELF_EXPORTED = {".gd", ".tscn", ".tres", ".res", ".scn", ".gdshader", ".gdshaderinc", ".gdns", ".theme", ".json"}
# Never in any pack: docs and their evidence, tests, build output (trip-ups 47 and 56).
FORBIDDEN_IN_PACK = ("_agents/", "tests/", "build/")
# Files a folder holds for people, never loaded: a directory reach does not count them.
NOT_CONTENT = (".md", ".gitignore", ".gdignore", ".import", ".uid", ".txt")
SCRIPT_ROOTS = ["game", "assets"]
SCRIPT_SKIP = ["assets/pipeline/"]  # the asset pipeline is an editor tool, excluded from every pack on purpose
LITERAL = re.compile(r'"res://([^"\s]*)"')
EXT_RESOURCE = re.compile(r'\[ext_resource[^\]]*path="res://([^"]+)"')


def walk_files():
    """Every project file (relative path), and the set of .gdignore'd folders."""
    files, ignored = [], []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        rel = os.path.relpath(dirpath, ROOT)
        rel = "" if rel == "." else rel + "/"
        if rel.startswith((".godot/", ".git/", ".tools/")) or rel in (".godot/", ".git/", ".tools/"):
            dirnames[:] = []
            continue
        if ".gdignore" in filenames and rel:
            ignored.append(rel)
        dirnames[:] = [d for d in dirnames if not d.startswith(".") and d != "node_modules"]
        for name in filenames:
            files.append(rel + name)
    return files, ignored


def read_presets(path):
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    cp.read(path)
    presets = []
    for section in cp.sections():
        if re.fullmatch(r"preset\.\d+", section):
            get = lambda k: cp.get(section, k, fallback='""').strip().strip('"')
            split = lambda v: [f.strip() for f in v.split(",") if f.strip()]
            if cp.get(section, "patches", fallback="").strip() not in ("", 'PackedStringArray()'):
                continue  # a PATCH pack (e.g. "Web Factions") is never a whole game: its base preset is judged
            presets.append({"name": get("name"), "export_filter": get("export_filter"),
                            "include": split(get("include_filter")), "exclude": split(get("exclude_filter"))})
    return presets


def matchn(path, filters):
    low = path.lower()
    return any(fnmatch.fnmatchcase(low, f.lower()) or fnmatch.fnmatchcase("res://" + low, f.lower()) for f in filters)


def in_pack(path, preset, files_set, ignored):
    if any(path.startswith(d) for d in ignored):
        return False, "under a .gdignore'd folder"
    if matchn(path, preset["exclude"]):
        return False, "exclude_filter"
    ext = os.path.splitext(path)[1].lower()
    if ext in SELF_EXPORTED or (path + ".import") in files_set:
        return True, ""
    if matchn(path, preset["include"]):
        return True, ""
    return False, "not a resource and not in include_filter"


def reached(files, files_set):
    """{path: [where it is reached from]} for every file the game's code or scenes name."""
    scripts = [f for f in files if f.endswith(".gd") and f.split("/")[0] in SCRIPT_ROOTS
               and not any(f.startswith(s) for s in SCRIPT_SKIP)]
    out = {}
    unmatched = []
    dir_reach = {}
    dirs = sorted({f.rsplit("/", 1)[0] for f in files if "/" in f} | {"/".join(f.split("/")[:i]) for f in files for i in range(1, f.count("/"))})

    def add(path, where):
        out.setdefault(path, [])
        if where not in out[path]:
            out[path].append(where)

    # Every game script is reached: a `class_name` is global, so any script may name any other without a path, and an
    # excluded script fails to compile every script that names it (lesson 239: `FactionArt` excluded with the art).
    for script in scripts:
        add(script, "a game script (class_name is global)")
    for script in scripts:
        with open(os.path.join(ROOT, script), encoding="utf-8", errors="replace") as f:
            for lineno, line in enumerate(f, 1):
                stripped = line.lstrip()
                if stripped.startswith("#") or stripped.startswith("##"):
                    continue
                for lit in LITERAL.findall(line):
                    where = f"{script}:{lineno}"
                    lit = lit.split(" ")[0].rstrip("/")
                    if not lit:
                        continue
                    pattern = re.sub(r"%[-0-9.]*[sdif]|\{[^}]*\}", "*", lit)
                    if pattern in files_set:
                        add(pattern, where)
                        continue
                    file_hits = [p for p in files if fnmatch.fnmatchcase(p, pattern) and not p.endswith((".import", ".uid"))]
                    dir_hits = sorted({d for d in dirs if fnmatch.fnmatchcase(d, pattern)})
                    if not file_hits and not dir_hits:
                        unmatched.append((lit, where))
                    for p in file_hits:
                        add(p, where)
                    if dir_hits:
                        # A folder the game lists or reads by name: it must reach the pack with SOMETHING in it.
                        # `res://game/theme/%s/generated` is any one of several, so the pattern is the unit.
                        key = pattern
                        dir_reach.setdefault(key, {"dirs": dir_hits, "where": []})
                        if where not in dir_reach[key]["where"]:
                            dir_reach[key]["where"].append(where)
    # The engine reaches for some files by itself: every res:// path project.godot names (main scene, icon, autoloads,
    # fonts, ...) and the bus layout Godot loads by default when the file exists (audio/buses/default_bus_layout,
    # res://default_bus_layout.tres: round 17, guns' fix for the browser's silence lives in it, so a preset that
    # dropped it would silence the browser build again).
    with open(os.path.join(ROOT, "project.godot"), encoding="utf-8", errors="replace") as f:
        for lit in LITERAL.findall(f.read()):
            if lit in files_set:
                add(lit, "project.godot")
    if "default_bus_layout.tres" in files_set:
        add("default_bus_layout.tres", "Godot's default bus layout (audio/buses/default_bus_layout)")
    # Scenes and resources pull in what they name, transitively.
    queue = [p for p in out if p.endswith((".tscn", ".tres"))]
    seen = set()
    while queue:
        scene = queue.pop()
        if scene in seen or scene not in files_set:
            continue
        seen.add(scene)
        with open(os.path.join(ROOT, scene), encoding="utf-8", errors="replace") as f:
            for dep in EXT_RESOURCE.findall(f.read()):
                add(dep, scene)
                if dep.endswith((".tscn", ".tres")):
                    queue.append(dep)
    return out, unmatched, dir_reach


def calibrate(pack, preset, reach, files_set, ignored):
    """The guard's model of Godot's exporter, checked against a real pack: for every reached file, predicted in or
    out must be what the pack holds. A disagreement means the model is wrong, and a wrong model passes breaks."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from pck_ls import read_pack, resolve
    entries = read_pack(pack)
    held = {name.removeprefix("res://") for name, _ in entries}
    wrong = []
    # What no pack should carry: the repo's docs and evidence (107 MB of the web pack at 3713fdaa), tests, build output.
    # Imported files are named under .godot/imported/ by their basename, so their sidecars are what is checked.
    for prefix in FORBIDDEN_IN_PACK:
        n = sum(1 for name in held if name.startswith(prefix))
        mb = sum(size for name, size in resolve(entries)[0].items() if name.startswith(prefix)) / 1e6
        if n:
            wrong.append(f"{os.path.basename(pack)} carries {n} files under {prefix} ({mb:.1f} MB): nothing in the "
                         f"game reads them -- add '{prefix}*' to the preset's exclude_filter"
                         f" (MB counts imports whose source name is unique; ambiguous ones are not attributed)")
    for path in sorted(reach):
        if path not in files_set:
            continue
        predicted = in_pack(path, preset, files_set, ignored)[0]
        actual = any(n in held for n in (path, path + ".import", path + ".remap"))
        if predicted != actual:
            wrong.append(f"calibration ({preset['name']}, {os.path.basename(pack)}): res://{path} predicted "
                         f"{'IN' if predicted else 'OUT'}, the pack has it {'IN' if actual else 'OUT'}")
    print(f"   calibrated against {pack}: {len(held)} entries, {len(wrong)} disagreements over {len(reach)} reached files")
    return wrong[:20]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--presets", default=os.path.join(ROOT, "export_presets.cfg"))
    ap.add_argument("--optional", default=os.path.join(ROOT, "tools/web_pack/export_optional.json"))
    ap.add_argument("-v", "--verbose", action="store_true")
    ap.add_argument("--pack", help="an exported .pck: also check this guard's prediction against what it really holds")
    ap.add_argument("--pack-preset", default="Web", help="the preset --pack was exported with")
    a = ap.parse_args()
    files, ignored = walk_files()
    files_set = set(files)
    presets = read_presets(a.presets)
    with open(a.optional) as f:
        optional = json.load(f)["optional"]
    reach, unmatched, dir_reach = reached(files, files_set)
    failures, used = [], set()
    dropped_ok = {}
    for preset in presets:
        for path, wheres in sorted(reach.items()):
            if path not in files_set:
                continue  # an ext_resource to a missing file is Godot's own error, not an export question
            ok, why = in_pack(path, preset, files_set, ignored)
            if ok:
                continue
            declared = [i for i, o in enumerate(optional)
                        if preset["name"] in o["presets"] and fnmatch.fnmatchcase(path, o["glob"])]
            if declared:
                used.update(declared)
                dropped_ok.setdefault((preset["name"], optional[declared[0]]["glob"]), 0)
                dropped_ok[(preset["name"], optional[declared[0]]["glob"])] += 1
                continue
            failures.append(f"{preset['name']}: res://{path} is NOT in the pack ({why}), but the game reaches for it "
                            f"at {', '.join(wheres[:3])}{' …' if len(wheres) > 3 else ''}")
        for pattern, info in sorted(dir_reach.items()):
            shipped = [f for f in files if any(f.startswith(d + "/") for d in info["dirs"])
                       and not f.endswith(NOT_CONTENT) and in_pack(f, preset, files_set, ignored)[0]]
            if shipped:
                continue
            declared = [i for i, o in enumerate(optional)
                        if preset["name"] in o["presets"] and fnmatch.fnmatchcase(pattern + "/", o["glob"])]
            if declared:
                used.update(declared)
                key = (preset["name"], optional[declared[0]]["glob"])
                dropped_ok[key] = dropped_ok.get(key, 0) + 1
                continue
            failures.append(f"{preset['name']}: res://{pattern}/ has NOTHING in the pack, but the game reads that folder "
                            f"at {', '.join(info['where'][:3])}")
    for i, o in enumerate(optional):
        handled = os.path.join(ROOT, o["handled_by"])
        if not os.path.exists(handled) or o["snippet"] not in open(handled, encoding="utf-8").read():
            failures.append(f"export_optional.json: '{o['glob']}' says {o['handled_by']} copes with its absence "
                            f"(\"{o['snippet']}\"), and that code is gone")
        elif i not in used:
            failures.append(f"export_optional.json: '{o['glob']}' ({', '.join(o['presets'])}) matches nothing any "
                            f"preset drops any more -- remove it, or it will excuse the next real break")
    if a.pack:
        failures += calibrate(a.pack, next(p for p in presets if p["name"] == a.pack_preset), reach, files_set, ignored)
    print(f">> export-guard: {len(reach)} files reached by the game, {len(presets)} presets "
          f"({', '.join(p['name'] for p in presets)}), {len(optional)} declared optional")
    for (preset, glob), n in sorted(dropped_ok.items()):
        print(f"   declared drop: {preset}: {n} reached files under {glob}")
    if a.verbose:
        for lit, where in unmatched:
            print(f"   (no file matches res://{lit} at {where}: written at runtime or not built yet)")
    if failures:
        print("EXPORT GUARD FAILED:")
        for line in failures:
            print("  " + line)
        return 1
    print("EXPORT GUARD PASSED: every file the game reaches for is in every pack, or declared optional with its fallback")
    return 0


if __name__ == "__main__":
    sys.exit(main())
