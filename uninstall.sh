#!/usr/bin/env bash
set -Eeuo pipefail

SERVICE_NAME="rclone-proton.service"
UNIT_FILE="$HOME/.config/systemd/user/$SERVICE_NAME"
MOUNT_POINT="$HOME/ProtonDrive"

[[ "$EUID" -ne 0 ]] || {
    echo "[ERROR] Do not run this script with sudo." >&2
    exit 1
}

if systemctl --user is-active --quiet "$SERVICE_NAME"; then
    systemctl --user stop "$SERVICE_NAME"
fi

systemctl --user disable "$SERVICE_NAME" >/dev/null 2>&1 || true

if command -v fusermount3 >/dev/null 2>&1 && mountpoint -q "$MOUNT_POINT"; then
    fusermount3 -u "$MOUNT_POINT" || true
fi

rm -f "$UNIT_FILE"
systemctl --user daemon-reload
systemctl --user reset-failed "$SERVICE_NAME" >/dev/null 2>&1 || true

echo "Service removed. The $MOUNT_POINT directory and rclone configuration were kept."
