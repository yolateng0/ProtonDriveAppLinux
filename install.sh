#!/usr/bin/env bash

set -Eeuo pipefail

REMOTE_NAME="proton"
SERVICE_NAME="rclone-proton.service"
USER_NAME="$(id -un)"
MOUNT_POINT="${HOME}/ProtonDrive"
CONFIG_BASE="${XDG_CONFIG_HOME:-${HOME}/.config}"
RCLONE_CONFIG="${RCLONE_CONFIG:-${CONFIG_BASE}/rclone/rclone.conf}"
CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/rclone-proton"
UNIT_DIR="${CONFIG_BASE}/systemd/user"
UNIT_FILE="${UNIT_DIR}/${SERVICE_NAME}"

# Tunable through the environment, e.g.: VFS_CACHE_MAX_SIZE=2G ./install.sh --repair
VFS_CACHE_MAX_SIZE="${VFS_CACHE_MAX_SIZE:-500M}"
VFS_CACHE_MAX_AGE="${VFS_CACHE_MAX_AGE:-1h}"
DIR_CACHE_TIME="${DIR_CACHE_TIME:-5m}"

RECONFIGURE=0
REINSTALL_RCLONE=0
RESET_PROTON=0
ASSUME_YES=0

die() {
    printf '\n[ERROR] %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: ./install.sh [OPTION...]

Options:
  --repair             Reinstall or update rclone and recreate the user service.
                       Keeps the existing rclone configuration.
  --reconfigure        Open the rclone configuration wizard.
  --reset-proton       Back up the rclone config, remove only the "proton" remote,
                       clear this mount's cache, then run the wizard.
  --reinstall-rclone   Reinstall or update rclone using the official installer.
  --yes, -y            Answer "yes" to confirmation prompts (reset, startup
                       without login session). If the remote already exists,
                       the wizard is not opened unless --reconfigure is given.
  --help, -h           Show this help message.

Options can be combined. For example:
  ./install.sh --reinstall-rclone --reconfigure

Environment variables (optional):
  VFS_CACHE_MAX_SIZE   Maximum VFS cache size (default: 500M)
  VFS_CACHE_MAX_AGE    Maximum age of cached files (default: 1h)
  DIR_CACHE_TIME       Directory listing cache duration (default: 5m)
EOF
}

confirm() {
    local prompt="$1"
    local answer

    if [[ "$ASSUME_YES" -eq 1 ]]; then
        return 0
    fi

    [[ -t 0 ]] || die "Interactive confirmation required (or use --yes): $prompt"
    read -r -p "$prompt [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

while (($#)); do
    case "$1" in
        --repair)
            REINSTALL_RCLONE=1
            ;;
        --reconfigure)
            RECONFIGURE=1
            ;;
        --reset-proton)
            RESET_PROTON=1
            RECONFIGURE=1
            ;;
        --reinstall-rclone)
            REINSTALL_RCLONE=1
            ;;
        --yes|-y)
            ASSUME_YES=1
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            usage >&2
            die "Unknown option: $1"
            ;;
    esac
    shift
done

[[ "$EUID" -ne 0 ]] || die "Do not run this script as root or with sudo. Run it as your regular user."
[[ -n "${HOME:-}" && "$HOME" != "/" ]] || die "HOME is missing or invalid."
[[ -r /etc/os-release ]] || die "Cannot identify the operating system."

# shellcheck disable=SC1091
. /etc/os-release

if [[ "${ID:-}" == "debian" ]] || [[ "${ID_LIKE:-}" =~ debian ]]; then
    :
else
    die "This script is intended for Debian or Debian-based systems."
fi

for cmd in sudo systemctl; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required but was not found."
done

# The generated systemd unit uses these paths directly in ExecStart.
# Whitespace and '%' (a systemd specifier) are refused rather than silently
# writing a unit that may not work.
for path in "$HOME" "$MOUNT_POINT" "$RCLONE_CONFIG" "$CACHE_DIR" "$UNIT_FILE"; do
    [[ "$path" != *[[:space:]%]* ]] \
        || die "Paths containing whitespace or '%' are not supported: $path"
done

systemctl --user show-environment >/dev/null 2>&1 \
    || die "The systemd user manager is unavailable. Log in to a normal user session and try again."

stop_existing_service() {
    if systemctl --user is-active --quiet "$SERVICE_NAME"; then
        echo "Stopping the existing user service..."
        systemctl --user stop "$SERVICE_NAME"
    fi
}

# Capture the list first: with "set -o pipefail", "rclone ... | grep -q" can
# fail spuriously when grep exits early and rclone receives SIGPIPE.
remote_exists() {
    local remotes
    remotes="$(rclone listremotes --config "$RCLONE_CONFIG" 2>/dev/null || true)"
    grep -Fxq "${REMOTE_NAME}:" <<<"$remotes"
}

echo "=== rclone Proton Drive setup ==="
echo "Linux user: $USER_NAME"
echo "rclone config: $RCLONE_CONFIG"
echo

stop_existing_service

echo "[1/6] Installing Debian dependencies..."
sudo apt-get update
sudo apt-get install -y curl fuse3

FUSERMOUNT_BIN="$(command -v fusermount3 || command -v fusermount || true)"
[[ -n "$FUSERMOUNT_BIN" ]] || die "fusermount3 or fusermount was not found. Check the fuse3 installation."

MKDIR_BIN="$(command -v mkdir)"

if [[ "$REINSTALL_RCLONE" -eq 1 ]] || ! command -v rclone >/dev/null 2>&1; then
    echo
    echo "[2/6] Installing or updating rclone with the official installer..."
    echo "      (the Debian package can be too old for the Proton Drive backend)"

    INSTALLER="$(mktemp)"
    trap 'rm -f -- "$INSTALLER"' EXIT

    curl --fail --silent --show-error --location \
        https://rclone.org/install.sh \
        --output "$INSTALLER"

    sudo bash "$INSTALLER"
    hash -r
else
    echo
    echo "[2/6] rclone is already installed. Keeping the current binary."
fi

RCLONE_BIN="$(command -v rclone || true)"
[[ -n "$RCLONE_BIN" ]] || die "rclone was not found after installation."

rclone version
echo

mkdir -p "$UNIT_DIR" "$MOUNT_POINT"

if [[ "$RESET_PROTON" -eq 1 ]]; then
    echo "This will remove the '$REMOTE_NAME' remote and clear this mount's cache."
    echo "Other rclone remotes will be kept."
    confirm "Continue with the Proton remote reset?" \
        || die "Reset canceled."

    if [[ -f "$RCLONE_CONFIG" ]]; then
        BACKUP_DIR="${CONFIG_BASE}/rclone-backups"
        BACKUP_FILE="${BACKUP_DIR}/rclone.conf.$(date +%Y%m%d-%H%M%S)"

        mkdir -p "$BACKUP_DIR"
        chmod 700 "$BACKUP_DIR"
        cp -p -- "$RCLONE_CONFIG" "$BACKUP_FILE"
        chmod 600 "$BACKUP_FILE"

        echo "Configuration backup created: $BACKUP_FILE"
    fi

    if remote_exists; then
        rclone config delete "$REMOTE_NAME" --config "$RCLONE_CONFIG"
    fi

    # Dedicated directory: the unit passes it to rclone as --cache-dir.
    rm -rf -- "$CACHE_DIR"
fi

REMOTE_EXISTS=0
if remote_exists; then
    REMOTE_EXISTS=1
fi

RUN_CONFIG="$RECONFIGURE"

if [[ "$REMOTE_EXISTS" -eq 0 ]]; then
    RUN_CONFIG=1
elif [[ "$RUN_CONFIG" -eq 0 && "$ASSUME_YES" -eq 0 ]]; then
    if confirm "The '${REMOTE_NAME}:' remote exists. Open rclone config to edit it?"; then
        RUN_CONFIG=1
    fi
fi

if [[ "$RUN_CONFIG" -eq 1 ]]; then
    [[ -t 0 ]] || die "The rclone configuration wizard requires an interactive terminal."

    echo
    echo "[3/6] Opening the rclone configuration wizard..."
    cat <<'INFO'

In the rclone wizard:

  - Create a new remote, or select the existing remote to edit.
  - Set the remote name to: proton
  - Select the storage type: protondrive
  - Follow the prompts to authenticate with Proton.
  - If your Proton account uses two passwords, configure the mailbox
    password in the advanced options.

Enter credentials in the rclone wizard, not in this script.

INFO

    rclone config --config "$RCLONE_CONFIG"
else
    echo "[3/6] Keeping the existing remote configuration."
fi

remote_exists \
    || die "Remote '${REMOTE_NAME}:' was not found. Create it with the exact name 'proton'."

if [[ -f "$RCLONE_CONFIG" ]]; then
    chmod 700 "$(dirname "$RCLONE_CONFIG")"
    chmod 600 "$RCLONE_CONFIG"
fi

echo
echo "[4/6] Testing the Proton Drive connection..."
rclone lsd "${REMOTE_NAME}:" --config "$RCLONE_CONFIG" \
    || die "Could not connect to Proton Drive. Check the remote with: rclone config"

echo
echo "[5/6] Creating or updating the systemd user service..."

mkdir -p "$CACHE_DIR"
chmod 700 "$CACHE_DIR"

# Logs go to the systemd journal (journalctl --user -u ${SERVICE_NAME}),
# so there is no log file to grow or rotate.
cat > "$UNIT_FILE" <<EOF
[Unit]
Description=rclone mount for Proton Drive
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
Type=notify
ExecStartPre=-$FUSERMOUNT_BIN -uz $MOUNT_POINT
ExecStartPre=$MKDIR_BIN -p $MOUNT_POINT
ExecStart=$RCLONE_BIN mount ${REMOTE_NAME}: $MOUNT_POINT --config=$RCLONE_CONFIG --cache-dir=$CACHE_DIR --vfs-cache-mode=full --vfs-cache-max-size=$VFS_CACHE_MAX_SIZE --vfs-cache-max-age=$VFS_CACHE_MAX_AGE --dir-cache-time=$DIR_CACHE_TIME --log-level=INFO
ExecStop=$FUSERMOUNT_BIN -uz $MOUNT_POINT
Restart=on-failure
RestartSec=10
TimeoutStopSec=30

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable "$SERVICE_NAME"
systemctl --user restart "$SERVICE_NAME" 2>/dev/null \
    || systemctl --user start "$SERVICE_NAME"

echo
if confirm "Start this user service at boot without an active login session?"; then
    sudo loginctl enable-linger "$USER_NAME"
    echo "Lingering enabled for $USER_NAME."
fi

echo
echo "Waiting for the mount to become available..."

MOUNT_READY=0
for _ in {1..15}; do
    if mountpoint -q -- "$MOUNT_POINT"; then
        MOUNT_READY=1
        break
    fi
    sleep 1
done

if [[ "$MOUNT_READY" -ne 1 ]]; then
    echo "[ERROR] The service did not mount Proton Drive." >&2
    echo "Recent service logs:" >&2
    journalctl --user -u "$SERVICE_NAME" -n 30 --no-pager >&2 || true
    exit 1
fi

echo
echo "[6/6] Service status:"
systemctl --user --no-pager --full status "$SERVICE_NAME" || true

echo
echo "Installation complete."
echo "Mount point: $MOUNT_POINT"
echo
echo "Useful commands:"
echo "  Stop:          systemctl --user stop $SERVICE_NAME"
echo "  Restart:       systemctl --user restart $SERVICE_NAME"
echo "  Logs:          journalctl --user -u $SERVICE_NAME -f"
echo "  Reconfigure:   ./install.sh --reconfigure"
echo "  Reset remote:  ./install.sh --reset-proton"
