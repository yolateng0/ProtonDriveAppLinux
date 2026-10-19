#!/bin/sh
set -e

# build.sh — construit les PNG à partir du SVG (si rsvg-convert ou convert disponible)
# puis construit le .deb depuis package_root/

# rendre exécutable les binaires
chmod +x package_root/usr/bin/protondrive-gui
chmod +x package_root/usr/lib/protondrive/gui.py

# générer des PNG pour les tailles communes si possible
SVG=package_root/usr/share/icons/hicolor/scalable/apps/protondrive-gui.svg
if [ -f "$SVG" ]; then
  if command -v rsvg-convert >/dev/null 2>&1; then
    echo "Génération PNG avec rsvg-convert"
    mkdir -p package_root/usr/share/icons/hicolor/48x48/apps
    mkdir -p package_root/usr/share/icons/hicolor/128x128/apps
    mkdir -p package_root/usr/share/icons/hicolor/192x192/apps
    rsvg-convert -w 48 -h 48 "$SVG" -o package_root/usr/share/icons/hicolor/48x48/apps/protondrive-gui.png
    rsvg-convert -w 128 -h 128 "$SVG" -o package_root/usr/share/icons/hicolor/128x128/apps/protondrive-gui.png
    rsvg-convert -w 192 -h 192 "$SVG" -o package_root/usr/share/icons/hicolor/192x192/apps/protondrive-gui.png
  elif command -v convert >/dev/null 2>&1; then
    echo "Génération PNG avec ImageMagick convert"
    mkdir -p package_root/usr/share/icons/hicolor/48x48/apps
    mkdir -p package_root/usr/share/icons/hicolor/128x128/apps
    mkdir -p package_root/usr/share/icons/hicolor/192x192/apps
    convert "$SVG" -resize 48x48 package_root/usr/share/icons/hicolor/48x48/apps/protondrive-gui.png
    convert "$SVG" -resize 128x128 package_root/usr/share/icons/hicolor/128x128/apps/protondrive-gui.png
    convert "$SVG" -resize 192x192 package_root/usr/share/icons/hicolor/192x192/apps/protondrive-gui.png
  else
    echo "Aucun outil de conversion SVG->PNG trouvé (rsvg-convert ou convert). Les PNG ne seront pas générés." >&2
  fi
fi

DEBNAME="protondrive-gui_0.1.0_all.deb"

echo "Construction du paquet .deb..."
dpkg-deb --build package_root "$DEBNAME"

echo "Paquet créé : $DEBNAME"
echo "Tester l'installation : sudo apt install -f ./$DEBNAME  (ou sudo dpkg -i ./$DEBNAME && sudo apt -f install)"
