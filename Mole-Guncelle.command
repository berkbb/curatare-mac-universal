#!/bin/bash
# Finder'da çift tıklayınca projedeki Mole motorunu (Vendor/mole) ve varsa derlenmiş
# build/Curatare.app içindeki Mole motorunu GitHub'daki son sürüme günceller.
cd "$(dirname "$0")" || exit 1
TARGETS=(--dest "$(pwd)/Vendor/mole")
if [ -d build/Curatare.app ]; then TARGETS+=(--app "$(pwd)/build/Curatare.app"); fi
./Scripts/update-mole.sh install "${TARGETS[@]}" "$@"
STATUS=$?
echo
read -r -p "Kapatmak için Enter'a basın…" _
exit $STATUS
