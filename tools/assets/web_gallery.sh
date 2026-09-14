#!/usr/bin/env bash
# Export the asset gallery as its own web build and render it in headless Chrome (WebGL 2), to prove
# generated models, emissive materials, and the texture import policy work in a browser.
# Release web templates refuse a scene path on the command line, so this copies the project (sources
# only) to build/web-gallery-project with the gallery as its main scene and exports that copy.
#   tools/assets/web_gallery.sh <godot> <theme> <port> <screenshot.png> [url query extras, e.g. "&only=kit.b&night"]
set -euo pipefail
godot=$(realpath "$1"); theme=$2; port=$3; shot=$(realpath -m "$4"); extra=${5:-}
root=$(cd "$(dirname "$0")/../.." && pwd)
work="$root/build/web-gallery-project"
out="$root/build/web-gallery"

mkdir -p "$work" "$out" "$root/build/screenshots"
touch "$root/build/.gdignore"
rsync -a --delete --exclude .godot --exclude build --exclude .tools --exclude node_modules --exclude assets/incoming \
	--exclude .git "$root/" "$work/"
sed -i 's|^run/main_scene=.*|run/main_scene="res://assets/pipeline/gallery.tscn"|' "$work/project.godot"
(cd "$work" && "$godot" --headless --path . --import >/dev/null 2>&1 || true)
(cd "$work" && "$godot" --headless --path . --export-release "Web" "$out/index.html" >/dev/null 2>&1)

python3 "$root/tools/serve_web.py" "$out" "$port" 127.0.0.1 >/dev/null 2>&1 & server=$!
trap 'kill $server 2>/dev/null; rm -rf "$out"' EXIT  # the export is ~39 MB; keep only the screenshot
node "$root/tools/web_smoke/smoke.mjs" "http://127.0.0.1:$port/?theme=$theme$extra" "$shot" 4 ASSET_GALLERY_READY
