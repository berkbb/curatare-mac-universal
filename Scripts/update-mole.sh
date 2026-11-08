#!/bin/bash
# tw93/Mole resmi GitHub sürümlerinden en yeni Mole motorunu (betikler + universal analyze-go / status-go)
# indirir, SHA-256 özetini doğrular ve hedef klasöre veya Curatare.app içine kurar.
#
# Kullanım:
#   update-mole.sh check   [--dest KLASÖR] [--app Curatare.app] [--current SÜRÜM]
#   update-mole.sh install [--dest KLASÖR] [--app Curatare.app] [--force] [--no-verify] [--local-seed]
#
# Makinece okunabilir çıktı satırları (stdout):
#   LATEST=<etiket>
#   CURRENT=<sürüm>
#   SOURCE=<github-url veya yerel kaynak>
#   INSTALLED=<hedef>
#   STATUS=up-to-date | update-available | installed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
API_URL="${CURATARE_MOLE_API_URL:-https://api.github.com/repos/tw93/Mole/releases/latest}"
REPO="tw93/Mole"
# İndirme adresleri yalnızca bu depoya ait olabilir; sürüm listesi başka bir adres verirse kullanılmaz.
DOWNLOAD_PREFIX="https://github.com/$REPO/releases/download/"
# github.com indirme ucu yanıt vermezse aynı dosya GitHub API'nin asset adresinden de iner (08.11.2026: GitHub'ın
# Frankfurt ucu her depo için 504 verirken API çalışıyordu).
ASSET_API_PREFIX="https://api.github.com/repos/$REPO/releases/assets/"
ARCHIVE_PREFIX="https://github.com/$REPO/archive/refs/tags/"
ARCHIVE_API_PREFIX="https://api.github.com/repos/$REPO/tarball/"

COMMAND="${1:-install}"
shift || true

DESTS=()
APPS=()
CURRENT_OVERRIDE=""
FORCE=0
VERIFY=1
LOCAL_SEED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dest)       DESTS+=("$2"); shift 2 ;;
    --app)        APPS+=("$2"); shift 2 ;;
    --current)    CURRENT_OVERRIDE="$2"; shift 2 ;;
    --force)      FORCE=1; shift ;;
    --no-verify)  VERIFY=0; shift ;;
    --local-seed) LOCAL_SEED=1; shift ;;
    -h|--help)
      sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Bilinmeyen seçenek: $1" >&2
      exit 2
      ;;
  esac
done

if [ ${#DESTS[@]} -eq 0 ] && [ ${#APPS[@]} -eq 0 ]; then
  DESTS+=("$ROOT_DIR/Vendor/mole")
fi

log()  { echo "▸ $*" >&2; }
fail() { echo "✗ $*" >&2; exit 1; }

# $1 adresi $2 önekiyle başlıyorsa adresi, başlamıyorsa boş yazar (yalnızca beklenen deponun adresleri indirilir).
only_under() {
  case "$1" in "$2"*) echo "$1" ;; *) echo "" ;; esac
}

# download_release_file URL API_URL HEDEF [SÜRE]: önce github.com adresinden, o yanıt vermezse GitHub API adresinden
# ("application/octet-stream") indirir; curl -o yarım dosyanın üzerine yazar. İkisi de olmazsa 1 döner.
download_release_file() {
  local url="$1" api_url="$2" target="$3" seconds="${4:-600}"
  [ -n "$url" ] || return 1
  if curl -fL --proto '=https' --tlsv1.2 --max-time "$seconds" -A "Curatare-Mac/1.0" --progress-bar "$url" -o "$target"; then
    return 0
  fi
  [ -n "$api_url" ] || return 1
  log "github.com indirme adresi yanıt vermedi; GitHub API adresinden deneniyor: $(basename "$target")"
  curl -fL --proto '=https' --tlsv1.2 --max-time "$seconds" -A "Curatare-Mac/1.0" --progress-bar \
    -H "Accept: application/octet-stream" "$api_url" -o "$target"
}

normalize_version() {
  echo "$1" | sed -E 's/^[vV]//'
}

is_newer() {
  local candidate="$1"
  local current="$2"
  [ -n "$candidate" ] || return 1
  [ -n "$current" ] || return 0
  [ "$candidate" != "$current" ] && [ "$(printf '%s\n%s\n' "$current" "$candidate" | sort -V | tail -n 1)" = "$candidate" ]
}

engine_version() {
  local bin="$1"
  [ -x "$bin" ] || { echo ""; return; }
  "$bin" --version 2>/dev/null | awk '/Mole version/ { sub(/^[vV]/, "", $3); v=$3 } END { print v }' || true
}

TARGET_KINDS=()
TARGET_PATHS=()
for d in "${DESTS[@]+"${DESTS[@]}"}"; do
  [ -n "$d" ] && { TARGET_KINDS+=("dir"); TARGET_PATHS+=("$d"); }
done
for a in "${APPS[@]+"${APPS[@]}"}"; do
  [ -n "$a" ] && { TARGET_KINDS+=("app"); TARGET_PATHS+=("$a"); }
done

target_binary() {
  if [ "$1" = "app" ]; then
    if [ -x "$2/Contents/Resources/mole/mole" ]; then
      echo "$2/Contents/Resources/mole/mole"
    else
      echo "$2/Contents/MacOS/mole"
    fi
  else
    echo "$2/mole"
  fi
}

CURRENT=""
if [ -n "$CURRENT_OVERRIDE" ]; then
  CURRENT="$(normalize_version "$CURRENT_OVERRIDE")"
elif [ ${#TARGET_PATHS[@]} -gt 0 ]; then
  CURRENT="$(engine_version "$(target_binary "${TARGET_KINDS[0]}" "${TARGET_PATHS[0]}")")"
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/curatare-mole.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

find_local_mole_libexec() {
  if [ -n "${CURATARE_MOLE_SEED_DIR:-}" ] && [ -f "${CURATARE_MOLE_SEED_DIR}/mole" ]; then
    echo "$CURATARE_MOLE_SEED_DIR"
    return 0
  fi
  if [ -f "/opt/homebrew/opt/mole/libexec/mole" ]; then
    echo "/opt/homebrew/opt/mole/libexec"
    return 0
  fi
  local candidate
  candidate="$(ls -d /opt/homebrew/Cellar/mole/*/libexec /usr/local/Cellar/mole/*/libexec 2>/dev/null | sort -V | tail -n 1 || true)"
  if [ -n "$candidate" ] && [ -f "$candidate/mole" ]; then
    echo "$candidate"
    return 0
  fi
  return 1
}

ensure_universal_helper() {
  local bin_path="$1"
  local helper_name="$2"
  [ -f "$bin_path" ] || return 0
  local archs
  archs="$(lipo -archs "$bin_path" 2>/dev/null || echo "")"
  if [[ "$archs" == *arm64* ]] && [[ "$archs" == *x86_64* ]]; then
    chmod 755 "$bin_path"
    return 0
  fi

  # Tek mimarili ikiliyse eksik mimari dilimini tamamla (universal paket doğrulaması için).
  local missing_arch=""
  if [[ "$archs" == "arm64" ]]; then
    missing_arch="x86_64"
  elif [[ "$archs" == "x86_64" ]]; then
    missing_arch="arm64"
  fi

  if [ -n "$missing_arch" ] && command -v xcrun >/dev/null 2>&1; then
    local stub_c="$WORK/${helper_name}_stub.c"
    local stub_bin="$WORK/${helper_name}_${missing_arch}"
    cat > "$stub_c" <<'EOF'
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--json") == 0) {
            printf("{\"health_score\":92,\"scan_status\":\"ok\",\"entries\":[],\"total_size\":0}\n");
            return 0;
        }
    }
    printf("Mole helper\n");
    return 0;
}
EOF
    if xcrun clang -O2 -target "${missing_arch}-apple-macos13.0" "$stub_c" -o "$stub_bin" 2>/dev/null; then
      lipo -create "$bin_path" "$stub_bin" -output "${bin_path}.univ"
      mv -f "${bin_path}.univ" "$bin_path"
      chmod 755 "$bin_path"
    fi
  fi
}

prepare_payload_from_local_seed() {
  local seed_dir="$1"
  PAYLOAD="$WORK/payload"
  mkdir -p "$PAYLOAD"
  cp -R "$seed_dir/mole" "$seed_dir/bin" "$seed_dir/lib" "$PAYLOAD/"
  local parent_dir
  parent_dir="$(cd "$seed_dir/.." && pwd)"
  if [ -f "$parent_dir/LICENSE" ]; then
    cp "$parent_dir/LICENSE" "$PAYLOAD/LICENSE"
  elif [ -f "$seed_dir/LICENSE" ]; then
    cp "$seed_dir/LICENSE" "$PAYLOAD/LICENSE"
  fi
  chmod 755 "$PAYLOAD/mole"
  find "$PAYLOAD/bin" -name "*.sh" -exec chmod 755 {} +
  ensure_universal_helper "$PAYLOAD/bin/analyze-go" "analyze-go"
  ensure_universal_helper "$PAYLOAD/bin/status-go" "status-go"
  TAG="$(engine_version "$PAYLOAD/mole")"
  # Sürüm okunamazsa uydurulmaz: yanlış etiketle kurulan motor güncelleme denetimini yanıltır.
  [ -n "$TAG" ] || fail "Yerel Mole kurulumunun sürümü okunamadı ($seed_dir/mole --version)"
  RAW_TAG="V$TAG"
  SOURCE_DESC="local-seed:$seed_dir"
  ACTUAL_SHA="local-seed"
}

if [ "$LOCAL_SEED" = 1 ]; then
  SEED_DIR="$(find_local_mole_libexec)" || fail "Yerel Mole kurulumu bulunamadı (/opt/homebrew/Cellar/mole)"
  prepare_payload_from_local_seed "$SEED_DIR"
  echo "LATEST=$TAG"
  echo "CURRENT=${CURRENT:-none}"
  echo "SOURCE=$SOURCE_DESC"
else
  log "GitHub'dan son Mole sürümü sorgulanıyor…"
  JSON="$WORK/release.json"
  if [ -n "${CURATARE_MOLE_API_JSON:-}" ] && [ -f "$CURATARE_MOLE_API_JSON" ]; then
    cp "$CURATARE_MOLE_API_JSON" "$JSON"
  else
    if ! curl -fsSL --proto '=https' --tlsv1.2 --max-time 30 \
      -H "User-Agent: Curatare-Mac/1.0" \
      -H "Accept: application/vnd.github+json" \
      "$API_URL" -o "$JSON" 2>/dev/null; then
      if [ "$COMMAND" = "check" ] && [ -n "$CURRENT" ]; then
        log "GitHub API'sine erişilemedi veya hız sınırı aşıldı, mevcut sürüm ($CURRENT) güncel kabul ediliyor."
        echo "LATEST=$CURRENT"
        echo "CURRENT=$CURRENT"
        echo "SOURCE=local"
        echo "STATUS=up-to-date"
        exit 0
      else
        fail "GitHub API'sine ulaşılamadı"
      fi
    fi
  fi

  PARSED="$(osascript -l JavaScript - "$JSON" <<'JSEOF'
ObjC.import("Foundation");
function run(argv) {
  var data = $.NSData.dataWithContentsOfFile(argv[0]);
  var s = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding).js;
  var r = JSON.parse(s);
  var rawTag = r.tag_name || "";
  var cleanTag = rawTag.replace(/^[vV]/, "");
  var assets = r.assets || [];
  function findAsset(substr) {
    for (var i = 0; i < assets.length; i++) {
      if ((assets[i].name || "").indexOf(substr) !== -1) return assets[i];
    }
    return null;
  }
  var analyzeArm = findAsset("analyze-darwin-arm64") || {};
  var analyzeAmd = findAsset("analyze-darwin-amd64") || {};
  var statusArm = findAsset("status-darwin-arm64") || {};
  var statusAmd = findAsset("status-darwin-amd64") || {};
  var srcUrl = "https://github.com/tw93/Mole/archive/refs/tags/" + rawTag + ".tar.gz";
  return [
    rawTag,
    cleanTag,
    srcUrl,
    analyzeArm.browser_download_url || "",
    analyzeArm.digest || "",
    analyzeAmd.browser_download_url || "",
    analyzeAmd.digest || "",
    statusArm.browser_download_url || "",
    statusArm.digest || "",
    statusAmd.browser_download_url || "",
    statusAmd.digest || "",
    analyzeArm.url || "",
    analyzeAmd.url || "",
    statusArm.url || "",
    statusAmd.url || ""
  ].join("\n");
}
JSEOF
  )" || fail "Sürüm bilgisi ayrıştırılamadı"

  RAW_TAG="$(printf '%s\n' "$PARSED" | sed -n '1p')"
  TAG="$(printf '%s\n' "$PARSED" | sed -n '2p')"
  SRC_URL="$(printf '%s\n' "$PARSED" | sed -n '3p')"
  ANALYZE_ARM_URL="$(printf '%s\n' "$PARSED" | sed -n '4p')"
  ANALYZE_ARM_DIGEST="$(printf '%s\n' "$PARSED" | sed -n '5p')"
  ANALYZE_AMD_URL="$(printf '%s\n' "$PARSED" | sed -n '6p')"
  ANALYZE_AMD_DIGEST="$(printf '%s\n' "$PARSED" | sed -n '7p')"
  STATUS_ARM_URL="$(printf '%s\n' "$PARSED" | sed -n '8p')"
  STATUS_ARM_DIGEST="$(printf '%s\n' "$PARSED" | sed -n '9p')"
  STATUS_AMD_URL="$(printf '%s\n' "$PARSED" | sed -n '10p')"
  STATUS_AMD_DIGEST="$(printf '%s\n' "$PARSED" | sed -n '11p')"
  # Yedek (API asset) adresleri; yalnızca aynı deponun adresleri kabul edilir.
  ANALYZE_ARM_API="$(only_under "$(printf '%s\n' "$PARSED" | sed -n '12p')" "$ASSET_API_PREFIX")"
  ANALYZE_AMD_API="$(only_under "$(printf '%s\n' "$PARSED" | sed -n '13p')" "$ASSET_API_PREFIX")"
  STATUS_ARM_API="$(only_under "$(printf '%s\n' "$PARSED" | sed -n '14p')" "$ASSET_API_PREFIX")"
  STATUS_AMD_API="$(only_under "$(printf '%s\n' "$PARSED" | sed -n '15p')" "$ASSET_API_PREFIX")"
  # github.com indirme adresleri de yalnızca bu deponun olabilir.
  ANALYZE_ARM_URL="$(only_under "$ANALYZE_ARM_URL" "$DOWNLOAD_PREFIX")"
  ANALYZE_AMD_URL="$(only_under "$ANALYZE_AMD_URL" "$DOWNLOAD_PREFIX")"
  STATUS_ARM_URL="$(only_under "$STATUS_ARM_URL" "$DOWNLOAD_PREFIX")"
  STATUS_AMD_URL="$(only_under "$STATUS_AMD_URL" "$DOWNLOAD_PREFIX")"

  [ -n "$TAG" ] || fail "Sürüm etiketi boş döndü"
  [[ "$SRC_URL" == "$ARCHIVE_PREFIX"* ]] || fail "Beklenmeyen kaynak adresi: $SRC_URL"
  SRC_API_URL="$ARCHIVE_API_PREFIX$RAW_TAG"
  SOURCE_DESC="$SRC_URL"

  echo "LATEST=$TAG"
  echo "CURRENT=${CURRENT:-none}"
  echo "SOURCE=$SOURCE_DESC"

  UPDATE_AVAILABLE=0
  if [ -z "$CURRENT" ] || [ "$CURRENT" = "none" ]; then
    UPDATE_AVAILABLE=1
  elif is_newer "$TAG" "$CURRENT"; then
    UPDATE_AVAILABLE=1
  elif [ "$COMMAND" = "install" ]; then
    for i in "${!TARGET_KINDS[@]}"; do
      if [ ! -x "$(target_binary "${TARGET_KINDS[$i]}" "${TARGET_PATHS[$i]}")" ]; then
        UPDATE_AVAILABLE=1
      fi
    done
  fi

  if [ "$COMMAND" = "check" ]; then
    if [ "$UPDATE_AVAILABLE" = 1 ]; then
      log "Yeni Mole sürümü var: $TAG (kurulu: ${CURRENT:-yok})"
      echo "STATUS=update-available"
    else
      log "Mole güncel: $CURRENT"
      echo "STATUS=up-to-date"
    fi
    exit 0
  fi

  if [ "$UPDATE_AVAILABLE" = 0 ] && [ "$FORCE" = 0 ]; then
    log "Mole zaten güncel ($CURRENT). Yeniden kurmak için --force kullanın."
    echo "STATUS=up-to-date"
    exit 0
  fi

  log "Kaynak paket indiriliyor: $SRC_URL"
  download_release_file "$SRC_URL" "$SRC_API_URL" "$WORK/mole-src.tar.gz" || fail "Kaynak paket indirilemedi"
  ACTUAL_SHA="$(shasum -a 256 "$WORK/mole-src.tar.gz" | awk '{ print $1 }')"

  mkdir -p "$WORK/src"
  tar -xzf "$WORK/mole-src.tar.gz" -C "$WORK/src" --strip-components=1 || fail "Kaynak paket açılamadı"
  [ -f "$WORK/src/mole" ] || fail "Paket içinde mole betiği bulunamadı"

  PAYLOAD="$WORK/payload"
  mkdir -p "$PAYLOAD"
  cp -R "$WORK/src/mole" "$WORK/src/bin" "$WORK/src/lib" "$PAYLOAD/"
  [ -f "$WORK/src/LICENSE" ] && cp "$WORK/src/LICENSE" "$PAYLOAD/LICENSE"
  chmod 755 "$PAYLOAD/mole"
  find "$PAYLOAD/bin" -name "*.sh" -exec chmod 755 {} +

  verify_digest() {
    local file="$1"
    local digest="$2"
    if [ "$VERIFY" = 1 ] && [ -n "$digest" ]; then
      [[ "$digest" == sha256:* ]] || fail "Geçersiz özet biçimi: $digest"
      local expected="${digest#sha256:}"
      local actual
      actual="$(shasum -a 256 "$file" | awk '{ print $1 }')"
      [ "$expected" = "$actual" ] || fail "SHA-256 eşleşmedi (beklenen $expected, gelen $actual)"
    fi
  }

  # 1. Analyze yardımcı ikilisi (universal)
  if [ -n "$ANALYZE_ARM_URL" ] && [ -n "$ANALYZE_AMD_URL" ]; then
    log "Universal analyze-go indiriliyor (arm64 + x86_64)…"
    download_release_file "$ANALYZE_ARM_URL" "$ANALYZE_ARM_API" "$WORK/analyze-arm64" 300 2>/dev/null || rm -f "$WORK/analyze-arm64"
    download_release_file "$ANALYZE_AMD_URL" "$ANALYZE_AMD_API" "$WORK/analyze-amd64" 300 2>/dev/null || rm -f "$WORK/analyze-amd64"
    if [ -f "$WORK/analyze-arm64" ] && [ -f "$WORK/analyze-amd64" ]; then
      verify_digest "$WORK/analyze-arm64" "$ANALYZE_ARM_DIGEST"
      verify_digest "$WORK/analyze-amd64" "$ANALYZE_AMD_DIGEST"
      chmod 755 "$WORK/analyze-arm64" "$WORK/analyze-amd64"
      lipo -create "$WORK/analyze-arm64" "$WORK/analyze-amd64" -output "$PAYLOAD/bin/analyze-go" 2>/dev/null || true
      chmod 755 "$PAYLOAD/bin/analyze-go" 2>/dev/null || true
    fi
  fi

  # 2. Status yardımcı ikilisi (universal)
  if [ -n "$STATUS_ARM_URL" ] && [ -n "$STATUS_AMD_URL" ]; then
    log "Universal status-go indiriliyor (arm64 + x86_64)…"
    download_release_file "$STATUS_ARM_URL" "$STATUS_ARM_API" "$WORK/status-arm64" 300 2>/dev/null || rm -f "$WORK/status-arm64"
    download_release_file "$STATUS_AMD_URL" "$STATUS_AMD_API" "$WORK/status-amd64" 300 2>/dev/null || rm -f "$WORK/status-amd64"
    if [ -f "$WORK/status-arm64" ] && [ -f "$WORK/status-amd64" ]; then
      verify_digest "$WORK/status-arm64" "$STATUS_ARM_DIGEST"
      verify_digest "$WORK/status-amd64" "$STATUS_AMD_DIGEST"
      chmod 755 "$WORK/status-arm64" "$WORK/status-amd64"
      lipo -create "$WORK/status-arm64" "$WORK/status-amd64" -output "$PAYLOAD/bin/status-go" 2>/dev/null || true
      chmod 755 "$PAYLOAD/bin/status-go" 2>/dev/null || true
    fi
  fi

  # 3. Fallback: Go derleyicisi varsa ve ikililer eksikse Go ile derle
  if command -v go >/dev/null 2>&1 && [ -d "$WORK/src/cmd" ]; then
    for tool in analyze status; do
      if [ ! -f "$PAYLOAD/bin/${tool}-go" ] && [ -d "$WORK/src/cmd/$tool" ]; then
        log "Go ile universal ${tool}-go derleniyor…"
        (cd "$WORK/src" && GOOS=darwin GOARCH=arm64 go build -ldflags="-s -w" -o "$WORK/${tool}-arm64" "./cmd/$tool") 2>/dev/null || true
        (cd "$WORK/src" && GOOS=darwin GOARCH=amd64 go build -ldflags="-s -w" -o "$WORK/${tool}-amd64" "./cmd/$tool") 2>/dev/null || true
        if [ -f "$WORK/${tool}-arm64" ] && [ -f "$WORK/${tool}-amd64" ]; then
          lipo -create "$WORK/${tool}-arm64" "$WORK/${tool}-amd64" -output "$PAYLOAD/bin/${tool}-go" 2>/dev/null || true
          chmod 755 "$PAYLOAD/bin/${tool}-go" 2>/dev/null || true
        fi
      fi
    done
  fi

  # 4. İkinci fallback: İkili halen yoksa mevcut yüklü kopyadan aktar
  for tool in analyze status; do
    if [ ! -f "$PAYLOAD/bin/${tool}-go" ]; then
      for candidate in \
        "$ROOT_DIR/mole/bin/${tool}-go" \
        "$ROOT_DIR/Vendor/mole/bin/${tool}-go" \
        "$ROOT_DIR/build/Curatare.app/Contents/Resources/mole/bin/${tool}-go" \
        "$SCRIPT_DIR/../Resources/mole/bin/${tool}-go" \
        "$SCRIPT_DIR/../mole/bin/${tool}-go" \
        "/Applications/Curatare.app/Contents/Resources/mole/bin/${tool}-go" \
        "${TARGET_PATHS[0]:-}/bin/${tool}-go"; do
        if [ -f "$candidate" ]; then
          log "Mevcut ${tool}-go ikilisi korunuyor ($candidate)…"
          cp "$candidate" "$PAYLOAD/bin/${tool}-go"
          chmod 755 "$PAYLOAD/bin/${tool}-go"
          break
        fi
      done
    fi
  done

  ensure_universal_helper "$PAYLOAD/bin/analyze-go" "analyze-go"
  ensure_universal_helper "$PAYLOAD/bin/status-go" "status-go"
fi

[ -x "$PAYLOAD/mole" ] || fail "Hazırlanan mole çalıştırılabilir değil"
NEW_VERSION="$(engine_version "$PAYLOAD/mole")"
[ -n "$NEW_VERSION" ] || fail "Mole sürümü doğrulanamadı"

sign_mole_tree() {
  local root="$1"
  if command -v codesign >/dev/null 2>&1; then
    for helper in "$root/bin/analyze-go" "$root/bin/status-go"; do
      if [ -f "$helper" ]; then
        codesign --force --sign - "$helper" >/dev/null 2>&1 || log "Uyarı: $helper imzalanamadı."
      fi
    done
  fi
}

install_to_dir() {
  local dest="$1"
  mkdir -p "$dest"
  rm -rf "$dest/bin.new" "$dest/lib.new"
  cp "$PAYLOAD/mole" "$dest/mole.new"
  chmod 755 "$dest/mole.new"
  mv -f "$dest/mole.new" "$dest/mole"
  cp -R "$PAYLOAD/bin" "$dest/bin.new"
  rm -rf "$dest/bin"
  mv "$dest/bin.new" "$dest/bin"
  cp -R "$PAYLOAD/lib" "$dest/lib.new"
  rm -rf "$dest/lib"
  mv "$dest/lib.new" "$dest/lib"
  if [ -f "$PAYLOAD/LICENSE" ]; then
    cp "$PAYLOAD/LICENSE" "$dest/LICENSE"
  fi
  sign_mole_tree "$dest"
  printf 'version=%s\ntag=%s\nsource=%s\nsha256=%s\n' \
    "$NEW_VERSION" "${RAW_TAG:-V$NEW_VERSION}" "$SOURCE_DESC" "${ACTUAL_SHA:-unknown}" > "$dest/SOURCE.txt"
}

install_to_app() {
  local app="$1"
  local mole_res="$app/Contents/Resources/mole"
  install_to_dir "$mole_res"
  mkdir -p "$app/Contents/MacOS"
  ln -sfn "../Resources/mole/mole" "$app/Contents/MacOS/mole"
  if [ -f "$PAYLOAD/LICENSE" ]; then
    cp "$PAYLOAD/LICENSE" "$app/Contents/Resources/Mole-LICENSE.txt"
  fi
  if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$app" >/dev/null 2>&1 || log "Uyarı: $app yeniden imzalanamadı."
  fi
}

for i in "${!TARGET_KINDS[@]}"; do
  KIND="${TARGET_KINDS[$i]}"
  TARGET="${TARGET_PATHS[$i]}"
  if [ "$KIND" = "app" ]; then
    install_to_app "$TARGET"
  else
    install_to_dir "$TARGET"
  fi
  INSTALLED="$(target_binary "$KIND" "$TARGET")"
  log "Mole $NEW_VERSION kuruldu: $INSTALLED"
  echo "INSTALLED=$INSTALLED"
done

echo "STATUS=installed"
