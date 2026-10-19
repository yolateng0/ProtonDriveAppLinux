Prototype GTK2 pour ProtonDrive — branche test-gui-deb-gtk2

Ce dépôt contient un prototype minimal empaqueté en .deb (squelette) basé sur GTK2 (PyGTK).

Fichiers inclus (dans package_root/):
- DEBIAN/control  : métadonnées du paquet
- usr/bin/protondrive-gui-gtk2 : script Python2 (PyGTK) qui lance une fenêtre et un bouton
- usr/share/applications/protondrive-gui-gtk2.desktop : entrée menu
- usr/share/icons/hicolor/scalable/apps/protondrive-gui-gtk2.svg : icône placeholder

Pour construire le .deb (sur une machine Debian/Ubuntu avec dpkg-deb installé) :

1) Installer les dépendances d'exécution (sur la machine cible) :
   sudo apt install python python-gtk2

2) Construire :
   ./build.sh

3) Installer pour tester :
   sudo apt install -f ./protondrive-gui-gtk2_0.1.0_all.deb
   # ou
   sudo dpkg -i ./protondrive-gui-gtk2_0.1.0_all.deb && sudo apt -f install

Notes :
- Ce prototype utilise Python 2 + PyGTK (GTK2). Sur de nombreuses distributions, GTK2/PyGTK est obsolète. Si vous préférez GTK3, dites-le et je créerai la version PyGObject/GTK3.
- Le paquet est un squelette de démonstration. Adaptez les chemins, dépendances et scripts selon vos besoins.
