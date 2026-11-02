#!/bin/bash
# Sürüm numarasını Support/Info.plist içinde günceller.
set -euo pipefail
[ $# -ge 1 ] || { echo "Kullanım: $0 <sürüm> [yapı-no]" >&2; exit 2; }
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLIST="$ROOT_DIR/Support/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $1" "$PLIST"
if [ $# -ge 2 ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $2" "$PLIST"
fi
echo "✓ Sürüm güncellendi: $1"
