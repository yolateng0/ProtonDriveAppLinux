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
APPDATA_DIR="$PACKAGE_ROOT/usr/share/metainfo"

chmod 755 "$APP_BIN" "$APP_PY"
mkdir -p "$ICON_DIR_48" "$ICON_DIR_128" "$ICON_DIR_192" "$DOC_DIR" "$APPDATA_DIR"

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

cat > "$DOC_DIR/changelog.Debian" <<'EOF'
protondrive-gui (0.1.0) unstable; urgency=medium

  * Initial GTK3 prototype for ProtonDrive Debian desktop integration.

 -- yolateng0 <noreply@users.noreply.github.com>  Mon, 20 Oct 2026 07:00:00 +0000
EOF

cat > "$APPDATA_DIR/protondrive-gui.appdata.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>protondrive-gui.desktop</id>
  <name>ProtonDrive</name>
  <summary>GTK3 desktop dashboard for ProtonDrive</summary>
  <description>
    <p>ProtonDrive is a lightweight GTK3 desktop dashboard for checking the ProtonDrive configuration and mount state on Debian.</p>
    <p>The application helps verify the rclone remote, the local mount point and the status of the systemd user service.</p>
  </description>
  <metadata_license>MIT</metadata_license>
  <project_license>MIT</project_license>
  <url type="homepage">https://github.com/yolateng0/ProtonDriveAppLinux</url>
  <project_group>ProtonDriveAppLinux</project_group>
  <content_rating type="oars-1.1"/>
  <screenshots>
    <screenshot type="default">
      <image>https://raw.githubusercontent.com/yolateng0/ProtonDriveAppLinux/main/package_root/usr/share/icons/hicolor/scalable/apps/protondrive-gui.svg</image>
    </screenshot>
  </screenshots>
</component>
EOF

if [ -f "$SVG" ]; then
  if command -v rsvg-convert >/dev/null 2>&1; then
    echo "Génération PNG depuis le SVG avec rsvg-convert"
    rsvg-convert -w 48 -h 48 "$SVG" -o "$ICON_DIR_48/protondrive-gui.png"
    rsvg-convert -w 128 -h 128 "$SVG" -o "$ICON_DIR_128/protondrive-gui.png"
    rsvg-convert -w 192 -h 192 "$SVG" -o "$ICON_DIR_192/protondrive-gui.png"
  elif command -v convert >/dev/null 2>&1; then
    echo "Génération PNG depuis le SVG avec ImageMagick"
    convert "$SVG" -resize 48x48 "$ICON_DIR_48/protondrive-gui.png"
    convert "$SVG" -resize 128x128 "$ICON_DIR_128/protondrive-gui.png"
    convert "$SVG" -resize 192x192 "$ICON_DIR_192/protondrive-gui.png"
  else
    echo "Aucun outil de conversion SVG vers PNG détecté. Les icônes vectorielles seront conservées." >&2
  fi
fi

DEB_NAME="protondrive-gui_0.1.0_all.deb"
rm -f "$REPO_ROOT/$DEB_NAME"

echo "Construction du paquet .deb..."
dpkg-deb --root-owner-group --build "$PACKAGE_ROOT" "$REPO_ROOT/$DEB_NAME"

echo "Paquet créé : $REPO_ROOT/$DEB_NAME"
echo "Commande d'installation : sudo apt install -f ./$DEB_NAME"
