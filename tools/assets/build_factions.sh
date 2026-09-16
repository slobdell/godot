#!/usr/bin/env bash
# The round-3 faction vehicles (assets X4): the lead's approved concepts (review 2026-09-16, assets/review/review.json)
# fitted into the K4 slots unit.<faction>.<role>.hull/.turret/.weapon, one theme per faction
# (game/theme/factions/<faction>/generated). Sources: assets/incoming/meshy/<id>_t2.glb (git-ignored; task ids in each
# manifest entry). Re-run after a pipeline change: make assets-factions
#
# Per model: the forward axis read from `make assets-view IN=… SPLIT=1` (Meshy returns ~1 m models on arbitrary axes),
# and whether image-to-3D separated a turret:
#   split=tank  the heuristic found a turret (and gun) island: hull / turret / weapon
#   hull        the weapon is part of the body and should be: fixed-mount scouts, the hover units' built-in emitters,
#               the gang support trucks. Their turret and weapon slots stay empty (FactionArt shows the hull alone).
# Gallery only this round: no gameplay reads these (K4).
set -euo pipefail
cd "$(dirname "$0")/../.."
LICENSE="--license='Meshy Pro (paid plan): customer owns the generated output' --credit='Generated with Meshy'"
COMMON="--tint=material_0 --tint-strength=0.2 --emission-energy=4 --texture-caps=normal_texture:512,roughness_texture:512,metallic_texture:512,ao_texture:512"

source_of() {
	python3 - "$1" <<'PY'
import json, sys
d = json.load(open(f"assets/incoming/meshy/{sys.argv[1]}_t2.json"))
print(f"--source='Meshy image-to-3D meshy-t2 task {d['task']['id']} from review item {sys.argv[1]}'")
PY
}

normalize() {  # model slot theme args
	local model="assets/incoming/meshy/$1_t2.glb"
	[ -s "$model" ] || { echo "missing $model (tools/assets/model_batch.py builds approved concepts)"; exit 1; }
	make --no-print-directory assets-normalize IN="$model" SLOT="$2" THEME="$3" \
		ARGS="$4 $COMMON $(source_of "$1") $LICENSE" 2>&1 \
		| grep -E "split into|note: (placed|turned|stripped|decimated)|size \(|triangles:|contract|CONTRACT|warning" || true
}

unit() {  # id faction role forward split
	local id="$1" faction="$2" role="$3" forward="$4" split="$5"
	local theme="factions/$faction" base="unit.$faction.$role"
	echo "== $faction $role ($id, forward $forward, $split)"
	if [ "$split" = "tank" ]; then
		local args="--split=tank --forward=$forward"
		normalize "$id" "$base.hull" "$theme" "$args --exclude=turret_*,cannon_*"
		normalize "$id" "$base.turret" "$theme" "$args --include=turret_* --place-from=$base.hull --center --textures-from=$base.hull"
		normalize "$id" "$base.weapon" "$theme" "$args --include=cannon_* --place-from=$base.hull --shift-from=$base.turret --stretch --textures-from=$base.hull"
	else
		normalize "$id" "$base.hull" "$theme" "--forward=$forward"
	fi
}

# Road gangs: rusted but loved (game_design.md). Special = the resupply tanker (the lead's pick decides the role).
unit gangs_tank_a      gangs     tank      -x tank
unit gangs_scout_b     gangs     scout     +z hull
unit gangs_ifv_a       gangs     ifv       -x tank
unit gangs_artillery_b gangs     artillery +x tank
unit gangs_special_b   gangs     special   +x hull

# The Law: professional but neglected.
unit law_tank_a        law       tank      -x tank
unit law_scout_a       law       scout     -x hull
unit law_ifv_b         law       ifv       -x tank
unit law_artillery_a   law       artillery +x tank
unit law_special_b     law       special   +z tank

# The Syndicate: the ivory tower. Special = the Lancer laser (the lead's pick decides the role).
unit syndicate_tank_c      syndicate tank      -x tank
unit syndicate_scout_a     syndicate scout     -x hull
unit syndicate_ifv_b       syndicate ifv       +x tank
unit syndicate_artillery_b syndicate artillery -x hull
unit syndicate_special_b   syndicate special   +x hull

# The wreck husk every destroyed vehicle leaves (scaled per unit by the wreck effects).
normalize wreck_a prop.wreck arena_kit "--forward=+z"
