#!/bin/bash
# Runs the test suite. Plain `swift test` works with full Xcode installed;
# with Command Line Tools only, Swift Testing's framework and macro plugin
# must be pointed at explicitly, which this script does.
set -euo pipefail
cd "$(dirname "$0")/.."

DEV_DIR="$(xcode-select -p)"
if [ "$DEV_DIR" = "/Library/Developer/CommandLineTools" ]; then
    DEVFW="$DEV_DIR/Library/Developer/Frameworks"
    DEVLIB="$DEV_DIR/Library/Developer/usr/lib"
    PLUG="$DEV_DIR/usr/lib/swift/host/plugins/testing"
    exec swift test \
        -Xswiftc -F -Xswiftc "$DEVFW" \
        -Xswiftc -plugin-path -Xswiftc "$PLUG" \
        -Xlinker -F"$DEVFW" \
        -Xlinker -rpath -Xlinker "$DEVFW" \
        -Xlinker -rpath -Xlinker "$DEVLIB" \
        "$@"
fi
exec swift test "$@"
