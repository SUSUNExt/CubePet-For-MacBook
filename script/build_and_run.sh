#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="MacBookPet"
DISPLAY_NAME="CubePet"
BUNDLE_ID="com.susunext.MacBookPet"
APP_VERSION="0.8.0"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON="$ROOT_DIR/Assets/MacBookPet.icns"
FROG_PET_IMAGE="$ROOT_DIR/Assets/FrogPet.png"
FROG_LARGE_MOUTH_IMAGE="$ROOT_DIR/Assets/FrogPetMouthLarge.png"
CAT_PET_IMAGE="$ROOT_DIR/Assets/CatPetFaceless.png"
CAT_LARGE_MOUTH_IMAGE="$ROOT_DIR/Assets/CatPetMouthLarge.png"
CAT_GRAY_PET_IMAGE="$ROOT_DIR/Assets/CatPetGrayFaceless.png"
CAT_GRAY_LARGE_MOUTH_IMAGE="$ROOT_DIR/Assets/CatPetGrayMouthLarge.png"
CAT_CALICO_PET_IMAGE="$ROOT_DIR/Assets/CatPetCalicoFaceless.png"
CAT_CALICO_LARGE_MOUTH_IMAGE="$ROOT_DIR/Assets/CatPetCalicoMouthLarge.png"
CAT_BLACK_PET_IMAGE="$ROOT_DIR/Assets/CatPetBlackFaceless.png"
CAT_BLACK_LARGE_MOUTH_IMAGE="$ROOT_DIR/Assets/CatPetBlackMouthLarge.png"
CAT_SIAMESE_PET_IMAGE="$ROOT_DIR/Assets/CatPetSiameseFaceless.png"
CAT_SIAMESE_MOUTH_IMAGE="$ROOT_DIR/Assets/CatPetSiameseMouthUnique.png"

BUILD_CONFIGURATION="debug"
if [[ "$MODE" == "--release-app" || "$MODE" == "release-app" ]]; then
  BUILD_CONFIGURATION="release"
fi

# Keep local builds independent from an unlicensed full Xcode installation.
# Callers can still override this explicitly when they need another toolchain.
if [[ -z "${DEVELOPER_DIR:-}" && -d "/Library/Developer/CommandLineTools" ]]; then
  export DEVELOPER_DIR="/Library/Developer/CommandLineTools"
fi

# The currently selected Command Line Tools can expose a newer default SDK
# whose Swift module version does not match its compiler. Prefer the installed
# 15.4 SDK for this macOS 14+ app when no SDK has been selected explicitly.
COMPATIBLE_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
if [[ -z "${SDKROOT:-}" && -d "$COMPATIBLE_SDK" ]]; then
  export SDKROOT="$COMPATIBLE_SDK"
fi

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/clang-module-cache}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-$ROOT_DIR/.build/swiftpm-module-cache}"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_MODULECACHE_OVERRIDE"

if [[ "$MODE" != "--release-app" && "$MODE" != "release-app" ]]; then
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi

swift build -c "$BUILD_CONFIGURATION"
BUILD_BINARY="$(swift build -c "$BUILD_CONFIGURATION" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$APP_ICON" "$APP_RESOURCES/MacBookPet.icns"
cp "$FROG_PET_IMAGE" "$APP_RESOURCES/FrogPet.png"
cp "$FROG_LARGE_MOUTH_IMAGE" "$APP_RESOURCES/FrogPetMouthLarge.png"
cp "$CAT_PET_IMAGE" "$APP_RESOURCES/CatPet.png"
cp "$CAT_LARGE_MOUTH_IMAGE" "$APP_RESOURCES/CatPetMouthLarge.png"
cp "$CAT_GRAY_PET_IMAGE" "$APP_RESOURCES/CatPetGrayFaceless.png"
cp "$CAT_GRAY_LARGE_MOUTH_IMAGE" "$APP_RESOURCES/CatPetGrayMouthLarge.png"
cp "$CAT_CALICO_PET_IMAGE" "$APP_RESOURCES/CatPetCalicoFaceless.png"
cp "$CAT_CALICO_LARGE_MOUTH_IMAGE" "$APP_RESOURCES/CatPetCalicoMouthLarge.png"
cp "$CAT_BLACK_PET_IMAGE" "$APP_RESOURCES/CatPetBlackFaceless.png"
cp "$CAT_BLACK_LARGE_MOUTH_IMAGE" "$APP_RESOURCES/CatPetBlackMouthLarge.png"
cp "$CAT_SIAMESE_PET_IMAGE" "$APP_RESOURCES/CatPetSiameseFaceless.png"
cp "$CAT_SIAMESE_MOUTH_IMAGE" "$APP_RESOURCES/CatPetSiameseMouthUnique.png"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_VERSION</string>
  <key>CFBundleIconFile</key>
  <string>MacBookPet.icns</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSInputMonitoringUsageDescription</key>
  <string>MacBookPet uses input monitoring to release the desktop pet immediately when you stop dragging it.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>MacBookPet checks whether Music is playing so the pet can react to your music.</string>
  <key>UTExportedTypeDeclarations</key>
  <array>
    <dict>
      <key>UTTypeIdentifier</key>
      <string>com.susunext.macbookpet.food</string>
      <key>UTTypeConformsTo</key>
      <array>
        <string>public.data</string>
      </array>
      <key>UTTypeDescription</key>
      <string>CubePet Food</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key>
        <array>
          <string>mbpetfood</string>
        </array>
      </dict>
    </dict>
  </array>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --release-app|release-app)
    echo "$APP_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--release-app]" >&2
    exit 2
    ;;
esac
