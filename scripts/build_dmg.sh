#!/bin/sh
# Empaqueta FanCTL.app en un DMG de arrastrar a Aplicaciones.
# Uso: sh scripts/build_dmg.sh [ruta-al-app] [ruta-salida.dmg]
set -e

APP="${1:-$HOME/Desktop/FanCTL.app}"
OUT="${2:-$HOME/Desktop/FanCTL.dmg}"
BUILD="$(mktemp -d)"

if [ ! -d "$APP" ]; then
  echo "No se encuentra la app en: $APP" >&2
  exit 1
fi

cp -R "$APP" "$BUILD/"
ln -s /Applications "$BUILD/Aplicaciones"

hdiutil create -volname "FanCTL" -srcfolder "$BUILD" -ov -format UDZO "$OUT"
echo "DMG creado en: $OUT"

rm -rf "$BUILD"
