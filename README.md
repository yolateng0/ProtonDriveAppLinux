# ProtonDriveAppLinux
Application Debian ProtonDrive 
Fork [https://github.com/dadtronics/protondrive-linux](https://github.com/dadtronics/protondrive-linux)

# rclone Proton Drive for Debian

Mount Proton Drive with rclone and a systemd user service. The mount is
configured for the Linux account that runs the installation script.

## Requirements

- Debian with systemd
- A user account with sudo access
- A Proton Drive account
- An active user session to install the service

The Proton Drive backend in rclone is marked as beta. Its behavior may change
as Proton Drive evolves.

## Installation

Clone the repository, then run the script without sudo:

```bash
git clone https://github.com/yolateng0/ProtonDriveAppLinux/
cd ProtonDriveAppLinux
chmod +x install.sh uninstall.sh
./install.sh
```

The script installs rclone and fuse3, then opens the `rclone config` wizard.

In the wizard:

1. Create a new remote.
2. Name it `proton`.
3. Select the `protondrive` storage type.
4. Follow the authentication prompts.
5. If your Proton account uses two passwords, also enter the mailbox password
   in the advanced options.

Enter your credentials in the rclone wizard, not in this repository.

After installation, Proton Drive is mounted at:

```text
~/ProtonDrive
```

The service starts when you log in. The script also offers to enable startup at
boot, even when you are not logged in.

## Useful commands

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

Uninstall the service:

```bash
./uninstall.sh
```

Uninstalling keeps your rclone configuration, logs, and `~/ProtonDrive`
directory.

## Notes

- The mount is available only to the Linux user who installed the service.
- `--allow-other` is not enabled.
- Proton Drive metadata caching is disabled for this mount.
- Never commit `rclone.conf`, passwords, or logs that may contain account data.



References:
rclone Proton Drive Docs
systemd user services
[dadtronics](https://github.com/dadtronics)

