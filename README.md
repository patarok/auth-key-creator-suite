# auth-key-creator-suite

A secure USB-based authentication system for Linux. This suite allows system administrators to manage hardware-token authentication using USB sticks as security keys alongside or instead of traditional password authentication.

## What is this?

This suite implements a **USB stick as an authentication factor** in PAM (Pluggable Authentication Modules), enabling:

- ✅ USB stick as hardware token for sudo/privileged operations
- ✅ ED25519 cryptographic authentication (modern, efficient)
- ✅ Audit logging of all authentication attempts
- ✅ Inventory management of registered sticks
- ✅ Flexible PAM integration (optional or mandatory)

**Architecture:** Single mount point (`/etc/usb-auth/device`) - one stick can be authenticated at a time. Multiple sticks can be registered in the inventory but only one is used per authentication attempt.

---

## Quick Start

### Prerequisites

- Linux system with root access
- Required packages: `openssl`, `util-linux` (lsblk), `usbutils` (lsusb)
- A USB stick (FAT/NTFS/ext4, readable/writable)

Install dependencies:
```bash
sudo apt-get install openssl util-linux usbutils
```

### Installation Steps

1. **Register a new USB stick:**
   ```bash
   sudo /workspaces/auth-key-creator-suite/src/install-usb-auth.sh
   ```
   - Follow the prompts to select your USB partition
   - Script generates ED25519 key pair on the stick
   - Registers the public key in `/etc/usb-auth/pubkeys/`
   - Provides fstab configuration

2. **Configure fstab for auto-mount:**
   ```bash
   sudo nano /etc/fstab
   ```
   Add the line provided by the install script (UUID-based mount):
   ```
   UUID=YOUR_UUID  /etc/usb-auth/device  auto  nosuid,nodev,nofail  0  0
   ```
   Test with: `sudo mount -a`

3. **Install PAM authentication script:**
   ```bash
   sudo cp /workspaces/auth-key-creator-suite/src/usb-auth-check.sh /usr/bin/
   sudo chmod 755 /usr/bin/usb-auth-check.sh
   ```

4. **Install admin tool (optional):**
   ```bash
   sudo cp /workspaces/auth-key-creator-suite/src/usb-auth-admin /usr/local/bin/
   sudo chmod 755 /usr/local/bin/usb-auth-admin
   ```

5. **Configure PAM:**
   - Review options in `src/pam_configuration_line.txt`
   - Edit `/etc/pam.d/sudo` (or `/etc/pam.d/polkit-1` for GUI)
   - Add the appropriate line as the FIRST auth line

---

## File Reference

| File | Purpose | Install To |
|------|---------|-----------|
| `install-usb-auth.sh` | Register new USB sticks | Run directly as root |
| `usb-auth-check.sh` | PAM authentication module | `/usr/bin/` |
| `usb-auth-admin` | View registered sticks & usage logs | `/usr/local/bin/` |
| `pam_configuration_line.txt` | PAM configuration reference | Manual reference |

## Directory Structure (created on install)

```
/etc/usb-auth/
├── device              (mount point for USB stick)
├── pubkeys/            (registered public keys)
│   └── key_<UUID>.pub
└── inventory.db        (inventory of registered sticks)

/var/log/
└── usb-auth-usage.log  (authentication audit log)
```

---

## Usage

### Check registered sticks:
```bash
sudo /usr/local/bin/usb-auth-admin
```
Output shows:
- Stick label
- UUID
- Last usage date
- Status (OK, WARNING if unused >21 days, NEW)
- `*` indicates currently detected/mounted stick

### Using with sudo:
Once PAM is configured, simply:
```bash
sudo <command>
```
Behavior depends on PAM configuration:
- **sufficient mode** (default): Stick auto-auths, or prompts for password
- **required mode** (strict): Stick is mandatory
- **success mode** (convenience): Stick-only, no password fallback

### View audit logs:
```bash
sudo tail -f /var/log/usb-auth-usage.log
```

---

## Configuration Modes

See `src/pam_configuration_line.txt` for three PAM integration options:

1. **Stick-only (convenience)** - USB stick is sufficient
2. **Stick + Password (security)** - Both required
3. **Stick preferred, Password fallback** - Recommended for gradual rollout

---

## Security Considerations

- **Private keys** stored on USB stick (unencrypted)
  - Protect stick physically or use encrypted partitions
- **Challenge-response** via ED25519 signatures (cryptographically verified)
- **Audit logging** all authentication attempts
- **Permissions:** Files in `/etc/usb-auth/` are 600/700 (root-only)
- **Temporary files** in `/dev/shm/` are process-isolated with PID suffix

---

## Troubleshooting

### Stick not recognized:
```bash
lsblk -o NAME,SIZE,UUID
```
Ensure the UUID matches in `/etc/usb-auth/inventory.db`

### PAM module not executing:
- Check permissions: `ls -la /usr/bin/usb-auth-check.sh` (must be 755)
- Check logs: `sudo journalctl -xe` or `sudo tail -f /var/log/auth.log`
- Verify path in `/etc/pam.d/sudo` matches exactly

### fstab mount fails:
- Check UUID: `sudo blkid /dev/sdc1` (example)
- Verify device path is correct
- Test mount manually: `sudo mount /dev/sdc1 /etc/usb-auth/device`

---

## Uninstalling

To remove USB authentication:

1. Edit PAM files: Remove the `pam_exec.so` line from `/etc/pam.d/sudo` and `/etc/pam.d/polkit-1`
2. Remove fstab entry: `sudo nano /etc/fstab` (delete USB mount line)
3. Clean up files:
   ```bash
   sudo rm /usr/bin/usb-auth-check.sh
   sudo rm /usr/local/bin/usb-auth-admin
   sudo rm -rf /etc/usb-auth/
   sudo rm /var/log/usb-auth-usage.log
   ```

---

## License

No specific license. Use as needed.

## Author Notes

This suite implements hardware-token authentication as a security supplement to traditional password-based auth. The approach:
- ✅ Adds physical factor (USB possession)
- ✅ Maintains password auth as fallback (depending on config)
- ✅ Provides audit trail for compliance
- ⚠️ Requires users to always carry USB sticks (depending on config)

Note: this can make your old Lexar Thumbprint Jumpstick quite a proper Yubikey competitor... if you dont believe in spaceships. :>
