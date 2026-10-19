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

die() {
    echo "[ERROR] $*" >&2
    exit 1
}

[[ "$EUID" -ne 0 ]] || die "Do not run this script with sudo. Run ./install.sh as your regular user."

command -v sudo >/dev/null 2>&1 || die "sudo is required to install packages."
command -v systemctl >/dev/null 2>&1 || die "systemctl was not found."
systemctl --user is-system-running >/dev/null 2>&1 \
    || die "The systemd user manager is not available in this session."

echo "=== Installing rclone for Proton Drive ==="
echo "Linux user: $USER_NAME"
echo

echo "[1/5] Installing dependencies..."
sudo apt-get update
sudo apt-get install -y curl fuse3

echo
echo "[2/5] Installing or updating rclone..."
INSTALLER="$(mktemp)"
trap 'rm -f "$INSTALLER"' EXIT

curl --fail --silent --show-error https://rclone.org/install.sh --output "$INSTALLER"
sudo bash "$INSTALLER"

RCLONE_BIN="$(command -v rclone)" \
    || die "rclone was not found after installation."
FUSERMOUNT_BIN="$(command -v fusermount3 || command -v fusermount)" \
    || die "fusermount3 was not found. Check your fuse3 installation."

rclone version
echo

if rclone listremotes | grep -Fxq "${REMOTE_NAME}:"; then
    echo "[3/5] The '${REMOTE_NAME}:' remote already exists."
    read -r -p "Open rclone config to review or change it? [y/N] " EDIT_CONFIG

    if [[ "$EDIT_CONFIG" =~ ^[Yy]$ ]]; then
        rclone config
    fi
else
    echo "[3/5] Configure the Proton Drive remote"
    cat <<'INFO'

The rclone configuration wizard will open.

In the wizard:
  1. Create a new remote.
  2. Name it: proton
  3. Select Proton Drive storage: protondrive
  4. Follow the prompts for account and authentication details.
  5. If your Proton account uses two passwords, also enter the mailbox
     password in the advanced options.

Enter your account details in the rclone wizard, not in this script.
INFO
    echo
    rclone config
fi

rclone listremotes | grep -Fxq "${REMOTE_NAME}:" \
    || die "Remote '${REMOTE_NAME}:' was not found. Run rclone config and name it proton."

echo
echo "[4/5] Testing the remote connection..."
rclone lsd "${REMOTE_NAME}:" \
    || die "Connection failed. Check your configuration with: rclone config"

echo
echo "[5/5] Creating and starting the systemd user service..."
mkdir -p "$MOUNT_POINT" "$CACHE_DIR" "$UNIT_DIR"

cat > "$UNIT_FILE" <<EOF
[Unit]
Description=Mount Proton Drive with rclone
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
systemctl --user enable --now "$SERVICE_NAME"

echo
read -r -p "Start the service at boot, even when you are not logged in? [y/N] " ENABLE_LINGER
if [[ "$ENABLE_LINGER" =~ ^[Yy]$ ]]; then
    sudo loginctl enable-linger "$USER_NAME"
    echo "Boot-time startup enabled for $USER_NAME."
fi

echo
echo "Installation complete."
echo "Mount point: $MOUNT_POINT"
echo "Service status:"
systemctl --user --no-pager --full status "$SERVICE_NAME" || true

echo
echo "View logs with: journalctl --user -u $SERVICE_NAME -f"
