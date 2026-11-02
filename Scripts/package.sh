#!/bin/bash
# Curatare'ı dağıtıma hazır paketler: evrensel .app, .dmg (Mole motoru dahil).
#
# Kullanım: package.sh [--skip-tests] [--update-mole]
#   --skip-tests   Testleri çalıştırmadan paketle
#   --update-mole  Paketlemeden önce Vendor/mole'u GitHub'daki son sürüme güncelle
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN_TESTS=1
UPDATE_ENGINE=0
for arg in "$@"; do
  case "$arg" in
    --skip-tests) RUN_TESTS=0 ;;
    --update-mole) UPDATE_ENGINE=1 ;;
    -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Bilinmeyen seçenek: $arg" >&2; exit 2 ;;
  esac
done

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/tmp/curatare-clang-cache}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-/tmp/curatare-swiftpm-cache}"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Support/Info.plist")"
DIST="$ROOT/dist"
APP="$ROOT/build/Curatare.app"
NAME="Curatare-$VERSION"

if [ "$UPDATE_ENGINE" = 1 ]; then
  echo "▸ Mole motoru güncelleniyor…"
  "$ROOT/Scripts/update-mole.sh" install --dest "$ROOT/Vendor/mole"
fi

if [ "$RUN_TESTS" = 1 ]; then
  echo "▸ Testler çalıştırılıyor…"
  swift test --package-path "$ROOT" --disable-sandbox
fi

"$ROOT/Scripts/build_app.sh"

# Paketin Mole motorunu içerdiğini ve çalıştığını doğrula.
ENGINE="$APP/Contents/MacOS/mole"
[ -x "$ENGINE" ] || { echo "HATA: Pakette mole yok." >&2; exit 1; }
ENGINE_VERSION="$("$ENGINE" --version 2>/dev/null | awk '/Mole version/ { v=$3 } END { print v }')"
echo "▸ Paketteki Mole: ${ENGINE_VERSION:-okunamadı}"
"$ROOT/Scripts/verify_bundle.sh" "$APP"

echo "▸ Dağıtım dosyaları hazırlanıyor…"
mkdir -p "$DIST"
rm -f "$DIST/$NAME.dmg" "$DIST/$NAME.dmg.sig" "$DIST/SHA256SUMS.txt"

STAGING="$(mktemp -d "${TMPDIR:-/tmp}/curatare-dmg.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Curatare.app"
ln -s /Applications "$STAGING/Applications"
cp "$ROOT/LICENSE" "$STAGING/LICENSE.txt"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$STAGING/THIRD_PARTY_NOTICES.txt"
hdiutil create -quiet -volname "Curatare $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO "$DIST/$NAME.dmg"

DMG_PATH="$DIST/$NAME.dmg"
SIGNING_TOOL=(xcrun swift "$ROOT/Scripts/update_signing.swift")
APP_PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :CuratareUpdatePublicEDKey' "$ROOT/Support/Info.plist" 2>/dev/null || true)"

if [ -n "$APP_PUBLIC_KEY" ]; then
  KEYCHAIN_PUBLIC_KEY="$("${SIGNING_TOOL[@]}" public-key 2>/dev/null || true)"
  if [ -n "$KEYCHAIN_PUBLIC_KEY" ] && [ "$APP_PUBLIC_KEY" = "$KEYCHAIN_PUBLIC_KEY" ]; then
    echo "▸ DMG imzalanıyor (Ed25519)…"
    "${SIGNING_TOOL[@]}" sign "$DMG_PATH" > "$DMG_PATH.sig"
    "${SIGNING_TOOL[@]}" verify "$DMG_PATH" "$(cat "$DMG_PATH.sig")" "$APP_PUBLIC_KEY"
    echo "✓ İmza doğrulandı ($DMG_PATH.sig)"
  else
    echo "▸ Keychain Ed25519 imzalama anahtarı bulunamadı; .sig üretimi atlanıyor (anahtarsız dağıtım)."
  fi
fi

echo "▸ SHA-256 özetleri oluşturuluyor…"
(cd "$DIST" && shasum -a 256 "$NAME.dmg" > SHA256SUMS.txt)

echo "✓ Paketler hazır:"
READY_FILES=("$DIST/$NAME.dmg" "$DIST/SHA256SUMS.txt")
if [ -f "$DMG_PATH.sig" ]; then
  READY_FILES+=("$DMG_PATH.sig")
fi
for file in "${READY_FILES[@]}"; do
  printf '   %s\t%s\n' "$(du -h "$file" | cut -f1)" "$file"
done
