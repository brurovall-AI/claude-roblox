#!/usr/bin/env bash
# Full build: type-check, bake the map, build the place file.
#   tools/build.sh            -> build/Ironhaven.rbxl (+ assets/Map.rbxm)
#   tools/build.sh --render   -> also renders preview images to build/preview
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== Luau type check"
node tools/check/check.mjs --quiet

echo "== Bake map"
lune run tools/bake/bake.luau

echo "== Build place"
mkdir -p build
rojo build default.project.json -o build/Ironhaven.rbxl
cp build/Ironhaven.rbxl Ironhaven.rbxl
echo "Built Ironhaven.rbxl ($(du -h Ironhaven.rbxl | cut -f1))"

if [[ "${1:-}" == "--render" ]]; then
  echo "== Render previews"
  (cd tools/render && cargo build --release -q)
  tools/render/target/release/ironhaven-render build/preview/dump.json tools/render/cameras.json build/preview "${2:-}"
fi
