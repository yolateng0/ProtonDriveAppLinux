#!/usr/bin/env bash
set -Eeuo pipefail

SERVICE_NAME="rclone-proton.service"

if [[ "${EUID}" -eq 0 ]]; then
    echo "[ERREUR] Ne lancez pas ce script avec sudo." >&2
    exit 1
fi

if [[ -z "${HOME:-}" || "${HOME}" == "/" ]]; then
    echo "[ERREUR] Répertoire HOME absent ou invalide ; désinstallation annulée." >&2
    exit 1
fi

UNIT_DIR="${HOME}/.config/systemd/user"
UNIT_FILE="${UNIT_DIR}/${SERVICE_NAME}"
MOUNT_POINT="${HOME}/ProtonDrive"

if ! command -v systemctl >/dev/null 2>&1; then
    echo "[ERREUR] systemctl est introuvable ; désinstallation annulée." >&2
    exit 1
fi

if ! systemctl --user show-environment >/dev/null 2>&1; then
    echo "[ERREUR] Impossible de contacter systemd utilisateur." >&2
    echo "Ouvrez une session utilisateur, puis relancez ce script sans sudo." >&2
    exit 1
fi

echo "Arrêt du service ${SERVICE_NAME}…"
systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true
systemctl --user disable "$SERVICE_NAME" >/dev/null 2>&1 || true

if mountpoint -q -- "$MOUNT_POINT"; then
    echo "Démontage de ${MOUNT_POINT}…"

    if command -v fusermount3 >/dev/null 2>&1; then
        fusermount3 -u -- "$MOUNT_POINT"
    elif command -v fusermount >/dev/null 2>&1; then
        fusermount -u -- "$MOUNT_POINT"
    else
        echo "[ERREUR] Point de montage encore actif et fusermount introuvable." >&2
        echo "Le fichier du service est conservé. Démontez le point de montage, puis relancez le script." >&2
        exit 1
    fi

    if mountpoint -q -- "$MOUNT_POINT"; then
        echo "[ERREUR] Le point de montage est toujours actif." >&2
        echo "Le fichier du service est conservé. Démontez-le, puis relancez le script." >&2
        exit 1
    fi
fi

if [[ -f "$UNIT_FILE" || -L "$UNIT_FILE" ]]; then
    rm -f -- "$UNIT_FILE"
fi

systemctl --user daemon-reload
systemctl --user reset-failed "$SERVICE_NAME" >/dev/null 2>&1 || true

echo "Désinstallation terminée."
echo "Le service a été retiré."
echo "Le dossier ${MOUNT_POINT}, la configuration rclone et les journaux ont été conservés."
