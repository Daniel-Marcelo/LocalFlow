#!/bin/bash
# Fetches whisper.cpp at the pinned tag into Vendor/whisper.cpp.
# v1.7.2 is the last whisper.cpp release that ships a SwiftPM Package.swift
# (with Metal enabled); later releases require building an xcframework with
# full Xcode, which we deliberately avoid so the project builds with just
# the Command Line Tools.
set -euo pipefail

WHISPER_TAG="v1.7.2"
VENDOR_DIR="$(cd "$(dirname "$0")/.." && pwd)/Vendor"
DEST="$VENDOR_DIR/whisper.cpp"

if [ -d "$DEST" ]; then
    current=$(git -C "$DEST" describe --tags --exact-match 2>/dev/null || true)
    if [ "$current" = "$WHISPER_TAG" ]; then
        echo "whisper.cpp $WHISPER_TAG already present at $DEST"
        exit 0
    fi
    echo "Vendor/whisper.cpp exists but is not $WHISPER_TAG — refetching"
    rm -rf "$DEST"
fi

mkdir -p "$VENDOR_DIR"
git clone --quiet --depth 1 --branch "$WHISPER_TAG" \
    https://github.com/ggml-org/whisper.cpp "$DEST"
echo "Fetched whisper.cpp $WHISPER_TAG into $DEST"
