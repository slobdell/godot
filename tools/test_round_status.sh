#!/usr/bin/env bash
# Known-answer tests for `round_status.sh`, the orchestrator's one screen.
#
# The remote half is rendered from a captured block (`--remote-from`), so the rendering -- which is where it
# can lie -- is driven without a build box. Its first live run found six slots held on a box configured for
# three, which is the kind of thing it exists to show.
set -uo pipefail
rs="$(cd "$(dirname "$0")" && pwd)/round_status.sh"
pass=0; fail=0
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }

cat > "$tmp/block" <<'B'
LOAD 15.70 11.74 10.30
CORES 12
MEMAVAIL_MB 8851
OWNER slot1 11:48:11 godot-scale: make --no-print-directory check
OWNER slot2 11:55:10 godot-metrics: make --no-print-directory check
PROCS godot-scale 8
PROCS godot-metrics 48
PROCS godot-feel 3
B
out=$(bash "$rs" --remote-from "$tmp/block" 2>&1)
grep -q 'load 15.70 11.74 10.30 on 12 cores, 8851 MB available' <<<"$out" && ok "renders load, cores and memory" || bad "renders load, cores and memory" "$out"
grep -q 'slot slot1 11:48:11 godot-scale' <<<"$out" && ok "renders who holds each slot" || bad "renders who holds each slot"
grep -qE 'godot-metrics +48 processes' <<<"$out" && ok "renders live processes per folder" || bad "renders live processes per folder" "$out"
# THE POINT of printing both -- but a QUEUED run also has work and no slot, and that is the healthy case.
# The first version called it "has work but holds NO SLOT", which read as an accusation aimed at two streams
# doing nothing wrong. Three states, told apart by the slot.sh ticket.
grep -q 'godot-feel has work, no slot and no ticket' <<<"$out" && ok "work with no slot AND no ticket is flagged as uncertain" \
	|| bad "work with no slot and no ticket is flagged" "$out"
grep -q 'an orphan, or a command run outside the slots' <<<"$out" && ok "and it is named as an uncertainty, not an accusation" \
	|| bad "named as an uncertainty" "$out"
grep -q 'godot-scale' <<<"$out" | grep -q 'no slot' && bad "a slot holder is not flagged" || ok "a slot holder is not flagged"

cat > "$tmp/queued" <<'B'
LOAD 1.00 1.00 1.00
CORES 12
MEMAVAIL_MB 9000
OWNER slot1 11:48:11 godot-scale: make --no-print-directory check
TICKET godot-nav
PROCS godot-scale 8
PROCS godot-nav 4
B
out=$(bash "$rs" --remote-from "$tmp/queued" 2>&1)
grep -q 'godot-nav is QUEUED' <<<"$out" && ok "a QUEUED run is named queued, not orphaned" || bad "a queued run is named queued" "$out"
grep -q 'godot-nav has work, no slot and no ticket' <<<"$out" && bad "a queued run is not called an orphan" || ok "a queued run is not called an orphan"

# An unreachable box must not render as a quiet one.
: > "$tmp/empty"
out=$(bash "$rs" --remote-from "$tmp/empty" 2>&1)
grep -q 'UNREACHABLE' <<<"$out" && ok "an empty block reads UNREACHABLE, not idle" || bad "an empty block reads UNREACHABLE" "$out"
grep -q 'Nothing below is known about the box' <<<"$out" && ok "and says the box is unknown" || bad "and says the box is unknown"

cat > "$tmp/idle" <<'B'
LOAD 0.10 0.20 0.30
CORES 12
MEMAVAIL_MB 11000
B
out=$(bash "$rs" --remote-from "$tmp/idle" 2>&1)
grep -q 'no slot is held' <<<"$out" && ok "a genuinely idle box says so" || bad "a genuinely idle box says so" "$out"
grep -q 'no processes in any' <<<"$out" && ok "and says no folder has work" || bad "and says no folder has work"

out=$(bash "$rs" --no-remote 2>&1)
grep -q 'skipped: --no-remote' <<<"$out" && ok "--no-remote says it skipped rather than printing nothing" || bad "--no-remote says it skipped"
grep -q '^== worktrees' <<<"$out" && ok "--no-remote still lists the worktrees" || bad "--no-remote still lists the worktrees"
grep -q '^== baselines' <<<"$out" && ok "--no-remote still lists the baselines" || bad "--no-remote still lists the baselines"
grep -qE '^  sim-baseline    glibc-' <<<"$out" && ok "renders the sim baseline line" || bad "renders the sim baseline line" "$out"
grep -qE '^  ai-scenarios    [0-9]+,[0-9]+,[0-9]+,[0-9]+  \(gated: [0-9]+,[0-9]+\)' <<<"$out" \
	&& ok "renders the ai-scenarios counts AND which two are gated" || bad "renders ai-scenarios counts" "$out"
grep -q 'this stream' <<<"$out" && bad "no placeholder text leaked" || ok "no placeholder text leaked"

# It must never write anything.
before=$(cd "$(dirname "$rs")/.." && git status --porcelain | sort | md5sum)
bash "$rs" --no-remote >/dev/null 2>&1
after=$(cd "$(dirname "$rs")/.." && git status --porcelain | sort | md5sum)
[ "$before" = "$after" ] && ok "read-only: the working tree is untouched" || bad "read-only: the working tree is untouched"

bash "$rs" --wat >/dev/null 2>&1; [ $? = 2 ] && ok "an unknown flag is refused" || bad "an unknown flag is refused"

printf '\nround-status: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
