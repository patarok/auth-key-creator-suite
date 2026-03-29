#!/bin/bash
# --- INSTALLER FÜR USB-AUTH ---
# Registriert einen neuen USB-Stick für die Authentifizierung.
# HINWEIS: Bitte als root ausführen.
# Verwendung: ./install-usb-auth.sh

set -e

# Cleanup bei Fehler
cleanup_on_error() {
    echo "Fehler während der Installation. Aufräumen..."
    [ -n "$PART" ] && umount "/dev/$PART" 2>/dev/null || true
    exit 1
}
trap cleanup_on_error EXIT

[ $EUID -ne 0 ] && echo "Bitte als root ausführen!" && exit 1

# Überprüfe erforderliche Programme
for cmd in openssl lsblk lsusb; do
    command -v "$cmd" &>/dev/null || { echo "Fehler: $cmd nicht installiert!"; exit 1; }
done

# Verzeichnisse anlegen (mit strikten Berechtigungen)
mkdir -p /etc/usb-auth/pubkeys
chmod 700 /etc/usb-auth
touch /etc/usb-auth/inventory.db /var/log/usb-auth-usage.log
chmod 600 /etc/usb-auth/inventory.db /var/log/usb-auth-usage.log

# 1. Hardware-Wahl
echo "=== Verfügbare Partitionen ==="
lsblk -o NAME,SIZE,UUID,MOUNTPOINT | head -20
read -p "Partition für neuen Stick angeben (z.B. sdc1): " PART

# Validierung der Partition
if ! lsblk "/dev/$PART" &>/dev/null; then
    echo "Fehler: Partition /dev/$PART existiert nicht!"
    exit 1
fi

UUID=$(lsblk -no UUID "/dev/$PART" 2>/dev/null)
if [ -z "$UUID" ]; then
    echo "Fehler: Keine UUID für /dev/$PART gefunden!"
    exit 1
fi

# Prüfe ob Stick bereits registriert
if grep -q "^.*|$UUID|" /etc/usb-auth/inventory.db 2>/dev/null; then
    echo "Warnung: Dieser Stick (UUID: $UUID) ist bereits registriert!"
    read -p "Möchtest du ihn erneut registrieren? (j/n) " -n 1 -r
    [ "$REPLY" != "j" ] && exit 0
fi

# 2. Mounten & Key-Check
MNT="/etc/usb-auth/device"
mkdir -p "$MNT"

# Unmount falls bereits gemountet
umount "$MNT" 2>/dev/null || true

echo "Mounte Stick..."
mount "/dev/$PART" "$MNT" 2>/dev/null || {
    echo "Fehler: Kann Partition nicht mounten!"
    exit 1
}

# Beende trap zum Manual-Cleanup danach
trap - EXIT

# Überprüfe ob private Key bereits existiert
if [ ! -f "$MNT/usb_private.pem" ]; then
    echo "Generiere ED25519 Key auf dem Stick..."
    openssl genpkey -algorithm ED25519 -out "$MNT/usb_private.pem" 2>/dev/null || {
        umount "$MNT" 2>/dev/null || true
        echo "Fehler: Konnte Key nicht generieren!"
        exit 1
    }
    chmod 600 "$MNT/usb_private.pem"
    echo "Neuer Key generiert."
else
    echo "Private Key existiert bereits auf dem Stick."
fi

# 3. Public Key registrieren
echo "Registriere Public Key..."
openssl pkey -in "$MNT/usb_private.pem" -pubout -out "/etc/usb-auth/pubkeys/key_$UUID.pub" 2>/dev/null || {
    umount "$MNT" 2>/dev/null || true
    echo "Fehler: Konnte Public Key nicht extrahieren!"
    exit 1
}
chmod 644 "/etc/usb-auth/pubkeys/key_$UUID.pub"

# 4. Inventory-Eintrag
read -p "Name für diesen Stick: " LABEL
if [ -z "$LABEL" ]; then
    LABEL="Stick_$UUID"
fi

USB_ID=$(lsusb | grep "$(lsblk -no VENDOR,MODEL "/dev/$PART" 2>/dev/null | head -n1)" | awk '{print $6}' | head -n1)
USB_ID="${USB_ID:-unknown}"

echo "$LABEL|$UUID|$USB_ID" >> /etc/usb-auth/inventory.db
echo "Stick registriert als: $LABEL (UUID: $UUID)"

# 5. fstab info
echo ""
echo "=== WICHTIG: Konfiguriere fstab für Auto-Mount ==="
echo "Um den Stick automatisch beim Boot zu mounten, füge diese Zeile in /etc/fstab ein:"
echo ""
FSTAB="UUID=$UUID  /etc/usb-auth/device  auto  nosuid,nodev,nofail  0  0"
echo "$FSTAB"
echo ""
echo "Anschließend testen mit: sudo mount -a"
echo ""

# Unmount
umount "$MNT" 2>/dev/null || true
echo "Installation abgeschlossen!"