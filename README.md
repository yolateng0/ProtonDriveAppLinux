# ☁️ rclone Proton Drive for Debian

[![Debian](https://img.shields.io/badge/OS-Debian-A81D33?logo=debian&logoColor=white)](https://www.debian.org/)
[![rclone](https://img.shields.io/badge/Powered%20by-rclone-3765A3?logo=rclone&logoColor=white)](https://rclone.org/)
[![systemd](https://img.shields.io/badge/Service-systemd-333?logo=systemd&logoColor=white)](https://systemd.io/)
[![License](https://img.shields.io/badge/License-see%20LICENSE-lightgrey)](LICENSE)

Mount Proton Drive on Debian using **rclone** and a **systemd user service**. The mount runs under the Linux account that installs the service.

> [!WARNING]
> The Proton Drive backend in rclone is marked as **beta**. Its behavior may change as Proton Drive evolves. Keep a separate backup of important files.

## ✨ Features

- Mount Proton Drive at `~/ProtonDrive`
- Manage the mount with a systemd user service
- Reconfigure or reset the Proton Drive remote
- Keep credentials out of the installation script

## 📋 Requirements

- Debian with systemd
- A regular user account with `sudo` access
- A Proton Drive account
- An active user session to install the service

## 🚀 Installation

Clone the repository and run the installer **without `sudo`**:

```bash
git clone https://github.com/yolateng0/ProtonDriveAppLinux.git
cd ProtonDriveAppLinux
chmod +x install.sh uninstall.sh
./install.sh
```

The installer installs rclone and `fuse3`, then opens the rclone configuration wizard.

### Configure the Proton remote

In the wizard:

1. Create a new remote.
2. Name it `proton`.
3. Select the `protondrive` storage type.
4. Follow the authentication prompts.
5. If your Proton account uses two passwords, enter the mailbox password in the advanced options.

> 🔐 Enter your credentials in the rclone wizard. **Do not put them in this repository or in the script.**

After installation, the mount is available at:

```text
~/ProtonDrive
```

The service starts when you log in. The installer also offers to enable startup when you are logged out.

## 🛠️ Useful commands

Check the service status:

```bash
systemctl --user status rclone-proton.service
```

Stop the mount:

```bash
systemctl --user stop rclone-proton.service
```

Restart the mount:

```bash
systemctl --user restart rclone-proton.service
```

Follow the service logs:

```bash
journalctl --user -u rclone-proton.service -f
```

Test the remote:

```bash
rclone lsd proton:
```

Reconfigure the Proton remote:

```bash
./install.sh --reconfigure
```

Repair the installation:

```bash
./install.sh --repair
```

Reset the Proton remote:

```bash
./install.sh --reset-proton
```

> [!CAUTION]
> `--reset-proton` backs up the rclone configuration, removes only the `proton` remote, clears this mount’s cache, and opens the configuration wizard.

## 🗑️ Uninstall

Run the uninstaller as your regular user:

```bash
./uninstall.sh
```

> [!CAUTION]
> The uninstaller removes the service, the rclone configuration directory, and `~/ProtonDrive`. **This deletes all rclone remotes stored in that configuration directory**, not just Proton Drive. Back up any files you want to keep before continuing.

The log and cache directories are not removed by the uninstaller.

## ℹ️ Notes

- The mount is available only to the Linux user who installed the service.
- `--allow-other` is not enabled.
- Proton Drive metadata caching is disabled for this mount.
- Never commit `rclone.conf`, passwords, or logs that may contain account data.

## 📚 Credits and sources

### Upstream project

This project is a fork/adaptation of
[ dadtronics/protondrive-linux ](https://github.com/dadtronics/protondrive-linux).

The original project provides a guide and setup script for mounting Proton Drive on Linux with rclone and systemd. This fork adapts the setup for Debian and adds installation, repair, reconfiguration, reset, and uninstall options.

### Software and documentation

- [rclone](https://rclone.org/) — Proton Drive backend and mount utility.
- [rclone Proton Drive documentation](https://rclone.org/protondrive/) — backend configuration and limitations.
- [systemd documentation](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html) — service management.
- [FUSE](https://github.com/libfuse/libfuse) — userspace filesystem support used by the mount.

### Trademark and affiliation

Proton Drive is a product and trademark of Proton AG. This is an unofficial, community-maintained project and is not affiliated with, endorsed by, or supported by Proton AG.
