#!/usr/bin/env bash
# The kitbash theme's recipe: fetch the CC0 sources, then normalize each into its slot with the
# options that were judged right in the gallery. Re-run after any pipeline change so every generated
# model picks it up (`make assets-kitbash`). Licenses: assets/CREDITS.md.
set -euo pipefail
cd "$(dirname "$0")/../.."
tools/assets/fetch_kitbash.sh

tank=assets/incoming/quaternius_tanks/58c387b2-636f-49dc-a900-13b0852717d6.glb
props=assets/incoming/quaternius_props
cc0="--license='CC0 1.0 (Public Domain)'"
tanks="--source='https://poly.pizza/bundle/Animated-Tank-Pack-0tfvbeAJkU (static.poly.pizza/58c387b2-636f-49dc-a900-13b0852717d6.glb)' --credit='Quaternius, Animated Tank Pack' $cc0"
shooter="https://poly.pizza/bundle/Toon-Shooter-Game-Kit-qraiSXoAru"
cyber="https://poly.pizza/bundle/Cyberpunk-Game-Kit-Hkfxa8K8zF"

normalize() {  # normalize <input> <slot> <pipeline args>
	make --no-print-directory assets-normalize IN="$1" SLOT="$2" THEME=kitbash ARGS="$3" 2>&1 | grep -E "note:|contract|CONTRACT"
}

# --palette merges flat-colored materials into one draw call (tint/emissive materials stay separate).
# The pack's tank faces -X; the turret and gun are separate meshes, so each slot selects its part and the
# turret reuses the hull's scale to stay in proportion.
normalize "$tank" tank.hull "--forward=-x --exclude=tank_turret,tank_gun --tint=Main --palette $tanks"
normalize "$tank" tank.turret "--forward=-x --include=tank_turret --scale-from=tank.hull --tint=Main,Main_Dark $tanks"
normalize "$tank" weapon.cannon "--forward=-x --include=tank_gun $tanks"
normalize "$props/container_small.glb" prop.crate \
	"--palette --source='$shooter (Container Small, static.poly.pizza/2e1f581e-5f9d-42ff-9ef9-600b1cfde0a6.glb)' --credit='Quaternius, Toon Shooter Game Kit' $cc0"
# Four containers in a row read as solid cover; barrier segments looked like a see-through fence.
normalize "$props/shipping_container.glb" prop.wall \
	"--repeat=4x1x1 --palette --source='$shooter (Shipping Container, static.poly.pizza/e56c8efb-940f-4150-9bf8-d468c0165116.glb)' --credit='Quaternius, Toon Shooter Game Kit' $cc0"
normalize "$props/street_light.glb" kit.light_pole \
	"--emissive=Light:4 --source='$shooter (Street Light, static.poly.pizza/9a8aac3e-d1ee-4860-b294-edca62ef50be.glb)' --credit='Quaternius, Toon Shooter Game Kit' $cc0"
# The signs face -Z in the source.
normalize "$props/cyberpunk_signs.glb" kit.billboard \
	"--forward=-z --palette --emissive=Texture_Signs:2.5 --source='$cyber (Cyberpunk Signs, static.poly.pizza/44299e58-2793-47f6-8245-fba288fd2bfd.glb)' --credit='Quaternius, Cyberpunk Game Kit' $cc0"
