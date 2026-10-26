#!/usr/bin/env bash
# Verify that what arrived from the build box is byte-for-byte what it wrote.
#
#     copyback_verify.sh <root> <manifest> [src]      # sha256 lines, as `sha256sum` writes them
#
# [src] (round 39, the orchestrator's flank_s5.mp4): an rsync source (`host:~/dir/`, or a local path) for <root>. A file
# that fails is re-copied from it ONCE with --checksum, and the whole manifest checked again before anything is called
# corrupt. The copy-back's own rsync decides by size and mtime, so a local file whose bytes differ but whose size and mtime
# match the box's is skipped by every plain re-copy, and the verifier flags it run after run (build/flank_s5.mp4: a plain
# `rsync -a` did nothing, `rsync -a --checksum` fixed it). The re-copy is announced; it never hides a first-pass mismatch.
# RSYNC_RSH carries the caller's ssh options.
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
[ -n "$root" ] && [ -n "$manifest" ] || { echo "usage: copyback_verify.sh <root> <manifest> [src]" >&2; exit 2; }

if [ ! -r "$manifest" ]; then
	echo ">> copy-back: NOT VERIFIED -- no manifest at $manifest." >&2
	echo ">>   The box did not write one (an older checkout there, or the run died before it could)." >&2
	exit 3
fi

src=${3:-}
# Round 41 (N1): a remote source written `host:~/dir/` is made home-relative (`host:dir/`). With --files-from, rsync 3.4's
# sender takes the `~` literally and fails with change_dir "/home/<user>/~/dir/" (exit 12 on the laptop's side; manoeuvre,
# builder2, 2026-10-25), so the re-copy that was meant to fix a mismatch never ran. A remote path is relative to the
# login's home already, so dropping `~/` names the same folder on every rsync version.
case "$src" in *':~/'*) src="${src%%':~/'*}:${src#*':~/'}" ;; esac
failed=$(mktemp); trap 'rm -f "$failed"' EXIT
check() {  # one pass over the manifest; the paths that failed go to $failed
	total=0; bad=0; missing=0; : > "$failed"
	while read -r want file; do
		[ -n "${file:-}" ] || continue
		case "$want" in ''|*[!0-9a-f]*) continue ;; esac      # not a sha256 line
		total=$((total + 1))
		if [ ! -f "$root/$file" ]; then
			echo ">> copy-back: MISSING  $file" >&2
			printf '%s\n' "$file" >> "$failed"
			missing=$((missing + 1))
			continue
		fi
		got=$(sha256sum "$root/$file" 2>/dev/null | cut -d' ' -f1)
		if [ "$got" != "$want" ]; then
			echo ">> copy-back: CORRUPT  $file" >&2
			echo ">>     the box wrote $want" >&2
			echo ">>     this machine has $got" >&2
			bad=$((bad + 1))
			printf '%s\n' "$file" >> "$failed"
		fi
	done < "$manifest"
}
check
if [ -n "$src" ] && [ -s "$failed" ] && [ "$total" -gt 0 ]; then
	n=$(wc -l < "$failed")
	echo ">> copy-back: $n file(s) failed; re-copying them with --checksum (a same-size, same-mtime file is skipped by the plain copy) and checking again" >&2
	rsync -a --checksum --files-from="$failed" "$src" "$root/" >&2 || echo ">> copy-back: the --checksum re-copy exited $?" >&2
	check
	[ "$bad" -eq 0 ] && [ "$missing" -eq 0 ] && echo ">> copy-back: the --checksum re-copy fixed all $n" >&2
fi

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
