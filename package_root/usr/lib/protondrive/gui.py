#!/usr/bin/env python3
# -*- coding: utf-8 -*-
from gi.repository import Gtk
import subprocess
import shutil
import os

class MainWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="ProtonDrive")
        self.set_default_size(400, 200)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.set_border_width(10)

        self.status_label = Gtk.Label(label="Statut: inconnu")
        box.pack_start(self.status_label, False, False, 0)

        check_button = Gtk.Button(label="Vérifier ProtonDrive")
        check_button.connect("clicked", self.on_check_clicked)
        box.pack_start(check_button, False, False, 0)

        quit_button = Gtk.Button(label="Quitter")
        quit_button.connect("clicked", Gtk.main_quit)
        box.pack_end(quit_button, False, False, 0)

        self.add(box)

    def on_check_clicked(self, widget):
        # Tentative d'appel d'une commande "protondrive" si disponible
        cmd = shutil.which("protondrive")
        if cmd is None:
            self.status_label.set_text("ProtonDrive CLI non trouvé sur le PATH")
            return
        try:
            p = subprocess.run([cmd, "status"], capture_output=True, text=True, timeout=10)
            if p.returncode == 0:
                out = p.stdout.strip() or "OK"
                self.status_label.set_text(f"ProtonDrive: {out}")
            else:
                self.status_label.set_text(f"Erreur ({p.returncode}): {p.stderr.strip()}")
        except Exception as e:
            self.status_label.set_text(f"Échec exécution: {e}")

def main():
    win = MainWindow()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()

if __name__ == '__main__':
    main()
