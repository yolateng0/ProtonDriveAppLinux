#!/usr/bin/env bash
set -Eeuo pipefail

SERVICE_NAME="rclone-proton.service"

if [[ "${EUID}" -eq 0 ]]; then
    echo "[ERREUR] Ne lancez pas ce script avec sudo." >&2
    exit 1
fi

if [[ -z "${HOME:-}" || "${HOME}" == "/" ]]; then
    echo "[ERREUR] HOME absent ou invalide ; désinstallation annulée." >&2
    exit 1
fi

for cmd in systemctl mountpoint; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[ERREUR] Commande requise introuvable : $cmd" >&2
        exit 1
    fi
done

UNIT_FILE="${HOME}/.config/systemd/user/${SERVICE_NAME}"
MOUNT_POINT="${HOME}/ProtonDrive"
RCLONE_CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/rclone"

# Vérifications pour éviter une suppression accidentelle d'un chemin inattendu.
if [[ "$MOUNT_POINT" != "${HOME}/ProtonDrive" ||
      "$RCLONE_CONFIG_DIR" != "${HOME}/.config/rclone" &&
      "$RCLONE_CONFIG_DIR" != "${XDG_CONFIG_HOME}/rclone" ]]; then
    echo "[ERREUR] Chemin de suppression inattendu ; opération annulée." >&2
    exit 1
fi

if ! systemctl --user show-environment >/dev/null 2>&1; then
    echo "[ERREUR] Impossible de contacter systemd utilisateur." >&2
    echo "Ouvrez une session utilisateur et relancez le script sans sudo." >&2
    exit 1
fi

echo "Les éléments suivants seront supprimés :"
echo "  Service : ${SERVICE_NAME}"
echo "  Configuration rclone : ${RCLONE_CONFIG_DIR}"
echo "  Dossier de montage local : ${MOUNT_POINT}"
echo
echo "La suppression de la configuration rclone effacera tous les remotes qu'elle contient."
echo "Vérifiez que ${MOUNT_POINT} ne contient pas de fichiers locaux à conserver."
read -r -p "Pour confirmer, tapez SUPPRIMER : " answer

if [[ "$answer" != "SUPPRIMER" ]]; then
    echo "Désinstallation annulée."
    exit 0
fi

echo "Arrêt et désactivation du service…"
systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true
systemctl --user disable "$SERVICE_NAME" >/dev/null 2>&1 || true

if mountpoint -q -- "$MOUNT_POINT"; then
    echo "Démontage de ${MOUNT_POINT}…"

    if command -v fusermount3 >/dev/null 2>&1; then
        fusermount3 -u -- "$MOUNT_POINT"
    elif command -v fusermount >/dev/null 2>&1; then
        fusermount -u -- "$MOUNT_POINT"
    else
        echo "[ERREUR] fusermount3/fusermount introuvable ; suppression annulée." >&2
        exit 1
    fi

    if mountpoint -q -- "$MOUNT_POINT"; then
        echo "[ERREUR] Le point est toujours monté ; suppression des données annulée." >&2
        exit 1
    fi
fi

if [[ -f "$UNIT_FILE" || -L "$UNIT_FILE" ]]; then
    rm -f -- "$UNIT_FILE"
fi

systemctl --user daemon-reload
systemctl --user reset-failed "$SERVICE_NAME" >/dev/null 2>&1 || true

if [[ -d "$RCLONE_CONFIG_DIR" && ! -L "$RCLONE_CONFIG_DIR" ]]; then
    rm -rf -- "$RCLONE_CONFIG_DIR"
elif [[ -e "$RCLONE_CONFIG_DIR" || -L "$RCLONE_CONFIG_DIR" ]]; then
    rm -f -- "$RCLONE_CONFIG_DIR"
fi

if [[ -d "$MOUNT_POINT" && ! -L "$MOUNT_POINT" ]]; then
    rm -rf -- "$MOUNT_POINT"
elif [[ -e "$MOUNT_POINT" || -L "$MOUNT_POINT" ]]; then
    rm -f -- "$MOUNT_POINT"
fi

echo "Désinstallation terminée : service, configuration rclone et dossier ProtonDrive supprimés."
