#!/usr/bin/env python3
"""The engine-message gate on a check target's OWN LOG (ship, round 17; the orchestrator's ask, found by the lead).

    engine_log_gate.py <target> <log> [--out <file>]

WHY. A `"\\u0000"` literal in game/theme/fx/weapon_fx.gd made the engine print

    Unicode parsing error, some characters were replaced with � (U+FFFD): Unexpected NUL character

every time the script was parsed: 38-46 times in EVERY check log on main from guns' interim merge (f93f3cb4) to
f5b2226c, and every one of those checks read `23 targets, all passed, ALL JUDGED`. The suite's engine-message gate
(tests/run_tests.gd's ErrorCollector, with tests/baselines/engine_expected.txt) never saw it, for two reasons:

  * the message does not go through the engine's error path: it is printed by `print_error()`, which reaches a
    Logger's `_log_message(msg, true)`, and the collector implements only `_log_error`;
  * it is printed when a script is PARSED -- when a test file is `load()`ed, before its first test -- and the runner
    calls `errors.take()` before every test, which drops whatever was logged before it.

And the smokes (net-smoke, match-smoke, web-smoke, ...) are scanned by nothing at all: each greps its own markers.
So this reads every line a target printed, whatever printed it.

WHAT FAILS (a line, after stripping leading whitespace):
  * `Unicode parsing error` anywhere, in EVERY target (no runner can see it);
  * `SCRIPT ERROR:`, `ERROR:`, `WARNING:`, `USER ERROR:`, `USER WARNING:` at the start of a line, in every target
    EXCEPT the ones that already judge those lines themselves (SELF_JUDGED: the test runner with its allowlist and
    `expect_warning()`, lint with its baseline, the scenario runner, the shell tests that print stub engine output);
  * unless the line contains a pattern of tests/baselines/engine_expected.txt (every target), or a pattern
    tests/baselines/engine_log_allowed.txt scopes to this target (each with its reason).

Exit 0 when nothing failed; 1 otherwise, with the lines QUOTED (counted, first 8 distinct), and the same written to
--out (check_verdict.sh puts the first on the target's FAIL row).
"""
import fnmatch
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Overridable for tools/test_engine_log_gate.sh only.
EXPECTED = os.environ.get("ENGINE_LOG_EXPECTED", os.path.join(ROOT, "tests/baselines/engine_expected.txt"))
ALLOWED = os.environ.get("ENGINE_LOG_ALLOWED", os.path.join(ROOT, "tests/baselines/engine_log_allowed.txt"))

# Targets whose own runner already fails on (and allows) the prefixed engine lines: their logs legitimately carry
# the messages a test declared with expect_warning(), or lint's baseline, or a shell test's stub output.
SELF_JUDGED = ["test", "test-shard-*", "lint", "ai-scenarios-check", "remote-guard-test"]

ALWAYS = re.compile(r"Unicode parsing error")
PREFIXED = re.compile(r"^(SCRIPT ERROR|USER ERROR|USER WARNING|ERROR|WARNING): ")


def patterns(path, target=None):
    """engine_expected.txt: one substring per line. engine_log_allowed.txt: `<target-glob> | <substring>`."""
    out = []
    if not os.path.exists(path):
        return out
    for raw in open(path, encoding="utf-8", errors="replace"):
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if target is None:
            out.append(line)
            continue
        if "|" not in line:
            continue
        glob, sub = (part.strip() for part in line.split("|", 1))
        if sub and fnmatch.fnmatch(target, glob):
            out.append(sub)
    return out


def matches(text, pattern):
    if "*" in pattern or "?" in pattern:
        return fnmatch.fnmatch(text, "*" + pattern + "*")
    return pattern in text


def scan(target, lines):
    allowed = [p for p in patterns(EXPECTED) if p] + patterns(ALLOWED, target)
    self_judged = any(fnmatch.fnmatch(target, glob) for glob in SELF_JUDGED)
    bad = {}
    order = []
    for raw in lines:
        text = raw.rstrip("\r\n").replace("\x00", "").strip()
        # The make recipe echoes its own commands (`grep -E 'NET_CHECK|ERROR' ...`): they never start with a shape.
        hit = ALWAYS.search(text) or (not self_judged and PREFIXED.match(text))
        if not hit or any(matches(text, p) for p in allowed):
            continue
        if text not in bad:
            order.append(text)
            bad[text] = 0
        bad[text] += 1
    return [(text, bad[text]) for text in order]


def main(argv):
    out = None
    if "--out" in argv:
        i = argv.index("--out")
        out = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    if len(argv) != 2:
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        return 2
    target, log = argv
    with open(log, encoding="utf-8", errors="replace") as f:
        found = scan(target, f)
    if out:
        os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
        with open(out, "w", encoding="utf-8") as f:
            for text, n in found:
                f.write('engine message x%d: "%s"\n' % (n, text[:200]))
    if not found:
        return 0
    total = sum(n for _, n in found)
    print(">> engine-log-gate: %s FAILED: %d engine message line(s), %d distinct, not allowed "
          "(tests/baselines/engine_expected.txt, engine_log_allowed.txt):" % (target, total, len(found)))
    for text, n in found[:8]:
        print('>> engine-log-gate:   x%d "%s"' % (n, text[:240]))
    if len(found) > 8:
        print(">> engine-log-gate:   ... and %d more distinct" % (len(found) - 8))
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
