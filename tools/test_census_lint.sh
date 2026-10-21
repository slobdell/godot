#!/usr/bin/env bash
# Known answers for tools/census_lint.py (round 36, N5: a counter named in a bar must appear in its series' printed line).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
pass=0 fail=0

# A tree: Movement counts three things; its series (a census script) prints route_arms(), which reaches `seen` directly and
# `deep` through a report it calls; `lost` is printed by nothing.
tree() {
	local d=$1
	mkdir -p "$d/game/ai" "$d/tests/traffic" "$d/_agents/streams/archive"
	cat > "$d/game/ai/movement.gd" <<'EOF'
static var seen := 0
static var deep := 0
static var lost := 0
static var _private := 0
static var never_counted := 0

static func route_arms() -> Dictionary:
	return {"seen": seen, "more": deeper()}

static func deeper() -> Dictionary:
	return {"deep": deep}

func drive() -> void:
	seen += 1
	deep += 1
	lost += 1
	_private += 1
EOF
	for f in manoeuvre manoeuvre_census traffic; do : > "$d/game/ai/$f.gd"; done
	echo 'print(JSON.stringify(Movement.route_arms()))' > "$d/tests/traffic/jam_census.gd"
	echo 'A bar reads the census.' > "$d/_agents/workstreams.md"
}
run() { # name, want exit, repo, allowed (python dict literal)
	local name=$1 want=$2 repo=$3 allowed=$4
	local out; out=$(python3 -I - "$here/census_lint.py" "$repo" "$allowed" 2>&1 <<-'EOF'
	import importlib.util, sys, ast
	spec = importlib.util.spec_from_file_location("census_lint", sys.argv[1]); m = importlib.util.module_from_spec(spec)
	spec.loader.exec_module(m); m.ALLOWED = ast.literal_eval(sys.argv[3]); sys.argv = [sys.argv[1], sys.argv[2]]; m.main()
	EOF
	); local got=$?
	if [ "$got" = "$want" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $name: exit $got, want $want:"; echo "$out" | tail -4; fi
	last=$out
}

tree "$tmp/a"
run "an unprinted counter fails" 1 "$tmp/a" '{}'
echo "$last" | grep -q 'Movement.lost is on no series line' || { fail=$((fail + 1)); echo "FAIL the failure names Movement.lost"; }
echo "$last" | grep -qE 'Movement.(seen|deep) is on no' && { fail=$((fail + 1)); echo "FAIL a printed counter (direct or through a report) flagged"; }
echo "$last" | grep -qE '_private|never_counted' && { fail=$((fail + 1)); echo "FAIL a private or never-incremented var counted"; }
run "an allowed gap passes" 0 "$tmp/a" '{"Movement.lost": "x: why"}'
run "a stale allowance (the counter is printed) fails" 1 "$tmp/a" '{"Movement.lost": "x", "Movement.deep": "x"}'
run "an allowance for no counter fails" 1 "$tmp/a" '{"Movement.lost": "x", "Movement.gone": "x"}'
echo 'Bar Z: `lost` falls 10 %.' > "$tmp/a/_agents/streams/manoeuvre.md"
run "an allowed gap named in a bar fails" 1 "$tmp/a" '{"Movement.lost": "x: why"}'
rm "$tmp/a/_agents/streams/manoeuvre.md"
echo 'Bar Z (archived): `lost` falls.' > "$tmp/a/_agents/streams/archive/old.md"
run "an archived bar does not count" 0 "$tmp/a" '{"Movement.lost": "x: why"}'
echo 'var n := Movement.lost' > "$tmp/a/tests/traffic/lost_stage.gd"
run "a stage reading it directly prints it (and the allowance is now stale)" 1 "$tmp/a" '{"Movement.lost": "x"}'
run "and with no allowance it passes" 0 "$tmp/a" '{}'
repo=$(dirname "$here")
python3 -I "$here/census_lint.py" "$repo" > "$tmp/repo.txt" 2>&1 && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL this repo:"; grep FAIL "$tmp/repo.txt"; }

echo "census lint known answers: $pass passed, $fail failed"
[ "$fail" = 0 ]
