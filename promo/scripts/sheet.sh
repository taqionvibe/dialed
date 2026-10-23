#!/bin/bash
# Contact sheet of frames from a rendered reel: scripts/sheet.sh <video> <out.png> <frame> [frame…]
set -euo pipefail
video="$1"; out="$2"; shift 2
dir=$(mktemp -d)
FF="node_modules/@remotion/compositor-darwin-arm64"
i=0
for fr in "$@"; do
  t=$(python3 -c "print($fr/30)")
  DYLD_LIBRARY_PATH="$FF" "$FF/ffmpeg" -loglevel error -ss "$t" -i "$video" -frames:v 1 -vf scale=360:-1 "$dir/$(printf %02d $i).png"
  i=$((i+1))
done
swift scripts/tile.swift "$out" 6 "$dir"/*.png 2>&1 | grep -v DVT || true
rm -rf "$dir"
echo "sheet: $out"
