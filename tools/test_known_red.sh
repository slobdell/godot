#!/usr/bin/env bash
# Known-answer tests for tools/known_red.py (`make known-red`; check-all's KNOWN RED labels). Ship, round 18, stretch c.
set -u
kr="$(cd "$(dirname "$0")" && pwd)/known_red.py"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/       /' | head -12; }
printf '# comment\nweb-host-smoke | f5b2226c, builder0, 2026-10-04 | the handshake; the wasm trap\n' > "$tmp/list"

printf 'check\tPASS\t1200\nweb-host-smoke\tFAIL\t66\nscreenshot\tPASS\t40\n' > "$tmp/v"
out=$(python3 "$kr" list "$tmp/list" "$tmp/v"); rc=$?
[ $rc = 0 ] && grep -q 'web-host-smoke *still red' <<<"$out" && ok "a listed red that is red: still red, exit 0" || bad "still red" "$out"
grep -q 'the handshake; the wasm trap' <<<"$out" && grep -q 'since f5b2226c' <<<"$out" && ok "prints why and since" || bad "why and since" "$out"
printf 'check\tPASS\t1200\nweb-host-smoke\tPASS\t66\n' > "$tmp/v"
out=$(python3 "$kr" list "$tmp/list" "$tmp/v"); grep -q 'PASSED in the last check-all: remove its line' <<<"$out" \
	&& ok "a listed red that passed: says remove its line" || bad "passed" "$out"
printf 'check\tPASS\t1200\nweb-host-smoke\tFAIL\t66\ngarage-tour\tFAIL\t300\n' > "$tmp/v"
out=$(python3 "$kr" list "$tmp/list" "$tmp/v"); rc=$?
[ $rc = 1 ] && grep -q 'garage-tour *NEW RED: not on the list' <<<"$out" && ok "an unlisted red: NEW RED, exit 1" || bad "new red" "$out"
out=$(python3 "$kr" list "$tmp/list" "$tmp/nowhere"); grep -q 'none here' <<<"$out" && grep -q 'not in the last check-all' <<<"$out" \
	&& ok "no verdicts file: says none, never 'still red'" || bad "no verdicts" "$out"
out=$(python3 "$kr" label "$tmp/list" web-host-smoke); [ "$out" = " (KNOWN RED since f5b2226c: tests/baselines/known_red.txt)" ] \
	&& ok "label: a listed target gets the KNOWN RED tag" || bad "label listed" "$out"
out=$(python3 "$kr" label "$tmp/list" garage-tour); [ -z "$out" ] && ok "label: an unlisted target gets nothing" || bad "label unlisted" "$out"
out=$(python3 "$kr" list "$(dirname "$kr")/../tests/baselines/known_red.txt"); grep -q 'web-host-smoke' <<<"$out" \
	&& ok "the real list parses and names web-host-smoke" || bad "real list" "$out"

printf 'HOLE end-frame-measure | x, 2026-10-04 | a dead run reads NOT JUDGED\n' >> "$tmp/list"
out=$(python3 "$kr" list "$tmp/list" "$tmp/v"); grep -q 'known holes' <<<"$out" && grep -q 'end-frame-measure *HOLE since x' <<<"$out" \
	&& ok "a HOLE line is printed as a known hole" || bad "hole" "$out"
grep -q 'end-frame-measure *NEW RED\|end-frame-measure *still red' <<<"$out" && bad "a HOLE is not a red target" || ok "a HOLE is not read as a red target"
out=$(python3 "$kr" holes "$tmp/list"); grep -q '>> check-all: KNOWN HOLE end-frame-measure (since x): a dead run reads NOT JUDGED' <<<"$out" \
	&& ok "holes: one check-all line per hole" || bad "holes line" "$out"
printf '\nknown-red: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
