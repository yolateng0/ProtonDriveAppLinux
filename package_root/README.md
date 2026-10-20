# ProtonDrive GUI prototype

This package provides a professional GTK3 desktop dashboard for ProtonDrive on Debian.

Included files:
- /usr/bin/protondrive-gui
- /usr/lib/protondrive/gui.py
- /usr/share/applications/protondrive-gui.desktop
- /usr/share/icons/hicolor/scalable/apps/protondrive-gui.svg
- /usr/share/metainfo/protondrive-gui.appdata.xml
- Debian maintainer scripts and documentation

Quick installation:
1. sudo dpkg -i protondrive-gui_0.1.0_all.deb
2. /usr/bin/protondrive-gui

The application checks the rclone configuration, Proton Drive remote, mount point and systemd user service status.
