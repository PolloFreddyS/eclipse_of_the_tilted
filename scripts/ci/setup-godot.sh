#!/usr/bin/env bash
# Descarga Godot y las plantillas de exportación (web y Android) si no están en caché.
# Uso: setup-godot.sh <versión>   p. ej. 4.7.2
set -euo pipefail
V="$1"
TOOLS="${GODOT_TOOLS_DIR:-$HOME/godot-tools}"
TEMPLATES="$HOME/.local/share/godot/export_templates/$V.stable"
BASE="https://github.com/godotengine/godot/releases/download/$V-stable"
mkdir -p "$TOOLS" "$TEMPLATES"
if [ ! -x "$TOOLS/godot" ]; then
  curl -sSL -o "$TOOLS/editor.zip" "$BASE/Godot_v$V-stable_linux.x86_64.zip"
  unzip -o -q "$TOOLS/editor.zip" -d "$TOOLS"
  mv "$TOOLS/Godot_v$V-stable_linux.x86_64" "$TOOLS/godot"
  rm "$TOOLS/editor.zip"
fi
if [ ! -f "$TEMPLATES/version.txt" ]; then
  curl -sSL -o "$TOOLS/templates.tpz" "$BASE/Godot_v$V-stable_export_templates.tpz"
  unzip -o -q -j "$TOOLS/templates.tpz" 'templates/web_nothreads_*' 'templates/android_debug.apk' 'templates/android_release.apk' 'templates/version.txt' -d "$TEMPLATES"
  rm "$TOOLS/templates.tpz"
fi
"$TOOLS/godot" --version
