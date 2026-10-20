#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import shutil
import subprocess
from pathlib import Path

try:
    from gi.repository import GLib, Gtk
except ImportError as exc:  # pragma: no cover - only for runtime environment
    raise SystemExit(
        "PyGObject / GTK3 is required. Install: sudo apt install python3-gi gir1.2-gtk-3.0"
    ) from exc


class ProtonDriveWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="ProtonDrive")
        self.set_default_size(520, 320)
        self.set_position(Gtk.WindowPosition.CENTER)

        self.config_path = Path(os.environ.get("RCLONE_CONFIG", os.path.expanduser("~/.config/rclone/rclone.conf")))
        self.mount_path = Path(os.path.expanduser("~/ProtonDrive"))

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        vbox.set_border_width(16)

        header = Gtk.Label()
        header.set_markup("<b>ProtonDrive</b>\n<small>GTK3 desktop prototype</small>")
        header.set_line_wrap(True)
        header.set_xalign(0)
        vbox.pack_start(header, False, False, 0)

        self.status_label = Gtk.Label()
        self.status_label.set_selectable(True)
        self.status_label.set_line_wrap(True)
        self.status_label.set_xalign(0)
        self.status_label.set_markup("<span foreground='gray'>Vérification du statut…</span>")
        vbox.pack_start(self.status_label, False, False, 0)

        self.info_label = Gtk.Label()
        self.info_label.set_selective(True)
        self.info_label.set_line_wrap(True)
        self.info_label.set_xalign(0)
        vbox.pack_start(self.info_label, False, False, 0)

        actions = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        actions.set_homogeneous(True)

        check_button = Gtk.Button(label="Vérifier")
        check_button.connect("clicked", self.on_check_clicked)
        actions.pack_start(check_button, True, True, 0)

        mount_button = Gtk.Button(label="Ouvrir le dossier")
        mount_button.connect("clicked", self.on_open_mount)
        actions.pack_start(mount_button, True, True, 0)

        start_button = Gtk.Button(label="Démarrer")
        start_button.connect("clicked", self.on_start_service)
        actions.pack_start(start_button, True, True, 0)

        stop_button = Gtk.Button(label="Arrêter")
        stop_button.connect("clicked", self.on_stop_service)
        actions.pack_start(stop_button, True, True, 0)

        vbox.pack_start(actions, False, False, 0)

        self.textview = Gtk.TextView()
        self.textview.set_editable(False)
        self.textview.set_wrap_mode(Gtk.WrapMode.WORD)
        self.textview.set_size_request(-1, 110)
        buffer = self.textview.get_buffer()
        buffer.set_text("Le tableau de bord permet de vérifier rapidement la présence de rclone, le point de montage et l'état du service systemd utilisateur.")
        vbox.pack_start(self.textview, True, True, 0)

        quit_button = Gtk.Button(label="Quitter")
        quit_button.connect("clicked", Gtk.main_quit)
        vbox.pack_end(quit_button, False, False, 0)

        self.add(vbox)
        self.connect("destroy", Gtk.main_quit)
        self.update_status()

    def _run(self, command):
        try:
            completed = subprocess.run(command, capture_output=True, text=True, timeout=20)
            return completed.returncode, completed.stdout.strip(), completed.stderr.strip()
        except FileNotFoundError:
            return 127, "", "Commande introuvable."
        except subprocess.TimeoutExpired:
            return 124, "", "La commande a dépassé le délai autorisé."

    def _set_status(self, text, color="gray"):
        self.status_label.set_markup(f"<span foreground='{color}'>{text}</span>")

    def update_status(self):
        remote_ok = False
        if self.config_path.exists():
            rc, out, err = self._run(["rclone", "listremotes", "--config", str(self.config_path)])
            remote_ok = rc == 0 and "proton:" in (out or "")

        if shutil.which("rclone") is None:
            self._set_status("rclone n'est pas installé ou non présent dans le PATH.", "red")
            self.info_label.set_text("Installez rclone pour pouvoir utiliser Proton Drive.")
            self._log("rclone absent")
            return

        if self.config_path.exists():
            rc, out, err = self._run(["rclone", "listremotes", "--config", str(self.config_path)])
            if rc == 0:
                remotes = (out or "").splitlines()
                if remotes:
                    self.info_label.set_text("Remotes connus : " + ", ".join(remotes[:5]))
                else:
                    self.info_label.set_text("Aucun remote configuré dans le fichier de configuration.")
            else:
                self.info_label.set_text(err or "Impossible de lire la configuration rclone.")
        else:
            self.info_label.set_text("Fichier de config rclone absent : " + str(self.config_path))

        if remote_ok:
            self._set_status("Proton Drive est configuré et accessible.", "darkgreen")
        else:
            self._set_status("Le remote 'proton' n'est pas encore disponible.", "orange")

        if self.mount_path.exists():
            self._log(f"Dossier de montage existant : {self.mount_path}")

    def _log(self, text):
        buffer = self.textview.get_buffer()
        start = buffer.get_start_iter()
        end = buffer.get_end_iter()
        current = buffer.get_text(start, end, False)
        lines = current.splitlines()
        if len(lines) > 15:
            lines = lines[-15:]
        lines.append(text)
        buffer.set_text("\n".join(lines))

    def on_check_clicked(self, _widget):
        self.update_status()
        rc, out, err = self._run(["rclone", "lsd", "proton:", "--config", str(self.config_path)])
        if rc == 0:
            self._set_status("Connexion Proton Drive OK.", "darkgreen")
            self.info_label.set_text(out[:300] if out else "Le remote Proton répond correctement.")
            self._log("rclone lsd proton: OK")
        else:
            self._set_status("Impossible de lancer la vérification Proton Drive.", "red")
            self.info_label.set_text(err or "Le remote 'proton' est absent ou inaccessible.")
            self._log(f"rclone lsd proton: {err or 'échec'}")

    def on_open_mount(self, _widget):
        mount = str(self.mount_path)
        if self.mount_path.exists():
            subprocess.Popen(["xdg-open", mount])
            self._log(f"Ouverture du dossier : {mount}")
        else:
            self._set_status("Le point de montage n'existe pas encore.", "orange")
            self.info_label.set_text("Créez d'abord le montage Proton Drive via le script d'installation.")

    def _service_state(self):
        rc, out, err = self._run(["systemctl", "--user", "is-active", "rclone-proton.service"])
        if rc == 0:
            return "actif"
        if rc == 3:
            return "inactif"
        return "inconnu"

    def on_start_service(self, _widget):
        rc, out, err = self._run(["systemctl", "--user", "start", "rclone-proton.service"])
        if rc == 0:
            self._set_status("Service démarré.", "darkgreen")
            self._log("systemctl --user start rclone-proton.service")
        else:
            self._set_status("Le service n'a pas pu démarrer.", "red")
            self.info_label.set_text(err or out or "Service inaccessible.")
            self._log((err or out or "Erreur démarrage service").strip())

    def on_stop_service(self, _widget):
        rc, out, err = self._run(["systemctl", "--user", "stop", "rclone-proton.service"])
        if rc == 0:
            self._set_status("Service arrêté.", "orange")
            self._log("systemctl --user stop rclone-proton.service")
        else:
            self._set_status("Le service n'a pas pu être arrêté.", "red")
            self.info_label.set_text(err or out or "Impossible d'arrêter le service.")
            self._log((err or out or "Erreur arrêt service").strip())


def main():
    app = Gtk.Application(application_id="fr.protondrive.gui")

    def activate(app):
        win = ProtonDriveWindow()
        win.show_all()

    app.connect("activate", activate)
    app.run()


if __name__ == "__main__":
    main()
