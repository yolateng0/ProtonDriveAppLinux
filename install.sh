#!/usr/bin/env bash
set -Eeuo pipefail

REMOTE_NAME="proton"
MOUNT_POINT="$HOME/ProtonDrive"
CACHE_DIR="$HOME/.cache/rclone"
LOG_FILE="$CACHE_DIR/rclone-proton.log"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT_FILE="$UNIT_DIR/rclone-proton.service"
SERVICE_NAME="rclone-proton.service"
USER_NAME="$(id -un)"

RECONFIGURE=0

die() {
    echo
    echo "[ERREUR] $*" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: ./install.sh [OPTION]

Options:
  --reconfigure  Ouvre rclone config pour créer ou modifier le remote Proton.
  --help, -h     Affiche ce message.
EOF
}

case "${1:-}" in
    "")
        ;;
    --reconfigure)
        RECONFIGURE=1
        ;;
    --help|-h)
        usage
        exit 0
        ;;
    *)
        usage >&2
        die "Option inconnue : $1"
        ;;
esac

# Ne pas exécuter ce script en root : le remote et le service
# systemd doivent appartenir au compte utilisateur courant.
[[ "$EUID" -ne 0 ]] || die "Ne lancez pas ce script avec sudo. Utilisez ./install.sh."

command -v sudo >/dev/null 2>&1 \
    || die "sudo est nécessaire pour installer les paquets."
command -v systemctl >/dev/null 2>&1 \
    || die "systemctl est introuvable."
systemctl --user show-environment >/dev/null 2>&1 \
    || die "Le gestionnaire systemd utilisateur n'est pas disponible dans cette session."

echo "=== Installation de rclone pour Proton Drive ==="
echo "Utilisateur Linux : $USER_NAME"
echo

echo "[1/6] Installation des dépendances Debian..."
sudo apt-get update
sudo apt-get install -y curl fuse3

echo
echo "[2/6] Installation ou mise à jour de rclone..."
INSTALLER="$(mktemp)"
trap 'rm -f "$INSTALLER"' EXIT

curl --fail --silent --show-error \
    https://rclone.org/install.sh \
    --output "$INSTALLER"

sudo bash "$INSTALLER"

RCLONE_BIN="$(command -v rclone)" \
    || die "rclone est introuvable après l'installation."

FUSERMOUNT_BIN="$(command -v fusermount3 || command -v fusermount)" \
    || die "fusermount3 est introuvable. Vérifiez l'installation de fuse3."

echo
echo "Version de rclone installée :"
rclone version
echo

REMOTE_EXISTS=0
if rclone listremotes | grep -Fxq "${REMOTE_NAME}:"; then
    REMOTE_EXISTS=1
fi

RUN_CONFIG=0

if [[ "$RECONFIGURE" -eq 1 ]]; then
    RUN_CONFIG=1
elif [[ "$REMOTE_EXISTS" -eq 0 ]]; then
    RUN_CONFIG=1
else
    echo "Le remote '${REMOTE_NAME}:' existe déjà."
    read -r -p "Voulez-vous ouvrir rclone config pour le modifier ? [y/N] " EDIT_CONFIG

    if [[ "$EDIT_CONFIG" =~ ^[Yy]$ ]]; then
        RUN_CONFIG=1
    fi
fi

if [[ "$RUN_CONFIG" -eq 1 ]]; then
    echo
    echo "[3/6] Ouverture de l'assistant rclone config"
    cat <<'INFO'

Dans l'assistant rclone :
  - Pour créer le remote, choisissez l'option de nouveau remote.
  - Nommez-le : proton
  - Choisissez le stockage : protondrive
  - Pour modifier un remote existant, sélectionnez son édition.
  - Suivez les demandes d'authentification affichées.
  - Si votre compte Proton utilise deux mots de passe, indiquez aussi
    le mot de passe de boîte aux lettres dans les options avancées.

Saisissez vos identifiants dans l'assistant rclone, pas dans ce script.
INFO
    echo
    rclone config
else
    echo "[3/6] Configuration existante conservée."
fi

rclone listremotes | grep -Fxq "${REMOTE_NAME}:" \
    || die "Remote '${REMOTE_NAME}:' introuvable. Créez-le avec le nom 'proton' dans rclone config."

echo
echo "[4/6] Test de la connexion à Proton Drive..."
rclone lsd "${REMOTE_NAME}:" \
    || die "Connexion à Proton Drive impossible. Vérifiez le remote avec : rclone config"

echo
echo "[5/6] Création ou mise à jour du service systemd utilisateur..."
mkdir -p "$MOUNT_POINT" "$CACHE_DIR" "$UNIT_DIR"

cat > "$UNIT_FILE" <<EOF
[Unit]
Description=Montage Proton Drive avec rclone
Wants=network-online.target
After=network-online.target

[Service]
Type=notify
ExecStart=$RCLONE_BIN mount ${REMOTE_NAME}: %h/ProtonDrive \\
    --vfs-cache-mode=full \\
    --vfs-cache-max-size=500M \\
    --vfs-cache-max-age=1h \\
    --dir-cache-time=5m \\
    --protondrive-enable-caching=false \\
    --cache-dir=%h/.cache/rclone \\
    --log-level=INFO \\
    --log-file=%h/.cache/rclone/rclone-proton.log \\
    --umask=022
ExecStop=$FUSERMOUNT_BIN -u %h/ProtonDrive
Restart=on-failure
RestartSec=10
TimeoutStopSec=30

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable "$SERVICE_NAME"

if systemctl --user is-active --quiet "$SERVICE_NAME"; then
    echo "Redémarrage du service existant..."
    systemctl --user restart "$SERVICE_NAME"
else
    echo "Démarrage du service..."
    systemctl --user start "$SERVICE_NAME"
fi

echo
read -r -p "Démarrer le service au démarrage, même sans connexion à votre session ? [y/N] " ENABLE_LINGER

if [[ "$ENABLE_LINGER" =~ ^[Yy]$ ]]; then
    sudo loginctl enable-linger "$USER_NAME"
    echo "Démarrage au boot activé pour $USER_NAME."
fi

echo
echo "[6/6] État du service..."
systemctl --user --no-pager --full status "$SERVICE_NAME" || true

echo
echo "Installation terminée."
echo "Point de montage : $MOUNT_POINT"
echo
echo "Commandes utiles :"
echo "  Arrêter       : systemctl --user stop $SERVICE_NAME"
echo "  Redémarrer    : systemctl --user restart $SERVICE_NAME"
echo "  Voir les logs : journalctl --user -u $SERVICE_NAME -f"
