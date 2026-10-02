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
# Gallery only this round, and 15 vehicles at the roster's 1024 albedo would be ~100 MB in the repo: every map is 512
# here (assets X6). Raise the albedo when a faction becomes playable and shows up in the garage close-ups.
COMMON="--tint=material_0 --tint-strength=0.2 --emission-energy=4 --texture-caps=albedo_texture:512,emission_texture:512,normal_texture:512,roughness_texture:512,metallic_texture:512,ao_texture:512"

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

# Round 15 (fleet): `ONLY=law_ifv tools/assets/build_factions.sh` rebuilds one unit (<faction>_<role>; the others'
# sources need not be here, and the wreck is skipped).
ONLY="${ONLY:-}"

unit() {  # id faction role forward split
	local id="$1" faction="$2" role="$3" forward="$4" split="$5"
	[ -z "$ONLY" ] || [ "$ONLY" = "${faction}_${role}" ] || return 0
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
unit law_artillery_a   law       artillery +x tank
unit law_special_b     law       special   +z tank

# Law's IFV (round 15, fleet F3): the lead's approved tracked police APC, law_ifv_r15_a (review page 2026-10-02 09:34 UTC),
# replacing law_ifv_b (the 6x6 MRAP that read as the 8x8 Assault Gun). Faces -X. The tank heuristic took a roof cable
# for the gun, so regions (fractions: x across, y up, z nose 0 to tail 1; `make assets-profile`): the remote weapon
# station's base is the turret, its gun reaching forward the weapon. --center puts the base on the SIMULATED pivot
# (law_ifv's turret_mount, unchanged from round 11) and --shift-from carries the gun with it: under the station as
# modelled the pivot threw the muzzle 2.5 m past the nose.
if [ -z "$ONLY" ] || [ "$ONLY" = "law_ifv" ]; then
	echo "== law ifv (law_ifv_r15_a, forward -x, regions)"
	LAW_IFV="--split=regions --forward=-x --turret-box=0.30,0.75,0.36,0.65,1.0,0.55 --cannon-box=0.30,0.75,0.08,0.65,1.0,0.36"
	normalize law_ifv_r15_a unit.law.ifv.hull factions/law "$LAW_IFV --exclude=turret_*,cannon_*"
	normalize law_ifv_r15_a unit.law.ifv.turret factions/law "$LAW_IFV --include=turret_* --place-from=unit.law.ifv.hull --center --textures-from=unit.law.ifv.hull"
	normalize law_ifv_r15_a unit.law.ifv.weapon factions/law "$LAW_IFV --include=cannon_* --place-from=unit.law.ifv.hull --shift-from=unit.law.ifv.turret --textures-from=unit.law.ifv.hull"
fi

# The Syndicate: the ivory tower. Special = the Lancer laser (the lead's pick decides the role).
unit syndicate_tank_c      syndicate tank      -x tank
unit syndicate_scout_a     syndicate scout     -x hull
unit syndicate_ifv_b       syndicate ifv       +x tank
unit syndicate_artillery_b syndicate artillery -x hull
unit syndicate_special_b   syndicate special   +x hull

# The wreck husk every destroyed vehicle leaves (scaled per unit by the wreck effects).
[ -n "$ONLY" ] || normalize wreck_a prop.wreck arena_kit "--forward=+z"
