#!/bin/bash
# Universal (arm64 + x86_64) Curatare.app uygulama paketini oluşturur ve içine
# gömülü Mole motorunu (Contents/Resources/mole + Contents/MacOS/mole) yerleştirir.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Curatare"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
VENDOR_MOLE="$ROOT_DIR/Vendor/mole"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/tmp/curatare-clang-cache}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-/tmp/curatare-swiftpm-cache}"

echo "▸ Mole motoru kontrol ediliyor…"
if [ ! -x "$VENDOR_MOLE/mole" ]; then
  ./Scripts/update-mole.sh install --dest "$VENDOR_MOLE" --local-seed || ./Scripts/update-mole.sh install --dest "$VENDOR_MOLE"
fi

if [ ! -f "$ROOT_DIR/Resources/AppIcon.icns" ]; then
  echo "▸ Uygulama simgesi (AppIcon.icns) üretiliyor…"
  xcrun swift -module-cache-path "$CLANG_MODULE_CACHE_PATH" Scripts/make_icon.swift "$ROOT_DIR/Resources/AppIcon.icns"
fi

echo "▸ $APP_NAME universal olarak derleniyor (arm64 + x86_64)…"
BUILD_ARGS=(--disable-sandbox -c release --arch arm64 --arch x86_64)
swift build "${BUILD_ARGS[@]}" --product "$APP_NAME"
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod 755 "$MACOS_DIR/$APP_NAME"
strip -x "$MACOS_DIR/$APP_NAME" 2>/dev/null || true

echo "▸ Gömülü Mole motoru paketleniyor…"
mkdir -p "$RESOURCES_DIR/mole"
cp "$VENDOR_MOLE/mole" "$RESOURCES_DIR/mole/mole"
chmod 755 "$RESOURCES_DIR/mole/mole"
cp -R "$VENDOR_MOLE/bin" "$RESOURCES_DIR/mole/bin"
cp -R "$VENDOR_MOLE/lib" "$RESOURCES_DIR/mole/lib"
ln -sfn "../Resources/mole/mole" "$MACOS_DIR/mole"

if [ -f "$VENDOR_MOLE/LICENSE" ]; then
  cp "$VENDOR_MOLE/LICENSE" "$RESOURCES_DIR/Mole-LICENSE.txt"
fi
if [ -f "$VENDOR_MOLE/SOURCE.txt" ]; then
  cp "$VENDOR_MOLE/SOURCE.txt" "$RESOURCES_DIR/Mole-SOURCE.txt"
fi

echo "▸ Güncelleyici betiği paketleniyor…"
mkdir -p "$RESOURCES_DIR/Scripts"
cp "$ROOT_DIR/Scripts/update-mole.sh" "$RESOURCES_DIR/Scripts/update-mole.sh"
chmod 755 "$RESOURCES_DIR/Scripts/update-mole.sh"

echo "▸ Paket kaynakları ve yerelleştirme dosyaları kopyalanıyor…"
cp "$ROOT_DIR/Support/Info.plist" "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"

if [ -f "$ROOT_DIR/Resources/AppIcon.icns" ]; then
  cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi
if [ -f "$ROOT_DIR/Resources/InternetAccessPolicy.plist" ]; then
  cp "$ROOT_DIR/Resources/InternetAccessPolicy.plist" "$RESOURCES_DIR/InternetAccessPolicy.plist"
fi
for sound in "$ROOT_DIR/Resources"/*.aif "$ROOT_DIR/Resources"/*.aiff; do
  [ -f "$sound" ] || continue
  cp "$sound" "$RESOURCES_DIR/"
done
cp "$ROOT_DIR/LICENSE" "$RESOURCES_DIR/LICENSE.txt"
cp "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$RESOURCES_DIR/THIRD_PARTY_NOTICES.md"

for lproj in "$ROOT_DIR/Resources"/*.lproj; do
  [ -d "$lproj" ] || continue
  cp -R "$lproj" "$RESOURCES_DIR/"
done

if command -v codesign >/dev/null 2>&1; then
  echo "▸ Ad-hoc kod imzası uygulanıyor…"
  for helper in "$RESOURCES_DIR/mole/bin/analyze-go" "$RESOURCES_DIR/mole/bin/status-go"; do
    if [ -f "$helper" ]; then
      codesign --force --sign - "$helper"
    fi
  done
  codesign --force --sign - "$MACOS_DIR/$APP_NAME"
  codesign --force --sign - "$APP_BUNDLE"
fi

echo "✓ Hazır: $APP_BUNDLE"
lipo -info "$MACOS_DIR/$APP_NAME"
