#!/usr/bin/env bash
# The round-2 unit roster (art X4): the lead's approved Meshy concepts (review #1, assets/review/review.json) fitted
# into the per-unit slots unit.<id>.hull / .turret / .weapon (_agents/slot_contracts.md, rules' catalog v2).
# Sources live in assets/incoming/meshy/ (git-ignored); the task ids are in each manifest entry's source.
# Re-run after any pipeline change: make assets-roster
#
# How each unit splits (look with make assets-view IN=assets/incoming/meshy/<name>.glb SPLIT=1 FORWARD=…):
#   scout      caged dune buggy, faces +X: hull + the gun welded to its nose (no turret: a fixed mount)
#   ifv        round 15: a cut-down crash tender (ifv_r15_a), faces -X; regions, its side ramp dropped (below)
#   artillery  crane carrier, faces +Z: the mortar rack is the turret (it leans forward over the cab),
#              no separate barrel
#   lancer     transformer flatbed, faces -X: the turntable is the turret, the coil emitter the weapon
# Turrets and weapons keep their generated placement on the hull (--place-from); turrets move onto the pivot
# (--center); real barrels reach the gameplay muzzle (--stretch; the Lancer's coil emitter doesn't: see
# streams/archive/round2/art.md requests); every part wears the hull's textures (--textures-from: one texture set per unit).
set -euo pipefail
cd "$(dirname "$0")/../.."
THEME=roster
LICENSE="--license='Meshy Pro (paid plan): customer owns the generated output' --credit='Generated with Meshy'"
# Normal and ORM maps at 512 (albedo and emission stay 1024): they barely show at RTS distance and were half of each
# unit's web download (22.4 MB .pck with all five units at 1024).
COMMON="--tint=material_0 --tint-strength=0.2 --emission-energy=4 --texture-caps=normal_texture:512,roughness_texture:512,metallic_texture:512,ao_texture:512"

# Round 12 (fleet): `ONLY=burner tools/assets/build_roster.sh` rebuilds one unit (the others' sources need not be here).
ONLY="${ONLY:-}"

base_of() {  # review item → the download's base name: round-2 models were saved as <item>_t2, round 12's as <item>
	if [ -s "assets/incoming/meshy/$1_t2.glb" ]; then echo "$1_t2"; else echo "$1"; fi
}

source_of() {  # unit name → "--source=…" from the generate.py sidecar
	python3 - "$1" "$(base_of "$1")" <<'EOF'
import json, sys
d = json.load(open(f"assets/incoming/meshy/{sys.argv[2]}.json"))
print(f"--source='Meshy image-to-3D meshy-t2 task {d['task']['id']} from review item {sys.argv[1]} (concept {d['image_task']})'")
EOF
}

normalize() {  # model slot args
	local unit; unit="$(echo "$2" | cut -d. -f2)"
	[ -z "$ONLY" ] || [ "$ONLY" = "$unit" ] || return 0
	local model="assets/incoming/meshy/$(base_of "$1").glb"
	[ -s "$model" ] || { echo "missing $model (see assets/review/review.json for its task)"; exit 1; }
	make --no-print-directory assets-normalize IN="$model" SLOT="$2" THEME=$THEME \
		ARGS="$3 $COMMON $(source_of "$1") $LICENSE" 2>&1 \
		| grep -E "split into|note: (placed|turned|stripped|decimated)|size \(|triangles:|contract|CONTRACT|warning" || true
}

# Scout: fixed hood gun.
SCOUT="--split=regions --forward=+x --cannon-box=0.3,0.6,0.0,0.7,0.95,0.3"
normalize scout_b unit.scout.hull "$SCOUT --exclude=cannon_*"
normalize scout_b unit.scout.weapon "$SCOUT --include=cannon_* --place-from=unit.scout.hull --stretch --textures-from=unit.scout.hull"

# IFV (round 15, fleet F3): the lead's approved crash-tender wedge, ifv_r15_a (review page 2026-10-02 09:34 UTC),
# replacing round 2's garbage truck (ifv_b) so it no longer reads as the bus from behind. Faces -X. The tank heuristic
# took a roof plate for the gun and left the barrel in the hull, so regions (fractions of the oriented bounds: x
# across, y up, z from the nose at 0 to the tail at 1; `make assets-profile` slices). The lowered side troop ramp lies
# on the ground beside the body (across 0.0-0.28, low): dropped, or the truck would be fitted 0.71 wide instead of 0.49.
# No --center, as the burner: the turret turns about its own ring (the unit's turret_mount).
IFV="--split=regions --forward=-x --turret-box=0.50,0.80,0.18,0.82,1.0,0.42 --cannon-box=0.55,0.82,0.0,0.77,1.0,0.24 --drop-box=0.0,0.0,0.0,0.27,0.30,1.0"
normalize ifv_r15_a unit.ifv.hull "$IFV --exclude=turret_*,cannon_*,drop_*"
normalize ifv_r15_a unit.ifv.turret "$IFV --include=turret_* --place-from=unit.ifv.hull --textures-from=unit.ifv.hull"
normalize ifv_r15_a unit.ifv.weapon "$IFV --include=cannon_* --place-from=unit.ifv.hull --textures-from=unit.ifv.hull"

# Artillery: the mortar rack rotates; no barrel.
ARTY="--split=regions --forward=+z --turret-box=0.15,0.45,0.25,0.85,1.0,0.8"
normalize artillery_a unit.artillery.hull "$ARTY --exclude=turret_*"
normalize artillery_a unit.artillery.turret "$ARTY --include=turret_* --place-from=unit.artillery.hull --center --textures-from=unit.artillery.hull"

# Lancer: turntable + coil emitter.
LANCER="--split=regions --forward=-x --cannon-box=0.0,0.78,0.0,1.0,1.0,0.75 --turret-box=0.2,0.6,0.3,0.8,0.8,0.7"
normalize lancer_b unit.lancer.hull "$LANCER --exclude=turret_*,cannon_*"
normalize lancer_b unit.lancer.turret "$LANCER --include=turret_* --place-from=unit.lancer.hull --center --textures-from=unit.lancer.hull"
normalize lancer_b unit.lancer.weapon "$LANCER --include=cannon_* --place-from=unit.lancer.hull --shift-from=unit.lancer.turret --textures-from=unit.lancer.hull"

# Burner (round 12, fleet F1): the lead's approved fire engine, burner_r11_b (review page, 2026-09-24 17:27 UTC). Faces
# -X. The flamethrower head on its turntable pedestal is the turret; the nozzle is the weapon; the ladder rack, the
# pedestal column (the fixed turntable base) and the cab stay on the hull. Boxes are fractions of the oriented bounds
# (x across, y up, z from the plow at 0 to the tail at 1), authored from `make assets-profile` slices and looked at
# with the split turnaround (lesson 216: side AND end views).
BURNER="--split=regions --forward=-x --turret-box=0.3,0.768,0.48,0.7,1.0,0.66 --cannon-box=0.3,0.78,0.15,0.7,1.0,0.48"
normalize burner_r11_b unit.burner.hull "$BURNER --exclude=turret_*,cannon_*"
# No --center: the head is placed exactly as generated, so it turns about its own ring (the unit's turret_mount).
normalize burner_r11_b unit.burner.turret "$BURNER --include=turret_* --place-from=unit.burner.hull --textures-from=unit.burner.hull"
normalize burner_r11_b unit.burner.weapon "$BURNER --include=cannon_* --place-from=unit.burner.hull --textures-from=unit.burner.hull"
