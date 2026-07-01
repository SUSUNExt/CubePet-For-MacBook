#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS_DIR="$ROOT_DIR/Assets"
MASTER_PNG="$ASSETS_DIR/AppIcon.png"
OUTPUT_ICNS="$ASSETS_DIR/MacBookPet.icns"
TEMP_DIR="$(mktemp -d)"
ICONSET_DIR="$TEMP_DIR/MacBookPet.iconset"

trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$ASSETS_DIR" "$ICONSET_DIR"
swift "$ROOT_DIR/script/generate_app_icon.swift" "$MASTER_PNG"

make_icon() {
  local pixels="$1"
  local filename="$2"
  sips -z "$pixels" "$pixels" "$MASTER_PNG" --out "$ICONSET_DIR/$filename" >/dev/null
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"
