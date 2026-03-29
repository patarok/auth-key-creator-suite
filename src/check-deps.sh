#!/bin/bash
# --- USB-AUTH DEPENDENCY CHECKER ---
# Überprüft, ob alle erforderlichen Abhängigkeiten für USB-Auth vorhanden sind.
# Verwendung: ./check-deps.sh

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== USB-Auth Dependency Checker ===${NC}"
echo ""

failed=0
warnings=0
passed=0

# 1. Überprüfe Root-Rechte
echo -n "Überprüfe Privilegien... "
if [ $EUID -eq 0 ]; then
    echo -e "${GREEN}✓ Root${NC}"
    passed=$((passed + 1))
else
    echo -e "${YELLOW}⚠ Nicht root (einige Checks überspringen)${NC}"
    warnings=$((warnings + 1))
fi

# 2. Überprüfe Befehle
echo ""
echo "Überprüfe erforderliche Befehle:"

commands=("openssl" "lsblk" "lsusb" "mount" "umount" "grep" "awk" "cut" "date")
for cmd in "${commands[@]}"; do
    echo -n "  $cmd... "
    if command -v "$cmd" &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        passed=$((passed + 1))
    else
        echo -e "${RED}✗ FEHLT${NC}"
        failed=$((failed + 1))
    fi
done

# 3. Überprüfe Verzeichnisse (falls installiert)
echo ""
echo "Überprüfe Installationsverzeichnisse:"

if [ $EUID -eq 0 ]; then
    dirs=("/etc/usb-auth" "/var/log" "/usr/bin" "/usr/local/bin")
    for dir in "${dirs[@]}"; do
        echo -n "  $dir... "
        if [ -d "$dir" ]; then
            echo -e "${GREEN}✓ existiert${NC}"
            passed=$((passed + 1))
        else
            echo -e "${YELLOW}⚠ nicht vorhanden${NC}"
            warnings=$((warnings + 1))
        fi
    done
    
    # 4. Überprüfe installierte Binaries
    echo ""
    echo "Überprüfe installierte Komponenten:"
    
    binaries=(
        "/usr/bin/usb-auth-check.sh"
        "/usr/local/bin/usb-auth-admin"
        "/usr/local/bin/install-usb-auth.sh"
    )
    
    for binary in "${binaries[@]}"; do
        echo -n "  $(basename $binary)... "
        if [ -x "$binary" ]; then
            echo -e "${GREEN}✓ installiert${NC}"
            passed=$((passed + 1))
        else
            echo -e "${YELLOW}⚠ nicht installiert${NC}"
            warnings=$((warnings + 1))
        fi
    done
    
    # 5. Überprüfe Datenbankdatein
    echo ""
    echo "Überprüfe Konfigurationsdateien:"
    
    config_files=(
        "/etc/usb-auth/inventory.db"
        "/var/log/usb-auth-usage.log"
    )
    
    for file in "${config_files[@]}"; do
        echo -n "  $(basename $file)... "
        if [ -f "$file" ]; then
            echo -e "${GREEN}✓ existiert${NC}"
            passed=$((passed + 1))
        else
            echo -e "${YELLOW}⚠ nicht vorhanden (wird beim ersten Install erstellt)${NC}"
            warnings=$((warnings + 1))
        fi
    done
    
    # 6. Überprüfe PAM-Konfiguration
    echo ""
    echo "Überprüfe PAM-Konfiguration:"
    
    pam_files=("/etc/pam.d/sudo" "/etc/pam.d/polkit-1")
    pam_configured=0
    
    for pam_file in "${pam_files[@]}"; do
        if [ -f "$pam_file" ]; then
            echo -n "  $(basename $pam_file)... "
            if grep -q "usb-auth-check.sh" "$pam_file" 2>/dev/null; then
                echo -e "${GREEN}✓ konfiguriert${NC}"
                pam_configured=$((pam_configured + 1))
                passed=$((passed + 1))
            else
                echo -e "${YELLOW}⚠ nicht konfiguriert${NC}"
                warnings=$((warnings + 1))
            fi
        fi
    done
    
    if [ $pam_configured -eq 0 ]; then
        echo -e "    ${YELLOW}Hinweis: PAM nicht konfiguriert (normal nach Installation)${NC}"
    fi
    
    # 7. Überprüfe fstab
    echo ""
    echo "Überprüfe Filesystem-Konfiguration (fstab):"
    
    echo -n "  USB-Mount in fstab... "
    if grep -q "/etc/usb-auth/device" /etc/fstab 2>/dev/null; then
        echo -e "${GREEN}✓ konfiguriert${NC}"
        passed=$((passed + 1))
    else
        echo -e "${YELLOW}⚠ nicht konfiguriert (wird beim USB-Setup erstellt)${NC}"
        warnings=$((warnings + 1))
    fi
    
    # 8. Überprüfe ob USB aktuell gemountet
    echo ""
    echo "Überprüfe aktiven USB-Status:"
    
    echo -n "  /etc/usb-auth/device Mount-Status... "
    if mountpoint -q /etc/usb-auth/device 2>/dev/null; then
        echo -e "${GREEN}✓ gemountet${NC}"
        passed=$((passed + 1))
        
        # Zeige gemounteten Stick
        mounted_device=$(mount | grep "/etc/usb-auth/device" | awk '{print $1}')
        mounted_uuid=$(blkid "$mounted_device" -s UUID -o value 2>/dev/null || echo "?")
        echo "    └─ Gerät: $mounted_device (UUID: $mounted_uuid)"
    else
        echo -e "${YELLOW}⚠ nicht gemountet${NC}"
        warnings=$((warnings + 1))
    fi
fi

# 7. Überprüfe systemverzeichnis (auch ohne root)
echo ""
echo "Überprüfe Systemdateien:"

echo -n "  /bin /usr/bin vorhanden... "
if [ -d /bin ] && [ -d /usr/bin ]; then
    echo -e "${GREEN}✓${NC}"
    passed=$((passed + 1))
else
    echo -e "${RED}✗${NC}"
    failed=$((failed + 1))
fi

# Zusammenfassung
echo ""
echo "-" | awk '{for(i=1;i<=50;i++)printf "-"; print ""}'
echo "Zusammenfassung:"
echo "  ✓ Erfolgreich: $passed"
echo "  ⚠ Warnungen:   $warnings"
echo "  ✗ Fehler:      $failed"
echo "-" | awk '{for(i=1;i<=50;i++)printf "-"; print ""}'

echo ""
if [ $failed -eq 0 ]; then
    if [ $warnings -eq 0 ]; then
        echo -e "${GREEN}Status: Alles gut! USB-Auth ist bereit.${NC}"
        exit 0
    else
        echo -e "${YELLOW}Status: System ist kompatibel, aber einige Komponenten fehlen.${NC}"
        echo "Installation durchführen mit: sudo ./setup.sh"
        exit 0
    fi
else
    echo -e "${RED}Status: Es gibt kritische Fehler!${NC}"
    echo "Installiere fehlende Abhängigkeiten mit:"
    echo "  sudo apt-get install openssl util-linux usbutils"
    exit 1
fi
