Prototype GTK3 pour ProtonDrive — branche test-gui-deb-gtk3

Ce squelette propose :
- un GUI minimal en Python3 + PyGObject (GTK3) placé dans /usr/lib/protondrive/gui.py
- un wrapper exécutable /usr/bin/protondrive-gui
- fichiers Debian (DEBIAN/control, postinst, prerm)
- icône vectorielle scalable et génération optionnelle de PNG via rsvg-convert ou ImageMagick
- build.sh pour générer le .deb

Instructions rapides :
1) Installer les dépendances de build et d'exécution :
   sudo apt update
   sudo apt install python3 python3-gi gir1.2-gtk-3.0 dpkg-deb rsvg-convert lintian

2) Construire :
   ./package_root/build.sh

3) Installer :
   sudo dpkg -i protondrive-gui_0.1.0_all.deb || true
   sudo apt -f install

4) Lancer :
   /usr/bin/protondrive-gui

Remarques :
- Le programme tente d'appeler une commande CLI nommée "protondrive" (via shutil.which) pour démontrer l'interaction backend. Si vous possédez une CLI différente ou des sous-commandes spécifiques, fournissez-les et je l'intégrerai.
- Les scripts postinst/prerm mettent à jour la base de données des applications et le cache d'icônes.
- Pour un packaging plus complet (conformité Lintian), il faudra ajouter des fichiers de documentation (usr/share/doc/*), déclarer correctement les licences et fournir un copyright.
