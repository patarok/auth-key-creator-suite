#!/bin/bash
# --- USB-AUTH AUTHENTICATION LOOP ---
# Verifiziert den eingesteckten Stick gegen alle registrierten Public Keys.
# bitte in '/usr/bin/.' ablegen.

PUBKEY_DIR="/etc/usb-auth/pubkeys"
MNT_POINT="/etc/usb-auth/device"
CHALLENGE="/dev/shm/.usb_challenge_$$"
SIG="/dev/shm/.usb_sig_$$"
LOG_FILE="/var/log/usb-auth-usage.log"
OPENSSL="/usr/bin/openssl"

# Cleanup bei Beendigung (auch bei Interrupt)
cleanup() {
    rm -f "$CHALLENGE" "$SIG"
}
trap cleanup EXIT INT TERM

# 1. Abbruch, falls kein Stick am festen Mountpoint ist
if ! mountpoint -q "$MNT_POINT"; then
    exit 1
fi

PRIV_KEY="$MNT_POINT/usb_private.pem"
if [ ! -f "$PRIV_KEY" ]; then
    exit 1
fi

# 2. Challenge erzeugen (eindeutig mit PID und Nanosekunden)
echo "auth-$(date +%s%N)-$$" > "$CHALLENGE" || exit 1

# 3. Alle registrierten Public Keys testen
SUCCESS=1 # Initial auf Fehler gesetzt
for pubkey in "$PUBKEY_DIR"/*.pub; do
    [ -e "$pubkey" ] || continue
    
    # Signatur-Versuch
    $OPENSSL pkeyutl -sign -inkey "$PRIV_KEY" -in "$CHALLENGE" -out "$SIG" 2>/dev/null
    [ $? -eq 0 ] || continue
    
    # Verifizierung gegen den aktuellen Key in der Schleife
    if $OPENSSL pkeyutl -verify -pubin -inkey "$pubkey" -sigfile "$SIG" -in "$CHALLENGE" &>/dev/null; then
        UUID=$(basename "$pubkey" | sed 's/key_//;s/.pub//')
        
        # Loggen für das Admin-Tool
        echo "$(date '+%Y-%m-%d %H:%M:%S') | SUCCESS | UUID: $UUID" >> "$LOG_FILE"
        SUCCESS=0
        break
    fi
done

exit $SUCCESS