"""What a measurement was taken ON, so a number carries its own conditions.

Two runs are only comparable when the machine and the commit match, and this project has repeatedly compared a
builder0 run at one commit against a laptop run at another -- the laptop is ~2.75x slower, and a commit apart can be
a different game. Every attempt to fix that by being careful has failed, twice in one day, with a self-catch each
time. So the fix is not vigilance: **the artefact carries its conditions and the reader cannot help but see them.**

Same principle as naming the arena in a faction-matrix header. A number whose configuration is implicit will be
promoted to a property of the thing measured, by omission rather than by anyone deciding to.
"""
import os
import platform
import subprocess


def describe():
    """{'machine', 'commit', 'dirty'} -- the conditions a run happened under."""
    def git(*args):
        try:
            return subprocess.run(("git",) + args, capture_output=True, text=True, timeout=10).stdout.strip()
        except Exception:
            return ""
    # tools/remote.sh excludes .git/ from its rsync, so on builder0 -- where almost every measurement is taken --
    # there is no repository to ask. That is the machine whose identity matters most, and the thing that strips it is
    # the thing that moves the code there. So prefer an env var the runner can export, and fall back to git locally.
    return {"machine": os.environ.get("TANK_SQUAD_MACHINE") or platform.node() or "unknown",
            "commit": os.environ.get("TANK_SQUAD_COMMIT") or git("rev-parse", "--short", "HEAD") or "unknown",
            # A dirty tree means the commit does NOT identify what ran, which is the case worth shouting about.
            "dirty": os.environ.get("TANK_SQUAD_DIRTY") == "1" or bool(git("status", "--porcelain"))}


def header(conditions=None):
    """One line naming the machine and commit, with a loud marker when the tree was dirty."""
    c = conditions or describe()
    return "%s at %s%s" % (c["machine"], c["commit"], "  **DIRTY TREE: the commit does not identify this run**" if c["dirty"] else "")
