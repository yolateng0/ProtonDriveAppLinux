#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import shutil
import subprocess
from pathlib import Path

try:
    from gi.repository import Gtk, GLib
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        "PyGObject / GTK3 is required. Install with: sudo apt install python3-gi gir1.2-gtk-3.0"
    ) from exc


class ProtonDriveWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="ProtonDrive")
        self.set_default_size(620, 430)
        self.set_position(Gtk.WindowPosition.CENTER)

        self.config_path = Path(
            os.environ.get("RCLONE_CONFIG", os.path.expanduser("~/.config/rclone/rclone.conf"))
        )
        self.mount_path = Path(os.path.expanduser("~/ProtonDrive"))
        self.service_name = "rclone-proton.service"

        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        main_box.set_border_width(18)

        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        icon = Gtk.Image.new_from_icon_name("protondrive-gui", Gtk.IconSize.DIALOG)
        title = Gtk.Label()
        title.set_markup("<span size='x-large' weight='bold'>ProtonDrive</span>\n<small>Desktop dashboard</small>")
        title.set_xalign(0)
        header.pack_start(icon, False, False, 0)
        header.pack_start(title, True, True, 0)
        main_box.pack_start(header, False, False, 0)

        self.status_label = Gtk.Label()
        self.status_label.set_xalign(0)
        self.status_label.set_line_wrap(True)
        self.status_label.set_markup("<span foreground='gray'>Vérification de l'état…</span>")
        main_box.pack_start(self.status_label, False, False, 0)

        self.summary_label = Gtk.Label()
        self.summary_label.set_xalign(0)
        self.summary_label.set_line_wrap(True)
        main_box.pack_start(self.summary_label, False, False, 0)

        action_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        action_box.set_homogeneous(True)

        refresh_btn = Gtk.Button(label="Vérifier")
        refresh_btn.connect("clicked", self.on_refresh)
        action_box.pack_start(refresh_btn, True, True, 0)

        start_btn = Gtk.Button(label="Démarrer")
        start_btn.connect("clicked", self.on_start_service)
        action_box.pack_start(start_btn, True, True, 0)

        stop_btn = Gtk.Button(label="Arrêter")
        stop_btn.connect("clicked", self.on_stop_service)
        action_box.pack_start(stop_btn, True, True, 0)

        open_btn = Gtk.Button(label="Ouvrir le dossier")
        open_btn.connect("clicked", self.on_open_mount)
        action_box.pack_start(open_btn, True, True, 0)

        main_box.pack_start(action_box, False, False, 0)

        grid = Gtk.Grid()
        grid.set_column_spacing(12)
        grid.set_row_spacing(8)

        labels = [
            ("Remote", "remote_value"),
            ("Service", "service_value"),
            ("Point de montage", "mount_value"),
            ("Configuration", "config_value"),
        ]

        for i, (title, key) in enumerate(labels):
            title_label = Gtk.Label()
            title_label.set_markup(f"<b>{title}</b>")
            title_label.set_xalign(0)
            value_label = Gtk.Label()
            value_label.set_xalign(0)
            value_label.set_line_wrap(True)
            setattr(self, key, value_label)
            grid.attach(title_label, 0, i, 1, 1)
            grid.attach(value_label, 1, i, 1, 1)

        main_box.pack_start(grid, False, False, 0)

        log_frame = Gtk.Frame(label="Journal")
        log_sw = Gtk.ScrolledWindow()
        log_sw.set_hexpand(True)
        log_sw.set_vexpand(True)
        self.log_buffer = Gtk.TextBuffer()
        self.log_buffer.set_text("Bienvenue dans le tableau de bord ProtonDrive.\n" +
                                 "Les vérifications sont automatiques et les commandes standard sont affichées ici.\n")
        log_view = Gtk.TextView(buffer=self.log_buffer)
        log_view.set_editable(False)
        log_view.set_cursor_visible(False)
        log_view.set_wrap_mode(Gtk.WrapMode.WORD)
        log_sw.add(log_view)
        log_frame.add(log_sw)
        main_box.pack_start(log_frame, True, True, 0)

        quit_btn = Gtk.Button(label="Quitter")
        quit_btn.connect("clicked", Gtk.main_quit)
        main_box.pack_end(quit_btn, False, False, 0)

        self.add(main_box)
        self.connect("destroy", Gtk.main_quit)
        self.refresh_status()
        GLib.timeout_add_seconds(15, self.refresh_status)

    def _log(self, text):
        end = self.log_buffer.get_end_iter()
        self.log_buffer.insert(end, text + "\n")
        self.log_buffer.get_start_iter()

    def _run(self, command):
        try:
            proc = subprocess.run(command, capture_output=True, text=True, timeout=20)
            return proc.returncode, (proc.stdout or "").strip(), (proc.stderr or "").strip()
        except FileNotFoundError:
            return 127, "", "Commande introuvable."
        except subprocess.TimeoutExpired:
            return 124, "", "La commande a dépassé le délai autorisé."

    def _set_status(self, text, color="gray"):
        self.status_label.set_markup(f"<span foreground='{color}'>{text}</span>")

    def _service_status(self):
        rc, stdout, stderr = self._run(["systemctl", "--user", "is-active", self.service_name])
        if rc == 0:
            return "actif"
        if rc == 3:
            return "inactif"
        return "inconnu"

    def refresh_status(self):
        rclone_found = shutil.which("rclone") is not None
        config_exists = self.config_path.exists()
        mount_exists = self.mount_path.exists()
        remote_ok = False
        remote_names = []

        if rclone_found:
            rc, out, err = self._run(["rclone", "listremotes", "--config", str(self.config_path)])
            if rc == 0:
                remote_names = [line.strip() for line in out.splitlines() if line.strip()]
                remote_ok = "proton:" in remote_names
            else:
                remote_names = []
                if config_exists:
                    self._log(f"rclone listremotes: {err or 'configuration invalide'}")
        else:
            self._log("rclone absent du PATH")

        service_state = self._service_status()

        if not rclone_found:
            self._set_status("rclone non installé ou absent du PATH", "red")
            self.summary_label.set_text("Installez rclone pour utiliser Proton Drive sur Debian.")
            self.remote_value.set_text("indisponible")
            self.service_value.set_text(service_state)
            self.mount_value.set_text("indisponible")
            self.config_value.set_text(str(self.config_path) if config_exists else "fichier absent")
            return True

        if remote_ok:
            self._set_status("Connexion Proton Drive OK", "darkgreen")
            self.summary_label.set_text("Le remote Proton est présent et prêt à être utilisé.")
        elif config_exists:
            self._set_status("Remote Proton non configuré", "orange")
            self.summary_label.set_text("Le fichier de configuration existe, mais le remote 'proton' manque.")
        else:
            self._set_status("Configuration manquante", "orange")
            self.summary_label.set_text("Créez la configuration rclone ou exécutez le script d'installation.")

        self.remote_value.set_text(", ".join(remote_names) if remote_names else "aucun remote")
        self.service_value.set_text(service_state)
        self.mount_value.set_text("OK" if mount_exists else "absent")
        self.config_value.set_text(str(self.config_path) if config_exists else "fichier absent")

        if mount_exists:
            self._log(f"Point de montage détecté : {self.mount_path}")

        return True

    def on_refresh(self, _widget):
        self._log("Vérification manuelle démarrée")
        self.refresh_status()

    def on_start_service(self, _widget):
        rc, out, err = self._run(["systemctl", "--user", "start", self.service_name])
        if rc == 0:
            self._set_status("Service démarré", "darkgreen")
            self._log("systemctl --user start rclone-proton.service")
        else:
            self._set_status("Démarrage du service impossible", "red")
            self._log(err or out or "Erreur lors du démarrage du service")
            self.summary_label.set_text(err or out or "Le service ne s'est pas démarré.")
        self.refresh_status()

    def on_stop_service(self, _widget):
        rc, out, err = self._run(["systemctl", "--user", "stop", self.service_name])
        if rc == 0:
            self._set_status("Service arrêté", "orange")
            self._log("systemctl --user stop rclone-proton.service")
        else:
            self._set_status("Arrêt du service impossible", "red")
            self._log(err or out or "Erreur lors de l'arrêt du service")
            self.summary_label.set_text(err or out or "Le service n'a pas pu être arrêté.")
        self.refresh_status()

    def on_open_mount(self, _widget):
        if self.mount_path.exists():
            opener = shutil.which("xdg-open") or shutil.which("gio")
            if opener:
                if opener.endswith("gio"):
                    subprocess.Popen([opener, "open", str(self.mount_path)])
                else:
                    subprocess.Popen([opener, str(self.mount_path)])
                self._log(f"Ouverture du point de montage : {self.mount_path}")
            else:
                self._log("Aucun outil d'ouverture de dossier disponible")
        else:
            self._set_status("Point de montage absent", "orange")
            self.summary_label.set_text("Le dossier ~/ProtonDrive n'existe pas encore.")


def main():
    app = Gtk.Application(application_id="com.protondrive.desktop")

    def activate(app):
        win = ProtonDriveWindow()
        win.show_all()

    app.connect("activate", activate)
    app.run()


if __name__ == "__main__":
    main()
