#!/bin/bash
# Builds Dialed.app (and a zip) into ./build.
#   scripts/build-app.sh            release build for this Mac's architecture
#   scripts/build-app.sh universal  arm64 + x86_64 (used by CI releases)
# Signing: set SIGN_IDENTITY to a Developer ID to sign; otherwise the app is
# ad-hoc signed (macOS then asks for Accessibility again after each new build).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(cat VERSION)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
APP="build/Dialed.app"

ARCH_FLAGS=()
if [[ "${1:-}" == "universal" ]]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

echo "▸ Compiling (release)…"
swift build -c release --product Dialed ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c release --product Dialed ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

echo "▸ Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Dialed" "$APP/Contents/MacOS/Dialed"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"
sed -e "s/__VERSION__/$VERSION/g" -e "s/__BUILD__/$BUILD_NUMBER/g" Resources/Info.plist > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "▸ Signing…"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --entitlements Resources/Dialed.entitlements \
    --sign "$SIGN_IDENTITY" "$APP"
elif [[ "${STABLE_DEV_IDENTITY:-}" == "1" ]]; then
  # Local development only: an identifier-based designated requirement lets
  # macOS keep the Accessibility permission across rebuilds. Never ship this.
  codesign --force --entitlements Resources/Dialed.entitlements --sign - \
    -r='designated => identifier "io.github.taqionvibe.dialed"' "$APP"
else
  codesign --force --entitlements Resources/Dialed.entitlements --sign - "$APP"
fi
codesign --verify --strict "$APP"

echo "▸ Zipping…"
(cd build && rm -f Dialed.zip && ditto -c -k --keepParent Dialed.app Dialed.zip)
echo "✓ build/Dialed.app ($VERSION, build $BUILD_NUMBER)"
