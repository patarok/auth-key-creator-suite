#!/bin/bash
# --- INSTALLER FÜR MULTI-STICK AUTH ---
# bitte einfach "lokal" ausfuehren.

[ $EUID -ne 0 ] && echo "Bitte als root ausführen!" && exit 1

# Verzeichnisse anlegen
mkdir -p /etc/usb-auth/pubkeys
touch /etc/usb-auth/inventory.db /var/log/usb-auth-usage.log

# 1. Hardware-Wahl
echo "Verfügbare Partitionen:"
lsblk -o NAME,SIZE,UUID,MOUNTPOINT
read -p "Partition für neuen Stick angeben (z.B. sdc1): " PART
UUID=$(lsblk -no UUID /dev/$PART)
[ -z "$UUID" ] && echo "Fehler: Keine UUID!" && exit 1

# 2. Mounten & Key-Check
MNT="/etc/usb-auth/device"
mkdir -p "$MNT"
mount /dev/$PART "$MNT" 2>/dev/null

if [ ! -f "$MNT/usb_private.pem" ]; then
    echo "Generiere ED25519 Key auf dem Stick..."
    openssl genpkey -algorithm ED25519 -out "$MNT/usb_private.pem"
    chmod 600 "$MNT/usb_private.pem"
fi

# 3. Public Key registrieren
openssl pkey -in "$MNT/usb_private.pem" -pubout -out "/etc/usb-auth/pubkeys/key_$UUID.pub"

# 4. Inventory-Eintrag
read -p "Name für diesen Stick: " LABEL
USB_ID=$(lsusb | grep "$(lsblk -no VENDOR,MODEL /dev/$PART | head -n1)" | awk '{print $6}' | head -n1)
echo "$LABEL|$UUID|$USB_ID" >> /etc/usb-auth/inventory.db

# 5. fstab Eintrag vorschlagen
FSTAB="UUID=$UUID  $MNT  auto  nosuid,nodev,nofail  0  0"
echo -e "\nFüge dies manuell in /etc/fstab ein:\n$FSTAB"

echo -e "\nRegistrierung abgeschlossen."