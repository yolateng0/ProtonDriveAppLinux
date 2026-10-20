# ProtonDrive GUI prototype

This package provides a lightweight GTK3 desktop app prototype for managing a Proton Drive mount on Debian.

It contains:
- a minimal application launcher (/usr/bin/protondrive-gui)
- the GTK3 Python logic (/usr/lib/protondrive/gui.py)
- a desktop entry (/usr/share/applications/protondrive-gui.desktop)
- a scalable icon (/usr/share/icons/hicolor/scalable/apps/protondrive-gui.svg)
- Debian maintenance scripts for icon and desktop database refresh

Quick usage:
1. sudo dpkg -i protondrive-gui_0.1.0_all.deb
2. /usr/bin/protondrive-gui

The app is meant to help validate the ProtonDrive backend, the presence of rclone and the local service status.
