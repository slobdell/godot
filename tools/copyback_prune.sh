#!/usr/bin/env bash
# copyback_prune.sh ROOT MANIFEST: after the copy-back, MOVE the logs an earlier run left among this run's rows.
#
# Why (round 35, X5 (b)): the copy-back's `P *.log` keeps every local log from --delete, for the wrapper logs being written
# into build/. It kept an earlier run's series rows too: the box clears manoeuvre-hull-rest's arm before a run, the
# copy-back then deleted each old <task>-<seed>/screen.json here but kept its run.log, and a reader pooled the old seeds with
# the new (brains' Bar E1 found seeds 601-616 beside its own; E2 had to filter by seed).
#
# A local *.log is an earlier run's when ALL hold:
#   - it is not in MANIFEST (the box's list of what it sent this run);
#   - no process has it open (a wrapper's `> build/.../x.log` still being written);
#   - it is not directly in build/ or build/metrics/ (where wrapper logs are written, remote_builds.md);
#   - its top folder build/<X>/ is one the box sent (a local measurement in a folder the box never had is left alone);
#   - it is not under a REMOTE_COPYBACK_PROTECT path, a .stale-* folder, or (the main lane) build/light/.
# It is MOVED, not deleted (an earlier run's rows can be filed evidence), to build/.stale-<timestamp>/<its path below build/>;
# run folders it empties are removed. The move is to build/'s top, not beside the series: os.listdir, os.walk and rglob all
# see a dot-folder, and tests/tactics/e1_bar.py and leg_wait_table.py list a faction's run folders with os.listdir, so a
# .stale-* folder inside the series would read as one more run. No series reader is rooted at build/ itself.
#
# ROOT is the folder holding build/ (the repo, or build/light for the light lane), as copyback_verify.sh takes it. No
# manifest: nothing moved, one line, exit 0 (an older checkout on the box writes none). Never fails the run: exit 0 always.
set -uo pipefail
root=$1 manifest=$2
if [ ! -s "$manifest" ]; then
	echo ">> remote: stale-log move NOT CHECKED: no copy-back manifest ($manifest)" >&2
	exit 0
fi
open_files=$(find /proc/[0-9]*/fd -maxdepth 1 -type l -printf '%l\n' 2>/dev/null | sort -u)
OPEN_FILES="$open_files" python3 -I - "$root" "$manifest" "$(date +%Y%m%d-%H%M%S)" "${REMOTE_COPYBACK_PROTECT:-}" <<'PY'
import os, sys
root, manifest, stamp, protect = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4].split()
sent = set()
with open(manifest, encoding="utf-8", errors="surrogateescape") as f:
    for line in f:
        line = line.rstrip("\n")
        if line.startswith("\\"):  # sha256sum escapes a name with a backslash or newline; such a file is never moved
            continue
        parts = line.split("  ", 1)
        if len(parts) == 2:
            sent.add(parts[1])
held = set(os.environ.get("OPEN_FILES", "").splitlines())
tops = {"/".join(p.split("/")[:2]) for p in sent if p.count("/") >= 2}
holding = set()  # every folder with a sent file at or below it
for p in sent:
    d = os.path.dirname(p)
    while d and d not in holding:
        holding.add(d)
        d = os.path.dirname(d)
skip_prefixes = ["build/" + x.strip("/") + "/" for x in protect] + ["build/light/"]
moved = []
for dirpath, dirnames, filenames in os.walk(os.path.join(root, "build")):
    dirnames[:] = [d for d in dirnames if not (dirpath == os.path.join(root, "build") and d.startswith(".stale-"))]
    rel_dir = os.path.relpath(dirpath, root)
    for name in filenames:
        if not name.endswith(".log"):
            continue
        rel = rel_dir + "/" + name
        if rel in sent or rel_dir in ("build", "build/metrics"):
            continue
        if "/".join(rel.split("/")[:2]) not in tops or any(rel.startswith(s) for s in skip_prefixes):
            continue
        full = os.path.join(root, rel)
        if os.path.realpath(full) in held:
            continue
        dest = os.path.join(root, "build", ".stale-" + stamp, os.path.relpath(rel, "build"))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        os.replace(full, dest)
        moved.append(rel)
        d = os.path.join(root, rel_dir)  # remove run folders it emptied, up to the nearest folder the box sent a file in
        while os.path.relpath(d, root) not in holding:
            try:
                os.rmdir(d)
            except OSError:
                break
            d = os.path.dirname(d)
if moved:
    print(">> remote: copy-back moved %d stale log(s) an earlier run left beside this run's rows, into build/.stale-%s/" % (
        len(moved), stamp), file=sys.stderr)
    for rel in moved[:20]:
        print("   moved  " + rel, file=sys.stderr)
    if len(moved) > 20:
        print("   ... and %d more" % (len(moved) - 20), file=sys.stderr)
PY
exit 0
