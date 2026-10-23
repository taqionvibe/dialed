#!/bin/bash
# Packages an existing build/Dialed.app into build/Dialed.dmg with the branded
# drag-to-Applications window. Run scripts/build-app.sh first.
#   scripts/build-dmg.sh [path/to/Dialed.app]
# Needs dmgbuild (pip install dmgbuild); set DMGBUILD to its path if it isn't on PATH.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="${1:-build/Dialed.app}"
OUT="build/Dialed.dmg"
DMGBUILD="${DMGBUILD:-dmgbuild}"

if [[ ! -d "$APP" ]]; then
  echo "No app at ${APP}. Run scripts/build-app.sh first." >&2
  exit 1
fi
if ! command -v "$DMGBUILD" >/dev/null 2>&1; then
  echo "dmgbuild not found. Install it with: pip install dmgbuild" >&2
  exit 1
fi

echo "▸ Building ${OUT}…"
rm -f "$OUT"
"$DMGBUILD" -s scripts/dmg-settings.py -D app="$APP" "Dialed" "$OUT"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$OUT"
fi

hdiutil verify "$OUT" >/dev/null
echo "✓ ${OUT} ($(du -h "$OUT" | cut -f1))"
