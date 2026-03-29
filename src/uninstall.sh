#!/bin/bash
# --- USB-AUTH SUITE UNINSTALL ---
# Entfernt alle Komponenten des USB-Auth-Systems.
# Verwendung: sudo ./uninstall.sh

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== USB-AUTH Suite Uninstall ===${NC}"
echo ""
echo -e "${RED}WARNUNG: Dies wird alle USB-Auth Komponenten entfernen!${NC}"
echo ""

# Überprüfe Root-Rechte
if [ $EUID -ne 0 ]; then
    echo -e "${RED}Fehler: Dieses Skript muss als root ausgeführt werden!${NC}"
    exit 1
fi

# Bestätigung
read -p "Möchtest du USB-Auth wirklich deinstallieren? (j/n) " -n 1 -r
echo
[ "$REPLY" != "j" ] && echo "Deinstallation abgebrochen." && exit 0

echo ""
echo "Deinstallation läuft..."
echo ""

# 1. Entferne PAM Konfiguration (mit Warnung)
echo "Überprüfe PAM-Konfiguration..."
if grep -q "usb-auth-check.sh" /etc/pam.d/sudo 2>/dev/null; then
    echo -e "${YELLOW}WARNUNG: Bitte entferne die usb-auth-check.sh Zeile manuell aus /etc/pam.d/sudo${NC}"
fi
if grep -q "usb-auth-check.sh" /etc/pam.d/polkit-1 2>/dev/null; then
    echo -e "${YELLOW}WARNUNG: Bitte entferne die usb-auth-check.sh Zeile manuell aus /etc/pam.d/polkit-1${NC}"
fi
if grep -q "UUID=.*usb-auth/device" /etc/fstab 2>/dev/null; then
    echo -e "${YELLOW}WARNUNG: Bitte entferne die USB-Mount Zeile manuell aus /etc/fstab${NC}"
fi
echo ""

# 2. Entferne installierte Binaries
echo "Entferne Binaries..."
rm -f /usr/bin/usb-auth-check.sh && echo "  ✓ Entfernt: /usr/bin/usb-auth-check.sh"
rm -f /usr/local/bin/usb-auth-admin && echo "  ✓ Entfernt: /usr/local/bin/usb-auth-admin"
rm -f /usr/local/bin/install-usb-auth.sh && echo "  ✓ Entfernt: /usr/local/bin/install-usb-auth.sh"
echo ""

# 3. Unmount USB wenn noch gemountet
echo "Unmount USB-Stick falls gemountet..."
if mountpoint -q /etc/usb-auth/device 2>/dev/null; then
    umount /etc/usb-auth/device 2>/dev/null && echo "  ✓ USB-Stick unmountet"
fi
echo ""

# 4. Entferne Konfigurationsverzeichnis
echo "Entferne Konfigurationsverzeichnis..."
rm -rf /etc/usb-auth && echo "  ✓ Entfernt: /etc/usb-auth/"
echo ""

# 5. Archiviere Logs (statt zu löschen)
echo "Archiviere Logs..."
if [ -f /var/log/usb-auth-usage.log ]; then
    LOG_BACKUP="/var/log/usb-auth-usage.log.backup.$(date +%s)"
    cp /var/log/usb-auth-usage.log "$LOG_BACKUP"
    echo "  ✓ Logs gesichert: $LOG_BACKUP"
    rm -f /var/log/usb-auth-usage.log
fi
echo ""

echo -e "${GREEN}=== Deinstallation abgeschlossen ===${NC}"
echo ""
echo "Verbleibende manuelle Aufgaben:"
echo "1. Entferne 'auth' Zeile mit usb-auth-check.sh aus /etc/pam.d/sudo"
echo "2. Entferne 'auth' Zeile mit usb-auth-check.sh aus /etc/pam.d/polkit-1 (falls vorhanden)"
echo "3. Entferne die UUID-Zeile aus /etc/fstab (falls vorhanden)"
echo ""
echo "Falls Logs benötigt werden, siehe:"
echo "  ls -la /var/log/usb-auth-usage.log.backup.*"
echo ""
