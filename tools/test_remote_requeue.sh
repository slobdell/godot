#!/usr/bin/env bash
# Known-answer tests for tools/remote.sh's Spot-preemption re-queue (round 45, native stretch).
#
# The property: on the GCP builder, a run whose ssh (or copy-back) dies with 255 while gcloud says the VM is no longer RUNNING is
# re-run verbatim ONCE after the VM is started again; if the builder's verdict line had already arrived, only build/ is copied
# back and that verdict is the exit. A 255 on a RUNNING VM, on builder0, a second preemption or REMOTE_REQUEUE=0 re-runs nothing.
# Fake ssh / rsync / gcloud on PATH, a scratch checkout holding remote.sh; no network, a few seconds.
set -uo pipefail
tools="$(cd "$(dirname "$0")" && pwd)"
pass=0; fail=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }

# The scratch checkout: remote.sh refuses anything without a Makefile and tools/remote.sh (and no guard: it says UNGUARDED).
repo="$tmp/godot-fake"; mkdir -p "$repo/tools" "$tmp/bin" "$tmp/state"
cp "$tools/remote.sh" "$repo/tools/"; echo 'all:' > "$repo/Makefile"
git -C "$repo" init -q && git -C "$repo" add -A && git -C "$repo" -c user.name=t -c user.email=t@t commit -qm t

# ssh: the run (`bash -s -- <make args>`) follows $S/run_plan, one word a call: ok | verdict-then-ok:<N> | preempt | blip
cat > "$tmp/bin/ssh" <<'EOF'
#!/usr/bin/env bash
S=$FAKE_STATE
case "$*" in *"bash -s -- "*) ;; *) exit 0 ;; esac   # mkdir, `true`: the box answers
cat > /dev/null
n=$(( $(cat "$S/runs" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$S/runs"
step=$(sed -n "${n}p" "$S/run_plan"); [ -n "$step" ] || step=$(tail -1 "$S/run_plan")
case "$step" in
	ok) echo ">> builder: make fake exited 0" >&2; exit 0 ;;
	verdict-then-ok:*) echo ">> builder: make fake exited ${step#*:}" >&2; exit "${step#*:}" ;;
	preempt) echo "half a run" >&2; echo TERMINATED > "$S/vm"; exit 255 ;;
	blip) echo "half a run" >&2; exit 255 ;;
esac
EOF
# rsync: the copy-back (a source on the box's build/) follows $S/copy_plan: ok | preempt
cat > "$tmp/bin/rsync" <<'EOF'
#!/usr/bin/env bash
S=$FAKE_STATE
for a in "$@"; do case "$a" in *:~/*/build/) is_copy=1 ;; esac; done
[ -n "${is_copy:-}" ] || exit 0
n=$(( $(cat "$S/copies" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$S/copies"
step=$(sed -n "${n}p" "$S/copy_plan"); [ -n "$step" ] || step=ok
[ "$step" = preempt ] && { echo TERMINATED > "$S/vm"; echo "rsync: connection unexpectedly closed" >&2; exit 255; }
exit 0
EOF
cat > "$tmp/bin/gcloud" <<'EOF'
#!/usr/bin/env bash
S=$FAKE_STATE
case "$*" in *" describe "*) cat "$S/vm" ;; *" start "*) echo RUNNING > "$S/vm"; echo start >> "$S/starts" ;; esac
EOF
chmod +x "$tmp/bin/"*

run() {   # run <host> <run plan> <copy plan> [env...]: remote.sh fake in the scratch checkout; sets $st $out
	local host=$1 rp=$2 cp=$3; shift 3
	rm -rf "$tmp/state"; mkdir -p "$tmp/state"; echo RUNNING > "$tmp/state/vm"
	tr ' ' '\n' <<<"$rp" > "$tmp/state/run_plan"; tr ' ' '\n' <<<"$cp" > "$tmp/state/copy_plan"
	out=$(cd "$repo" && env PATH="$tmp/bin:$PATH" FAKE_STATE="$tmp/state" REMOTE_HOST="$host" REMOTE_VERIFY=0 \
		REMOTE_REQUEUE_SSH_SLEEP=0 "$@" timeout 60 bash tools/remote.sh fake 2>&1)
	st=$?
	runs=$(cat "$tmp/state/runs" 2>/dev/null || echo 0); copies=$(cat "$tmp/state/copies" 2>/dev/null || echo 0)
	starts=$( { cat "$tmp/state/starts" 2>/dev/null || true; } | wc -l)
}

# ---- 1. preempted mid-run, no verdict: started again, re-run verbatim once, its verdict is the exit --------------------
run slobdell@builder2 "preempt ok" "ok"
[ "$st" = 0 ] && [ "$runs" = 2 ] && [ "$starts" = 1 ] && ok "a preempted run (no verdict yet) is re-run once after the VM starts: exit 0, 2 runs, 1 start" \
	|| bad "a preempted run is re-run once" "exit $st runs $runs starts $starts; $out"
grep -q '>> remote: slobdell@builder2 was PREEMPTED (TERMINATED) during the run' <<<"$out" && grep -q 're-running verbatim, once: make fake' <<<"$out" \
	&& ok "it says why, in one line, and what it re-runs" || bad "it says why" "$out"

# ---- 2. the verdict had arrived, then the copy-back lost the box: copy-back only, that verdict is the exit -----------
run slobdell@builder2 "verdict-then-ok:3" "preempt ok"
[ "$st" = 3 ] && [ "$runs" = 1 ] && [ "$copies" = 2 ] && ok "verdict in, copy-back preempted: the run is NOT repeated, build/ copied back, exit 3 (its verdict)" \
	|| bad "verdict in, copy-back preempted: copy-back only" "exit $st runs $runs copies $copies; $out"
grep -q 'copying build/ back only, not re-running it' <<<"$out" && ok "and says it copied back only" || bad "and says it copied back only" "$out"

# ---- 3. a 255 on a RUNNING VM is not a preemption: nothing re-run -------------------------------------------------
run slobdell@builder2 "blip" "ok"
[ "$st" = 255 ] && [ "$runs" = 1 ] && [ "$starts" = 0 ] && ! grep -q PREEMPTED <<<"$out" \
	&& ok "a 255 while the VM is RUNNING re-runs nothing (exit 255, 1 run)" || bad "a 255 on a RUNNING VM re-runs nothing" "exit $st runs $runs; $out"

# ---- 4. preempted twice: one re-queue only ---------------------------------------------------------------------
run slobdell@builder2 "preempt preempt ok" "ok"
[ "$runs" = 2 ] && [ "$st" = 255 ] && grep -q 'not re-queued twice' <<<"$out" \
	&& ok "a second preemption is not re-queued (2 runs, exit 255, says so)" || bad "a second preemption is not re-queued" "exit $st runs $runs; $out"

# ---- 5. builder0 (not GCP) and REMOTE_REQUEUE=0: never ---------------------------------------------------------
run slobdell@builder0 "preempt ok" "ok"
[ "$runs" = 1 ] && [ "$st" = 255 ] && [ "$starts" = 0 ] && ok "builder0: a 255 is never re-queued" || bad "builder0: never re-queued" "exit $st runs $runs; $out"
run slobdell@builder2 "preempt ok" "ok" REMOTE_REQUEUE=0
[ "$runs" = 1 ] && [ "$st" = 255 ] && ok "REMOTE_REQUEUE=0 turns it off" || bad "REMOTE_REQUEUE=0 turns it off" "exit $st runs $runs; $out"

# ---- 6. a plain green run is untouched, and its streams still come through ------------------------------------------
run slobdell@builder2 "ok" "ok"
[ "$st" = 0 ] && [ "$runs" = 1 ] && grep -q '>> builder: make fake exited 0' <<<"$out" && grep -q '>> remote: make fake exited 0' <<<"$out" \
	&& ok "a green run: one run, its builder line and the wrapper's verdict line both printed" || bad "a green run is untouched" "exit $st; $out"

echo "remote-requeue: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
