#!/usr/bin/env bash
# compile_shaders.sh — Compile GLSL fragment shaders to .qsb for SiM
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

QSB="/usr/lib/qt6/bin/qsb"

shaders=(
    "SiMSoul"
    "SiMCore"
    "crystallize"
    "SiMSanctum"
)

compile() {
    local src="$1"
    local out="${src%.frag}.frag.qsb"
    echo "[shaders] Compiling $src → $out"
    "$QSB" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$out" "$src"
}

# Vertex shaders
echo "[shaders] Compiling default.vert → default.vert.qsb"
"$QSB" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o default.vert.qsb default.vert

# Fragment shaders
for s in "${shaders[@]}"; do
    compile "$s.frag"
done

echo "[shaders] ✓ All shaders compiled."
