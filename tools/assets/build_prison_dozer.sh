#!/usr/bin/env bash
# The prison_dozer theme's recipe: the art-direction north star (_agents/art_direction.md) generated with Meshy and
# split into the tank slots. Sources live in assets/incoming/meshy/ (git-ignored; regenerate with the commands in
# the manifest's source field). Re-run after any pipeline change: tools/assets/build_prison_dozer.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
model=assets/incoming/meshy/dozer_t2.glb
[ -s "$model" ] || { echo "missing $model (Meshy image-to-3D task 01a09ff4-4b17-76af-8ed1-4d7f2e8d7c9d)"; exit 1; }
meta="--source='Meshy image-to-3D meshy-t2 task 01a09ff4-4b17-76af-8ed1-4d7f2e8d7c9d from nano-banana-pro concept 01a09fec-d5c3-700a-bce1-3cdf54384292' --license='Meshy Pro (paid plan): customer owns the generated output' --credit='Generated with Meshy'"
# The model faces -X; one mesh of 282 islands, so --split=tank labels hull_/turret_/cannon_ islands.
# Team color tints the grimy texture only slightly (players will paint the whole vehicle in the garage; friend or
# foe is accent lights); the baked neon stays as generated.
normalize() {
	make --no-print-directory assets-normalize IN="$model" SLOT="$1" THEME=prison_dozer ARGS="--split=tank --forward=-x $2 $meta" 2>&1 \
		| grep -E "split into|note:|size \(|triangles:|contract|CONTRACT"
}
# The bus roof (1.6 m) is above the default deck, so turret and cannon ride on it (--deck-from); Meshy's emission map
# comes in at energy 1, too dim for the night arena.
normalize tank.hull "--exclude=turret_*,cannon_* --tint=material_0 --tint-strength=0.2 --emission-energy=4 --texture-caps=normal_texture:512,roughness_texture:512,metallic_texture:512"
# One texture set per unit (art X1): the turret and cannon ship untextured and wear the hull's materials, which
# cut the web download by two 1024² PBR sets. The hull keeps the generator's full detail (15k budget: the treads).
normalize tank.turret "--include=turret_* --scale-from=tank.hull --deck-from=tank.hull --tint=material_0 --tint-strength=0.2 --emission-energy=4 --textures-from=tank.hull"
normalize weapon.cannon "--include=cannon_* --attach-to=tank.turret --emission-energy=4 --textures-from=tank.hull"
