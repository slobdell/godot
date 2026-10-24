#!/usr/bin/env bash
# Known answers for mk/native.mk's trig preload (round 39, N4): which machines get LD_PRELOAD=libtank_trig and the builders'
# sim-baseline key, and that the native library imports none of the five float trig functions it defines itself.
# TRIG_GLIBC stands in for getconf's version; the outer make's own LD_PRELOAD / SIM_BASELINE_KEY are cleared first.
set -u
here="$(cd "$(dirname "$0")" && pwd)"; root="$(dirname "$here")"
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/       /' | head -8; }
info() { env -u LD_PRELOAD -u SIM_BASELINE_KEY make -C "$root" --no-print-directory -s trig-info "$@" 2>&1; }

out=$(info TRIG_GLIBC=2.39)
[[ "$out" == *"older than 2.41"* && "$out" == *"LD_PRELOAD=$root/.tools/trig/libtank_trig-"*".so"* && "$out" == *"key glibc-2.43"* ]] \
	&& ok "glibc 2.39: the preload and the builders' key" || bad "2.39" "$out"
out=$(info TRIG_GLIBC=2.40.1)
[[ "$out" == *"LD_PRELOAD=$root/.tools/trig/"* ]] && ok "glibc 2.40.1: the preload (versions compare as versions)" || bad "2.40.1" "$out"
out=$(info TRIG_GLIBC=2.41)
[[ "$out" == *"LD_PRELOAD=none"* && "$out" == *"key glibc-2.41"* ]] && ok "glibc 2.41: libm is CORE-MATH, no preload" || bad "2.41" "$out"
out=$(info TRIG_GLIBC=2.43)
[[ "$out" == *"LD_PRELOAD=none"* && "$out" == *"key glibc-2.43"* ]] && ok "glibc 2.43 (the builders): nothing changes" || bad "2.43" "$out"
out=$(info TRIG_GLIBC=2.39 TRIG=system)
[[ "$out" == *"LD_PRELOAD=none"* && "$out" == *"key glibc-2.39"* ]] && ok "TRIG=system: this machine's own libm and key" || bad "system" "$out"

so="$root/native/bin/libtank_native.linux.x86_64.so"
if [ -e "$so" ] && command -v nm >/dev/null; then
	imported=$(nm -D --undefined-only "$so" | grep -E ' (atan2f|acosf|asinf|atanf|tanf)(@|$)')
	[ -z "$imported" ] && ok "libtank_native imports none of the five (its own, hidden)" || bad "native imports" "$imported"
else
	ok "libtank_native not built here: its import check skipped"
fi

printf '\ntrig: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
