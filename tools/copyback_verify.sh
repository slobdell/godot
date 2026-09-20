#!/usr/bin/env bash
# Verify that what arrived from the build box is byte-for-byte what it wrote.
#
#     copyback_verify.sh <root> <manifest>      # sha256 lines, as `sha256sum` writes them
#
# WHY (2026-09-20). nav's `p7-pit.jsonl` came back from builder0 with one byte changed in 273,578 lines --
# `0x78` `x` flipped to `0xf8`, breaking a JSON key at line 143,873 of a 101 MB log. One bit. It could have
# happened in builder0's memory, on its disk, in the transfer, or on this laptop, and the file alone cannot
# say which. **This narrows it to "the transfer, or not", which is the only part we can cheaply learn.**
#
# The flip was caught because it landed in a KEY NAME and the reader refused the file. In a digit it would
# have read as a perfectly good coordinate and quietly moved a number. So the value of this check is not the
# files it rejects -- it is that the next flip gets located instead of being argued about.
#
# A missing manifest is reported, never treated as a pass: "nothing to check" and "everything checked out"
# must not print the same way (the round's recurring defect).
set -uo pipefail

root=${1:-}; manifest=${2:-}
[ -n "$root" ] && [ -n "$manifest" ] || { echo "usage: copyback_verify.sh <root> <manifest>" >&2; exit 2; }

if [ ! -r "$manifest" ]; then
	echo ">> copy-back: NOT VERIFIED -- no manifest at $manifest." >&2
	echo ">>   The box did not write one (an older checkout there, or the run died before it could)." >&2
	exit 3
fi

total=0; bad=0; missing=0
while read -r want file; do
	[ -n "${file:-}" ] || continue
	case "$want" in ''|*[!0-9a-f]*) continue ;; esac      # not a sha256 line
	total=$((total + 1))
	if [ ! -f "$root/$file" ]; then
		echo ">> copy-back: MISSING  $file" >&2
		missing=$((missing + 1))
		continue
	fi
	got=$(sha256sum "$root/$file" 2>/dev/null | cut -d' ' -f1)
	if [ "$got" != "$want" ]; then
		echo ">> copy-back: CORRUPT  $file" >&2
		echo ">>     the box wrote $want" >&2
		echo ">>     this machine has $got" >&2
		bad=$((bad + 1))
	fi
done < "$manifest"

if [ "$total" -eq 0 ]; then
	# An empty manifest passing would be `lint` over zero files all over again.
	echo ">> copy-back: NOT VERIFIED -- the manifest lists no files." >&2
	exit 3
fi

if [ "$bad" -gt 0 ] || [ "$missing" -gt 0 ]; then
	echo ">> copy-back: FAILED -- $bad corrupt, $missing missing, of $total files." >&2
	echo ">>   A CORRUPT file means the bytes changed between the box and here: that is the transfer, or" >&2
	echo ">>   this machine. Re-copy before you quote anything out of build/, and say so if it recurs." >&2
	exit 5
fi
echo ">> remote: copy-back verified, $total files, sha256"
