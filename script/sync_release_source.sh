#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/UploadGithub/CubePet-For-MacBook"
MODE="${1:---check}"

if [[ ! -d "$RELEASE_DIR/.git" ]]; then
  echo "Release repository is missing: $RELEASE_DIR" >&2
  exit 2
fi

sync_tree() {
  local relative_path="$1"
  /usr/bin/rsync -a \
    --exclude '.DS_Store' \
    --exclude '.build' \
    --exclude 'dist' \
    --exclude '.swiftpm' \
    "$ROOT_DIR/$relative_path/" "$RELEASE_DIR/$relative_path/"
}

check_tree() {
  local relative_path="$1"
  /usr/bin/diff -qr \
    --exclude '.DS_Store' \
    --exclude '.build' \
    --exclude 'dist' \
    --exclude '.swiftpm' \
    "$ROOT_DIR/$relative_path" "$RELEASE_DIR/$relative_path"
}

case "$MODE" in
  --sync)
    for path in Assets Sources Tests script; do
      sync_tree "$path"
    done
    /usr/bin/rsync -a "$ROOT_DIR/Package.swift" "$RELEASE_DIR/Package.swift"
    /usr/bin/rsync -a "$ROOT_DIR/README.md" "$RELEASE_DIR/README.md"
    ;;
  --check)
    ;;
  *)
    echo "usage: $0 [--check|--sync]" >&2
    exit 2
    ;;
esac

for path in Assets Sources Tests script; do
  check_tree "$path"
done
/usr/bin/diff -q "$ROOT_DIR/Package.swift" "$RELEASE_DIR/Package.swift"
/usr/bin/diff -q "$ROOT_DIR/README.md" "$RELEASE_DIR/README.md"

echo "Release source is synchronized."
