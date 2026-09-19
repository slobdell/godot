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
    """One line naming the machine and commit, with a loud marker when the tree was dirty.

    A dirty run is NOT refused. Measuring while you work is the normal case, and a tool that rejected it would be
    worked around within a day. What is refused is the SILENCE: the gate belongs where a number gets promoted to a
    citable fact, not where it gets taken. So a dirty run says so in its own header and in its own json, and the rule
    that goes with it is one line:

        **a run with dirty = true may be acted on, and may not be quoted.**

    Quoting means a headline, a design document, anything the lead reads, or a row in
    _agents/streams/references/. All of those promise reproducibility, and a dirty tree cannot supply the commit that
    would deliver it. Re-run from a clean tree before it becomes a fact.
    """
    c = conditions or describe()
    if not c["dirty"]:
        return "%s at %s" % (c["machine"], c["commit"])
    return "%s at %s  **DIRTY TREE: this commit does not identify the run -- usable, NOT quotable**" % (
        c["machine"], c["commit"])
