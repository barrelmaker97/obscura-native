#!/bin/bash
# Dev helper - runs swift commands with Xcode's Swift toolchain
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

SWIFT="xcrun swift"
LIBSIGNAL_PATH="$ROOT/vendored/libsignal/target/release"
LIBSIGNAL_SWIFT_SOURCE="$ROOT/vendored/libsignal/swift"
LIBSIGNAL_SWIFT_PACKAGE="$ROOT/vendored/LibSignalClient"

if [ ! -f "$LIBSIGNAL_SWIFT_SOURCE/Package.swift" ]; then
  echo "error: libsignal v0.40.0 is not checked out at vendored/libsignal" >&2
  exit 1
fi

# SwiftPM derives local package identity from the final path component. The
# monorepo package itself lives at swift/, so depending on libsignal/swift
# directly creates an identity collision.
rm -rf "$LIBSIGNAL_SWIFT_PACKAGE"
cp -R "$LIBSIGNAL_SWIFT_SOURCE" "$LIBSIGNAL_SWIFT_PACKAGE"

case "${1:-test}" in
  build)
    LIBRARY_PATH="$LIBSIGNAL_PATH" $SWIFT build "${@:2}"
    ;;
  test)
    LIBRARY_PATH="$LIBSIGNAL_PATH" $SWIFT test "${@:2}"
    ;;
  shell)
    LIBRARY_PATH="$LIBSIGNAL_PATH" bash
    ;;
  *)
    echo "Usage: ./dev.sh [build|test|shell]"
    echo "Extra args passed to swift, e.g.: ./dev.sh test --filter CoreFlowTests"
    ;;
esac
