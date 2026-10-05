#!/usr/bin/env bash
# The copy-back rsync and the copy-back manifest must skip the SAME files (tools/remote.sh; ship, round 18): a
# directory exclude that is not anchored skips every directory of that name at any depth while the manifest skips only
# build/<name>/*, and the verification then fails every run (19 garage-tour screenshots under .../desktop/, 2026-10-05).
set -u
rs="$(cd "$(dirname "$0")" && pwd)/remote.sh"
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/       /'; }
copy=$(grep -A2 'copy_log=$(rsync' "$rs" | grep -oE "\-\-exclude='[^']+'" | sed "s/--exclude='//; s/'$//")
[ -n "$copy" ] && ok "found the copy-back excludes" || bad "copy-back excludes not found"
for e in $copy; do
	case $e in
		/*/) grep -q "! -path 'build${e}\*'" "$rs" && ok "$e anchored, and the manifest skips build${e}*" || bad "$e: no matching manifest exclusion" ;;
		\*.*) grep -qF "! -name '$e'" "$rs" && ok "$e: the manifest skips it too" || bad "$e: no matching manifest exclusion" ;;
		*) bad "$e is a directory exclude that is not anchored (it matches at any depth)" ;;
	esac
done
printf '\nremote-excludes: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
