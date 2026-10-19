#!/usr/bin/env bash
set -Eeuo pipefail

SERVICE_NAME="rclone-proton.service"

if [[ "${EUID}" -eq 0 ]]; then
    echo "[ERROR] Do not run this script with sudo." >&2
    exit 1
fi

if [[ -z "${HOME:-}" || "${HOME}" == "/" ]]; then
    echo "[ERROR] HOME is missing or invalid; uninstall canceled." >&2
    exit 1
fi

for cmd in systemctl mountpoint; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[ERROR] Required command not found: $cmd" >&2
        exit 1
    fi
done

UNIT_FILE="${HOME}/.config/systemd/user/${SERVICE_NAME}"
MOUNT_POINT="${HOME}/ProtonDrive"
CONFIG_BASE="${XDG_CONFIG_HOME:-${HOME}/.config}"
RCLONE_CONFIG_DIR="${CONFIG_BASE}/rclone"

if ! systemctl --user show-environment >/dev/null 2>&1; then
    echo "[ERROR] Cannot contact the user systemd instance." >&2
    echo "Log in to your user session, then rerun this script without sudo." >&2
    exit 1
fi

echo "The following items will be removed:"
echo "  Service: ${SERVICE_NAME}"
echo "  rclone configuration directory: ${RCLONE_CONFIG_DIR}"
echo "  Local mount directory: ${MOUNT_POINT}"
echo
echo "Removing the rclone configuration will delete every remote configured there."
echo "Make sure ${MOUNT_POINT} contains no local files you want to keep."
read -r -p "Type DELETE to confirm: " answer

if [[ "$answer" != "DELETE" ]]; then
    echo "Uninstall canceled."
    exit 0
fi

echo "Stopping and disabling the service..."
systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true
systemctl --user disable "$SERVICE_NAME" >/dev/null 2>&1 || true

if mountpoint -q -- "$MOUNT_POINT"; then
    echo "Unmounting ${MOUNT_POINT}..."

    if command -v fusermount3 >/dev/null 2>&1; then
        fusermount3 -u -- "$MOUNT_POINT"
    elif command -v fusermount >/dev/null 2>&1; then
        fusermount -u -- "$MOUNT_POINT"
    else
        echo "[ERROR] Neither fusermount3 nor fusermount was found; uninstall canceled." >&2
        exit 1
    fi

    if mountpoint -q -- "$MOUNT_POINT"; then
        echo "[ERROR] The mount is still active; data removal canceled." >&2
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

echo "Uninstall complete: the service, rclone configuration, and ProtonDrive directory have been removed."
