#!/bin/bash
# build/Curatare.app uygulama paketinin tüm bütünlük, mimari, yerelleştirme ve kod imzası kurallarını doğrular.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT_DIR/build/Curatare.app}"

fail() { echo "✗ $*" >&2; exit 1; }
ok()   { echo "✓ $*"; }

[ -d "$APP" ] || fail "Uygulama paketi bulunamadı: $APP"

MAIN_BIN="$APP/Contents/MacOS/Curatare"
MOLE_LINK="$APP/Contents/MacOS/mole"
MOLE_SCRIPT="$APP/Contents/Resources/mole/mole"
ANALYZE_BIN="$APP/Contents/Resources/mole/bin/analyze-go"
STATUS_BIN="$APP/Contents/Resources/mole/bin/status-go"
UPDATER="$APP/Contents/Resources/Scripts/update-mole.sh"

[ -x "$MAIN_BIN" ] || fail "Ana çalıştırılabilir bulunamadı: $MAIN_BIN"
[ -L "$MOLE_LINK" ] || fail "Contents/MacOS/mole sembolik bağlantısı eksik"
[ -x "$MOLE_SCRIPT" ] || fail "Gömülü Mole betiği bulunamadı: $MOLE_SCRIPT"
[ -x "$ANALYZE_BIN" ] || fail "analyze-go bulunamadı: $ANALYZE_BIN"
[ -x "$STATUS_BIN" ] || fail "status-go bulunamadı: $STATUS_BIN"
[ -x "$UPDATER" ] || fail "update-mole.sh bulunamadı: $UPDATER"

for bin in "$MAIN_BIN" "$ANALYZE_BIN" "$STATUS_BIN"; do
  ARCHS="$(lipo -archs "$bin")"
  [[ "$ARCHS" == *arm64* ]] && [[ "$ARCHS" == *x86_64* ]] || fail "$bin universal değil ($ARCHS)"
done
ok "Universal ikililer doğrulandı (Curatare, analyze-go, status-go: arm64 + x86_64)"

MOLE_VER="$("$MOLE_LINK" --version 2>/dev/null | awk '/Mole version/ { v=$3 } END { print v }')"
[ -n "$MOLE_VER" ] || fail "Gömülü Mole çalıştırılamadı"
ok "Gömülü Mole sürümü: $MOLE_VER"

for lang in tr en ro; do
  for f in Localizable.strings InfoPlist.strings ServicesMenu.strings; do
    p="$APP/Contents/Resources/${lang}.lproj/$f"
    [ -f "$p" ] || fail "Eksik yerelleştirme dosyası: $p"
    plutil -lint "$p" >/dev/null || fail "Bozuk strings dosyası: $p"
  done
done
ok "Üç dilli (tr/en/ro) yerelleştirme dosyaları doğrulandı"

for doc in LICENSE.txt THIRD_PARTY_NOTICES.md Mole-LICENSE.txt AppIcon.icns curatare_trash.aiff curatare_restore.aiff; do
  [ -f "$APP/Contents/Resources/$doc" ] || fail "Eksik kaynak dosyası: $doc"
done
ok "Lisanslar, ses efektleri ve simge doğrulandı"

codesign --verify --deep --strict "$APP" || fail "codesign doğrulaması başarısız"
ok "Kod imzası doğrulandı (codesign --verify --deep --strict)"
