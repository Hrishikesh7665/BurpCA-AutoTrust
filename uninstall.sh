#!/system/bin/sh
MODDIR=${0%/*}
SYS_CERT_DIR=/system/etc/security/cacerts
APEX_CERT_DIR=/apex/com.android.conscrypt/cacerts

DEBUG=1
if [ "$DEBUG" = "1" ]; then
    LOGFILE="/data/local/tmp/burpca_autotrust_uninstall_$(date '+%Y%m%d_%H%M%S').log"
    exec >> "$LOGFILE" 2>&1
    set -x
else
    LOGFILE="/data/local/tmp/burpca_autotrust_uninstall.log"
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

BURP_CERT_HASH=9a5ba575
CERT_FILENAME="${BURP_CERT_HASH}.0"

log "Starting BurpCA AutoTrust uninstall cleanup..."

# Remove from overlay
if [ -f "$MODDIR/system/etc/security/cacerts/$CERT_FILENAME" ]; then
    rm -f "$MODDIR/system/etc/security/cacerts/$CERT_FILENAME"
    log "Removed $CERT_FILENAME from module overlay"
fi

# Attempt to cleanup APEX bind mount (only if mounted)
if mountpoint -q "$APEX_CERT_DIR"; then
    umount "$APEX_CERT_DIR" && log "Unmounted APEX certs directory bind mount"
else
    log "No APEX certs directory bind mount found"
fi

# Remove tmpdir if exists
TMPDIR="/data/local/tmp/burpca_autotrust"
if [ -d "$TMPDIR" ]; then
    rm -rf "$TMPDIR"
    log "Removed temporary directory $TMPDIR"
fi

log "BurpCA AutoTrust uninstall cleanup complete."
