#!/usr/bin/env bash
# Builds NewRadio.app from Swift sources without Xcode.
# Requires: macOS 14+ with Swift toolchain (ships with Command Line Tools).
set -euo pipefail

APP_NAME="NewRadio"
BUILD_DIR="build"
APP="${BUILD_DIR}/${APP_NAME}.app"
SRC_DIR="Sources"
PLIST="Resources/Info.plist"

if ! command -v swiftc >/dev/null 2>&1; then
    echo "error: swiftc not found. Install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi

rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS"
mkdir -p "${APP}/Contents/Resources"
cp "${PLIST}" "${APP}/Contents/Info.plist"

SOURCES=()
while IFS= read -r -d '' f; do
    SOURCES+=("$f")
done < <(find "${SRC_DIR}" -name '*.swift' -print0)

ARCH="$(uname -m)"
if [[ "${ARCH}" == "arm64" ]]; then
    TARGET="arm64-apple-macos14.0"
else
    TARGET="x86_64-apple-macos14.0"
fi

echo "› compiling ${#SOURCES[@]} source files for ${TARGET}"
swiftc \
    -O \
    -parse-as-library \
    -target "${TARGET}" \
    -framework SwiftUI \
    -framework AppKit \
    -framework AVFoundation \
    -o "${APP}/Contents/MacOS/${APP_NAME}" \
    "${SOURCES[@]}"

# Ad-hoc sign so Gatekeeper lets the local build run.
codesign --force --deep --sign - "${APP}" >/dev/null 2>&1 || true

echo "✓ built ${APP}"
echo "  run: open \"${APP}\""
