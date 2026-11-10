#!/bin/bash
# Runs the pinned SwiftLint, downloading its prebuilt universal binary on first use, so neither CI nor
# contributors have to build it from source. Arguments are passed through to `swiftlint`.

set -euo pipefail

VERSION="0.57.1"
SHA256="aa2e0f8f8272545e5593ebedd7872db51132fcec4ead76d001bbe17af69c7ae5"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/.tools/swiftlint-$VERSION"
BINARY="$DIR/swiftlint"

if [ ! -x "$BINARY" ]; then
  echo "⬇️  Downloading SwiftLint $VERSION..." >&2
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  curl -fsSL --retry 3 -o "$TMP/swiftlint.zip" \
    "https://github.com/realm/SwiftLint/releases/download/$VERSION/portable_swiftlint.zip"
  echo "$SHA256  $TMP/swiftlint.zip" | shasum -a 256 -c - > /dev/null \
    || { echo "❌ SwiftLint download doesn't match its pinned checksum." >&2; exit 1; }
  unzip -q -o "$TMP/swiftlint.zip" swiftlint -d "$TMP"
  mkdir -p "$DIR"
  mv "$TMP/swiftlint" "$BINARY"
fi

exec "$BINARY" "$@"
