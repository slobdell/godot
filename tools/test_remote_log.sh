#!/usr/bin/env bash
# Known-answer tests for tools/remote_log.sh: the builder-side copy of a remote run, verdict included, survives its reader.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
pass=0; fail=0
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }

# A run whose reader (the laptop wrapper's ssh) goes away at once: everything after still reaches the file.
( source "$here/remote_log.sh"
  remote_log_begin "$tmp/logs" godot-camera check
  echo "first line"; echo "to stderr" >&2
  sleep 0.3
  for i in 1 2 3; do echo "after the reader left $i"; done
  remote_log_end 0 check
  echo "$REMOTE_LOG" > "$tmp/which" ) 2>/dev/null | head -c 0
sleep 0.5
log=$(cat "$tmp/which" 2>/dev/null)
[ -n "$log" ] && [ -f "$log" ] && ok "the log exists on the builder" || bad "the log exists on the builder" "$log"
grep -q "after the reader left 3" "$log" && ok "output after the reader died is kept" || bad "output after the reader died is kept" "$(cat "$log")"
grep -q "to stderr" "$log" && ok "stderr is kept too" || bad "stderr is kept too"
grep -q "^>> builder: make check exited 0 " "$log" && ok "the verdict line is in the log" || bad "the verdict line is in the log" "$(tail -2 "$log")"
case "$log" in "$tmp/logs/godot-camera-check-"*.log) ok "named folder-target-stamp";; *) bad "named folder-target-stamp" "$log";; esac

# A live reader still sees everything, unchanged.
out=$( ( source "$here/remote_log.sh"; remote_log_begin "$tmp/logs2" godot-native "test FILTER=a|b"; echo hello; remote_log_end 3 test ) 2>&1 )
grep -q "^hello$" <<<"$out" && ok "a live reader sees the output" || bad "a live reader sees the output" "$out"
grep -q ">> builder: make test exited 3" <<<"$out" && ok "a live reader sees the verdict" || bad "a live reader sees the verdict" "$out"
ls "$tmp/logs2"/godot-native-test_FILTER=a_b-*.log >/dev/null 2>&1 && ok "unsafe characters in the target are replaced" \
	|| bad "unsafe characters in the target are replaced" "$(ls "$tmp/logs2")"

# Pruning keeps the newest N.
mkdir -p "$tmp/many"; for i in $(seq 1 7); do touch -d "-$i min" "$tmp/many/f$i.log"; done
( source "$here/remote_log.sh"; remote_log_prune "$tmp/many" 3 )
[ "$(ls "$tmp/many" | wc -l)" = 3 ] && [ -f "$tmp/many/f1.log" ] && [ ! -f "$tmp/many/f7.log" ] \
	&& ok "prune keeps the newest 3" || bad "prune keeps the newest 3" "$(ls "$tmp/many")"

# remote.sh calls it (both ends), and keeps the logs outside the synced folder.
grep -q 'remote_log_begin ~/\$root/remote-logs' "$here/remote.sh" && ok "remote.sh begins the builder log outside the folder" \
	|| bad "remote.sh begins the builder log outside the folder"
grep -q 'remote_log_end \\\$make_status' "$here/remote.sh" && ok "remote.sh writes the verdict line" \
	|| bad "remote.sh writes the verdict line"

echo "remote_log: $pass passed, $fail failed"
[ "$fail" = 0 ]
