#!/system/bin/sh
chmod 755 "$0"
MODDIR=${0%/*}

BURP_CERT_HASH=9a5ba575
BURP_CERT_SRC="${MODDIR}/system/etc/security/cacerts/${BURP_CERT_HASH}.0"
SYS_CERT_DIR="/system/etc/security/cacerts"
APEX_CERT_DIR="/apex/com.android.conscrypt/cacerts"

DEBUG=1
if [ "$DEBUG" = "1" ]; then
    LOGFILE="/data/local/tmp/burpca_autotrust_$(date '+%Y%m%d_%H%M%S').log"
    exec >> "$LOGFILE" 2>&1
    set -x
else
    LOGFILE="/data/local/tmp/burpca_autotrust.log"
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "================================"
log " BurpCA AutoTrust Module START "
log "================================"

# Runtime detection for root framework
if [ -d /data/adb/ksu ]; then
    ROOT_FRAMEWORK="kernelsu"
    BUSYBOX="/data/adb/ksu/bin/busybox"
    log "Detected KernelSU runtime"
else
    ROOT_FRAMEWORK="magisk"
    BUSYBOX=""
    log "Defaulting to Magisk runtime"
fi

run_cmd() {
    if [ -x "$BUSYBOX" ]; then
        "$BUSYBOX" "$@"
    else
        "$@"
    fi
}

set_context() {
    src="$1"; dst="$2"
    if [ "$(getenforce 2>/dev/null)" != "Enforcing" ]; then
        log "SELinux not enforcing — skipping chcon"
        return 0
    fi
    context=$(ls -Zd "$src" 2>/dev/null | awk '{print $1}')
    if [ -n "$context" ] && [ "$context" != "?" ]; then
        chcon -R "$context" "$dst" 2>/dev/null && log "Set SELinux context from $src to $dst"
    else
        chcon -R u:object_r:system_file:s0 "$dst" 2>/dev/null && log "Set SELinux context to default for $dst"
    fi
}

if [ ! -f "$BURP_CERT_SRC" ]; then
    log "ERROR: Burp cert not found in module path: $BURP_CERT_SRC"
    exit 1
fi
log "Found Burp cert in module: $BURP_CERT_SRC"

ANDROID_VER=$(getprop ro.build.version.release 2>/dev/null | cut -d'.' -f1)
if [ -z "$ANDROID_VER" ]; then ANDROID_VER=0; fi
log "Detected Android major version: $ANDROID_VER"

install_to_overlay() {
    mkdir -p "$MODDIR$SYS_CERT_DIR"
    cp -f "$BURP_CERT_SRC" "$MODDIR$SYS_CERT_DIR/${BURP_CERT_HASH}.0" && log "Copied Burp cert to overlay: $MODDIR$SYS_CERT_DIR/${BURP_CERT_HASH}.0"
    run_cmd chown -R 0:0 "$MODDIR$SYS_CERT_DIR" || log "chown overlay failed"
    run_cmd chmod 644 "$MODDIR$SYS_CERT_DIR"/* || log "chmod overlay failed"
    set_context "$SYS_CERT_DIR" "$MODDIR$SYS_CERT_DIR"
}

inject_into_apex_once() {
    if [ "$ANDROID_VER" -lt 14 ]; then
        log "Android <14 detected, skipping APEX injection"
        return 0
    fi

    if [ ! -d "$APEX_CERT_DIR" ]; then
        log "APEX conscrypt cert dir not present: $APEX_CERT_DIR"
        return 0
    fi

    TMPDIR="/data/local/tmp/burpca_autotrust"
    run_cmd rm -rf "$TMPDIR"
    run_cmd mkdir -p "$TMPDIR"
    log "Prepared tmp dir: $TMPDIR"

    cp -f "$APEX_CERT_DIR"/* "$TMPDIR" 2>/dev/null || log "No existing apex certs copied (ok)"
    cp -f "$BURP_CERT_SRC" "$TMPDIR/${BURP_CERT_HASH}.0" && log "Injected Burp cert into tmp copy"
    run_cmd chown -R 0:0 "$TMPDIR"
    set_context "$APEX_CERT_DIR" "$TMPDIR"

    mount --bind "$TMPDIR" "$APEX_CERT_DIR" && log "Bind-mounted $TMPDIR -> $APEX_CERT_DIR" || log "mount --bind failed"

    PIDS="$(pidof zygote 2>/dev/null) $(pidof zygote64 2>/dev/null)"
    for pid in $PIDS; do
        if [ -n "$pid" ] && [ -x /system/bin/nsenter ]; then
            /system/bin/nsenter --mount=/proc/"$pid"/ns/mnt -- /bin/mount --bind "$TMPDIR" "$APEX_CERT_DIR" && \
            log "Bind-mounted into ns of PID $pid" || log "Failed to bind into ns of PID $pid"
        fi
    done

    log "APEX injection finished (one-shot)."
}

install_to_overlay
inject_into_apex_once

log "================================"
log " BurpCA AutoTrust Module END "
log "================================"