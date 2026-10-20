#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PACKAGE_ROOT="$SCRIPT_DIR"
REPO_ROOT=$(dirname "$PACKAGE_ROOT")
APP_BIN="$PACKAGE_ROOT/usr/bin/protondrive-gui"
APP_PY="$PACKAGE_ROOT/usr/lib/protondrive/gui.py"
SVG="$PACKAGE_ROOT/usr/share/icons/hicolor/scalable/apps/protondrive-gui.svg"
ICON_DIR_48="$PACKAGE_ROOT/usr/share/icons/hicolor/48x48/apps"
ICON_DIR_128="$PACKAGE_ROOT/usr/share/icons/hicolor/128x128/apps"
ICON_DIR_192="$PACKAGE_ROOT/usr/share/icons/hicolor/192x192/apps"
DOC_DIR="$PACKAGE_ROOT/usr/share/doc/protondrive-gui"

chmod 755 "$APP_BIN" "$APP_PY"
mkdir -p "$ICON_DIR_48" "$ICON_DIR_128" "$ICON_DIR_192" "$DOC_DIR"

cat > "$DOC_DIR/copyright" <<'EOF'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: protondrive-gui
Source: https://github.com/yolateng0/ProtonDriveAppLinux

Files: *
Copyright: 2026, yolateng0
License: MIT
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 .
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 .
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
EOF

if [ -f "$SVG" ]; then
  if command -v rsvg-convert >/dev/null 2>&1; then
    echo "Génération des icônes PNG via rsvg-convert"
    rsvg-convert -w 48 -h 48 "$SVG" -o "$ICON_DIR_48/protondrive-gui.png"
    rsvg-convert -w 128 -h 128 "$SVG" -o "$ICON_DIR_128/protondrive-gui.png"
    rsvg-convert -w 192 -h 192 "$SVG" -o "$ICON_DIR_192/protondrive-gui.png"
  elif command -v convert >/dev/null 2>&1; then
    echo "Génération des icônes PNG via ImageMagick"
    convert "$SVG" -resize 48x48 "$ICON_DIR_48/protondrive-gui.png"
    convert "$SVG" -resize 128x128 "$ICON_DIR_128/protondrive-gui.png"
    convert "$SVG" -resize 192x192 "$ICON_DIR_192/protondrive-gui.png"
  else
    echo "Aucun outil SVG->PNG trouvé; seules les icônes vectorielles seront incluses." >&2
  fi
fi

DEB_NAME="protondrive-gui_0.1.0_all.deb"
rm -f "$REPO_ROOT/$DEB_NAME"

echo "Construction du paquet .deb..."
dpkg-deb --build "$PACKAGE_ROOT" "$REPO_ROOT/$DEB_NAME"

echo "Paquet créé : $REPO_ROOT/$DEB_NAME"
echo "Installer : sudo dpkg -i $REPO_ROOT/$DEB_NAME || true"
echo "Puis : sudo apt-get -f install"
