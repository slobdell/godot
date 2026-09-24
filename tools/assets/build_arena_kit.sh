#!/usr/bin/env bash
# The gladiator arena kit (art X5/X6): the lead's approved Meshy concepts from review #1 fitted into prop slots and
# dressing candidates, theme `arena_kit`. Sources in assets/incoming/meshy/ (git-ignored; task ids in the manifest).
# Re-run after any pipeline change: make assets-arena-kit
#   container_a  armored container stack       → prop.crate (stretched to the 4.5 × 3 × 4.5 m cover box)
#   barrier_a    concrete blast barrier (4 ×)  → prop.wall  (tiled along the wall's 18 m, neon face outward)
#   scrap_a      crushed car wrecks            → kit.scrap_heap (for a scrap obstacle type, pending rules' C5)
#   stands_a     container-and-scaffold stands → kit.stands (perimeter modules, crowds added in-game)
#   gate_a       perimeter wall with a gate    → kit.gate
#   tower_a      floodlight tower              → kit.floodlight_tower
set -euo pipefail
cd "$(dirname "$0")/../.."
THEME=arena_kit
LICENSE="--license='Meshy Pro (paid plan): customer owns the generated output' --credit='Generated with Meshy'"
# Every map at 512: the kit is seen from RTS distance, and at 1024 it added ~20 MB to the web download (40 MB .pck).
KIT_CAPS="--texture-caps=albedo_texture:512,normal_texture:512,roughness_texture:512,metallic_texture:512,ao_texture:512,emission_texture:512"

source_of() {
	python3 - "$1" <<'PY'
import json, sys
d = json.load(open(f"assets/incoming/meshy/{sys.argv[1]}_t2.json"))
print(f"--source='Meshy image-to-3D meshy-t2 task {d['task']['id']} from review item {sys.argv[1]} (concept {d['image_task']})'")
PY
}

normalize() {  # model slot args
	local model="assets/incoming/meshy/$1_t2.glb"
	[ -s "$model" ] || { echo "missing $model (see assets/review/review.json for its task)"; exit 1; }
	make --no-print-directory assets-normalize IN="$model" SLOT="$2" THEME=$THEME \
		ARGS="$3 --emission-energy=4 $KIT_CAPS $(source_of "$1") $LICENSE" 2>&1 \
		| grep -E "note: (tiled|decimated)|size \(|triangles:|contract|CONTRACT|warning" || true
}

normalize container_a prop.crate "--forward=+z"
normalize barrier_a prop.wall "--forward=+x --repeat=4x1x1"
# normalize scrap_a kit.scrap_heap "--forward=+z"   # not shipped until rules add a scrap obstacle type (C5): 4 MB unused
normalize stands_a kit.stands "--forward=${STANDS_FORWARD:-+z}"
normalize gate_a kit.gate "--forward=+z"
normalize tower_a kit.floodlight_tower "--forward=+z"

# The Syndicate broadcast airship (round 11, the lead's approved airship_r11_m). Fitted by LENGTH, not "contain":
# `arena.airship`'s guide.z IS the design length, and the whole size is forced by the lead's camera (see
# SyndicateAdAirship.LENGTH). Its textures stay at 1024, not the kit's 512 -- it is ONE instance and the biggest thing
# on screen when it passes (1446 px of 1920), where the kit's props are small and many.
AIRSHIP="assets/incoming/meshy/airship_m.glb"
if [ -s "$AIRSHIP" ]; then
	make --no-print-directory assets-normalize IN="$AIRSHIP" SLOT=arena.airship THEME=$THEME \
		ARGS="--forward=-x --emission-energy=3 \
			--texture-caps=albedo_texture:1024,normal_texture:1024,roughness_texture:512,metallic_texture:512 \
			--source='Meshy image-to-3D meshy-t2 from review item airship_r11_m' $LICENSE" 2>&1 \
		| grep -E "note: (tiled|decimated)|size \(|triangles:|contract|CONTRACT|warning" || true
else
	echo "skipping arena.airship: $AIRSHIP is missing (git-ignored; regenerate with"
	echo "  tools/assets/generate.py --provider meshy --slot unit.tank --review-item airship_r11_m \\"
	echo "      --smart-topology --polycount 30000 --name meshy/airship_m )"
fi
