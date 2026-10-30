#!/usr/bin/env bash
# Round 46 (native): whether a remote run should run `make native-fresh` before its targets. Prints "yes" or "no".
# A fresh light folder has no native library, and native-fresh is only a prerequisite of a few play / replay targets, so
# `make remote LIGHT=1 T=control-timing` on 7189e3ff3 (builder3, 2026-10-30) timed the GDScript fallbacks: the 30-unit right
# click read 6.86 ms (ratio 180.6, "FAIL") where the C++ path reads 2.03 ms (56.3). native-fresh is one `find` when the
# library is current. Not for check (native-for-check builds it), the native* / bootstrap targets themselves, NATIVE=off,
# or REMOTE_NATIVE_FRESH=0.
# usage: tools/remote_native_first.sh <make target> [more targets / VAR=value ...]
[ "${REMOTE_NATIVE_FRESH:-1}" != 0 ] || { echo no; exit 0; }
first=""
for a in "$@"; do
	case "$a" in
	NATIVE=off) echo no; exit 0 ;;
	*=*|-*) ;;
	*) [ -n "$first" ] || first=$a ;;
	esac
done
case "$first" in
"" | check | check-* | native | native-* | bootstrap | clean*) echo no ;;
*) echo yes ;;
esac
