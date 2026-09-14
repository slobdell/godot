#!/usr/bin/env bash
# Fetch the CC0 source models behind the kitbash theme into assets/incoming/ (git-ignored, ~6 MB).
# Licenses and pages: assets/CREDITS.md. Used by `make assets-kitbash`.
set -euo pipefail
cd "$(dirname "$0")/../.."
dest=assets/incoming
mkdir -p "$dest/quaternius_tanks" "$dest/quaternius_props"

fetch() {  # fetch <url> <file>: skip files we already have
	[ -s "$2" ] && return 0
	curl -sfL --retry 3 -o "$2.part" "$1" && mv "$2.part" "$2"
	echo "fetched $2 ($(du -h "$2" | cut -f1))"
}

# Quaternius Animated Tank Pack (CC0), via Poly Pizza's CDN.
fetch https://static.poly.pizza/58c387b2-636f-49dc-a900-13b0852717d6.glb "$dest/quaternius_tanks/58c387b2-636f-49dc-a900-13b0852717d6.glb"

# Quaternius Toon Shooter + Cyberpunk Game Kit props (CC0): name → Poly Pizza id.
while read -r name id; do
	fetch "https://static.poly.pizza/$id.glb" "$dest/quaternius_props/$name.glb"
done <<'EOF'
container_small 2e1f581e-5f9d-42ff-9ef9-600b1cfde0a6
barrier_large 1533a896-a4db-4ca5-aa04-51dec1da46ad
street_light 9a8aac3e-d1ee-4860-b294-edca62ef50be
streetlight 7576487c-00cd-43cd-93a7-d2c217fa8c25
broken_car ab665646-c115-492f-a72f-1120399a1dd5
shipping_container e56c8efb-940f-4150-9bf8-d468c0165116
cyberpunk_signs 44299e58-2793-47f6-8245-fba288fd2bfd
EOF
