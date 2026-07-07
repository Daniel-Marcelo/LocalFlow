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

# Generates a self-contained Metal shader source: the raw ggml-metal.metal
# #includes ggml-common.h, which the runtime Metal compiler can't resolve, so
# the header is inlined. ggml JIT-compiles this file at startup (it must be
# named exactly "ggml-metal.metal"); the Makefile copies it into the app
# bundle's Resources, and CLI runs point GGML_METAL_PATH_RESOURCES at it.
METAL_RES_DIR="$VENDOR_DIR/metal-resources"
generate_merged_metal() {
    local ggml_src="$DEST/ggml/src"
    mkdir -p "$METAL_RES_DIR"
    sed -e '/#include "ggml-common.h"/r '"$ggml_src"'/ggml-common.h' \
        -e '/#include "ggml-common.h"/d' \
        "$ggml_src/ggml-metal.metal" > "$METAL_RES_DIR/ggml-metal.metal"
    echo "Generated self-contained Metal source at $METAL_RES_DIR/ggml-metal.metal"
}

if [ -d "$DEST" ]; then
    current=$(git -C "$DEST" describe --tags --exact-match 2>/dev/null || true)
    if [ "$current" = "$WHISPER_TAG" ]; then
        echo "whisper.cpp $WHISPER_TAG already present at $DEST"
        [ -f "$METAL_RES_DIR/ggml-metal.metal" ] || generate_merged_metal
        exit 0
    fi
    echo "Vendor/whisper.cpp exists but is not $WHISPER_TAG — refetching"
    rm -rf "$DEST"
fi

mkdir -p "$VENDOR_DIR"
git clone --quiet --depth 1 --branch "$WHISPER_TAG" \
    https://github.com/ggml-org/whisper.cpp "$DEST"
echo "Fetched whisper.cpp $WHISPER_TAG into $DEST"
generate_merged_metal
