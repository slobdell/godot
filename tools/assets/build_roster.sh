#!/usr/bin/env bash
# The round-2 unit roster (art X4): the lead's approved Meshy concepts (review #1, assets/review/review.json) fitted
# into the per-unit slots unit.<id>.hull / .turret / .weapon (_agents/slot_contracts.md, rules' catalog v2).
# Sources live in assets/incoming/meshy/ (git-ignored); the task ids are in each manifest entry's source.
# Re-run after any pipeline change: make assets-roster
#
# How each unit splits (look with make assets-view IN=assets/incoming/meshy/<name>.glb SPLIT=1 FORWARD=…):
#   scout      caged dune buggy, faces +X: hull + the gun welded to its nose (no turret: a fixed mount)
#   ifv        armored garbage truck, faces +Z: the tank heuristic finds its turret and 30 mm gun
#   artillery  crane carrier, faces +Z: the mortar rack is the turret (it leans forward over the cab),
#              no separate barrel
#   lancer     transformer flatbed, faces -X: the turntable is the turret, the coil emitter the weapon
# Turrets and weapons keep their generated placement on the hull (--place-from); turrets move onto the pivot
# (--center); real barrels reach the gameplay muzzle (--stretch; the Lancer's coil emitter doesn't: see
# streams/art.md requests); every part wears the hull's textures (--textures-from: one texture set per unit).
set -euo pipefail
cd "$(dirname "$0")/../.."
THEME=roster
LICENSE="--license='Meshy Pro (paid plan): customer owns the generated output' --credit='Generated with Meshy'"
COMMON="--tint=material_0 --tint-strength=0.2 --emission-energy=4"

source_of() {  # unit name → "--source=…" from the generate.py sidecar
	python3 - "$1" <<'EOF'
import json, sys
d = json.load(open(f"assets/incoming/meshy/{sys.argv[1]}_t2.json"))
print(f"--source='Meshy image-to-3D meshy-t2 task {d['task']['id']} from review item {sys.argv[1]} (concept {d['image_task']})'")
EOF
}

normalize() {  # model slot args
	local model="assets/incoming/meshy/$1_t2.glb"
	[ -s "$model" ] || { echo "missing $model (see assets/review/review.json for its task)"; exit 1; }
	make --no-print-directory assets-normalize IN="$model" SLOT="$2" THEME=$THEME \
		ARGS="$3 $COMMON $(source_of "$1") $LICENSE" 2>&1 \
		| grep -E "split into|note: (placed|turned|stripped|decimated)|size \(|triangles:|contract|CONTRACT|warning" || true
}

# Scout: fixed hood gun.
SCOUT="--split=regions --forward=+x --cannon-box=0.3,0.6,0.0,0.7,0.95,0.3"
normalize scout_b unit.scout.hull "$SCOUT --exclude=cannon_*"
normalize scout_b unit.scout.weapon "$SCOUT --include=cannon_* --place-from=unit.scout.hull --stretch --textures-from=unit.scout.hull"

# IFV: turret + 30 mm autocannon.
IFV="--split=tank --forward=+z"
normalize ifv_b unit.ifv.hull "$IFV --exclude=turret_*,cannon_*"
normalize ifv_b unit.ifv.turret "$IFV --include=turret_* --place-from=unit.ifv.hull --center --textures-from=unit.ifv.hull"
normalize ifv_b unit.ifv.weapon "$IFV --include=cannon_* --place-from=unit.ifv.hull --shift-from=unit.ifv.turret --stretch --textures-from=unit.ifv.hull"

# Artillery: the mortar rack rotates; no barrel.
ARTY="--split=regions --forward=+z --turret-box=0.15,0.45,0.25,0.85,1.0,0.8"
normalize artillery_a unit.artillery.hull "$ARTY --exclude=turret_*"
normalize artillery_a unit.artillery.turret "$ARTY --include=turret_* --place-from=unit.artillery.hull --center --textures-from=unit.artillery.hull"

# Lancer: turntable + coil emitter.
LANCER="--split=regions --forward=-x --cannon-box=0.0,0.78,0.0,1.0,1.0,0.75 --turret-box=0.2,0.6,0.3,0.8,0.8,0.7"
normalize lancer_b unit.lancer.hull "$LANCER --exclude=turret_*,cannon_*"
normalize lancer_b unit.lancer.turret "$LANCER --include=turret_* --place-from=unit.lancer.hull --center --textures-from=unit.lancer.hull"
normalize lancer_b unit.lancer.weapon "$LANCER --include=cannon_* --place-from=unit.lancer.hull --shift-from=unit.lancer.turret --textures-from=unit.lancer.hull"
