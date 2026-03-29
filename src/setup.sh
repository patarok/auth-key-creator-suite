#!/bin/bash
# --- USB-AUTH SUITE SETUP ---
# Installiert alle erforderlichen Komponenten des USB-Auth-Systems.
# Verwendung: sudo ./setup.sh

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== USB-AUTH Suite Setup ===${NC}"
echo ""

# Überprüfe Root-Rechte
if [ $EUID -ne 0 ]; then
    echo -e "${RED}Fehler: Dieses Skript muss als root ausgeführt werden!${NC}"
    echo "Starten Sie mit: sudo ./setup.sh"
    exit 1
fi

# Überprüfe erforderliche Programme
echo "Überprüfe erforderliche Abhängigkeiten..."
for cmd in openssl lsblk lsusb mount; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}Fehler: $cmd nicht installiert!${NC}"
        echo "Installieren Sie mit: sudo apt-get install openssl util-linux usbutils"
        exit 1
    fi
done
echo -e "${GREEN}✓ Alle Abhängigkeiten vorhanden${NC}"
echo ""

# Skriptpfade (relativ zu diesem Skript)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTH_CHECK="$SCRIPT_DIR/usb-auth-check.sh"
AUTH_ADMIN="$SCRIPT_DIR/usb-auth-admin"
INSTALL_SCRIPT="$SCRIPT_DIR/install-usb-auth.sh"

# Überprüfe ob Skripte existieren
for script in "$AUTH_CHECK" "$AUTH_ADMIN" "$INSTALL_SCRIPT"; do
    if [ ! -f "$script" ]; then
        echo -e "${RED}Fehler: $script nicht gefunden!${NC}"
        exit 1
    fi
done

# Erstelle Verzeichnisse
echo "Erstelle Verzeichnisse..."
mkdir -p /etc/usb-auth/pubkeys
chmod 700 /etc/usb-auth
mkdir -p /var/log
echo -e "${GREEN}✓ Verzeichnisse erstellt${NC}"

# Erstelle/Initialisiere Log-Dateien
echo "Initialisiere Log-Dateien..."
touch /etc/usb-auth/inventory.db
touch /var/log/usb-auth-usage.log
chmod 600 /etc/usb-auth/inventory.db
chmod 644 /var/log/usb-auth-usage.log
echo -e "${GREEN}✓ Log-Dateien initialisiert${NC}"

# Installiere usb-auth-check.sh
echo "Installiere usb-auth-check.sh nach /usr/bin/..."
cp "$AUTH_CHECK" /usr/bin/usb-auth-check.sh
chmod 755 /usr/bin/usb-auth-check.sh
echo -e "${GREEN}✓ usb-auth-check.sh installiert${NC}"

# Installiere usb-auth-admin
echo "Installiere usb-auth-admin nach /usr/local/bin/..."
cp "$AUTH_ADMIN" /usr/local/bin/usb-auth-admin
chmod 755 /usr/local/bin/usb-auth-admin
echo -e "${GREEN}✓ usb-auth-admin installiert${NC}"

# Installiere install-usb-auth.sh
echo "Installiere install-usb-auth.sh nach /usr/local/bin/..."
cp "$INSTALL_SCRIPT" /usr/local/bin/install-usb-auth.sh
chmod 755 /usr/local/bin/install-usb-auth.sh
echo -e "${GREEN}✓ install-usb-auth.sh installiert${NC}"

echo ""
echo -e "${GREEN}=== Installation abgeschlossen! ===${NC}"
echo ""
echo "Nächste Schritte:"
echo "1. Registriere einen USB-Stick:"
echo "   sudo /usr/local/bin/install-usb-auth.sh"
echo ""
echo "2. Konfiguriere fstab mit der von install-usb-auth.sh bereitgestellten Zeile"
echo ""
echo "3. Konfiguriere PAM:"
echo "   - Überprüfe Optionen in:"
echo "     cat $SCRIPT_DIR/pam_configuration_line.txt"
echo "   - Bearbeite dann /etc/pam.d/sudo oder /etc/pam.d/polkit-1"
echo "   - Füge die gewählte Zeile als ERSTE auth-Zeile ein"
echo ""
echo "4. Teste mit:"
echo "   sudo /usr/local/bin/usb-auth-admin"
echo ""
