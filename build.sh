#!/usr/bin/env bash
set -e

# Script simple pour construire le paquet .deb depuis package_root/
# Usage: ./build.sh

# Rendre exécutable le binaire
chmod +x package_root/usr/bin/protondrive-gui-gtk2

# Construire le paquet
DEBNAME="protondrive-gui-gtk2_0.1.0_all.deb"

dpkg-deb --build package_root "$DEBNAME"

echo "Paquet créé : $DEBNAME"

echo "Tester l'installation : sudo apt install -f ./$DEBNAME  (ou sudo dpkg -i ./$DEBNAME && sudo apt -f install)"
