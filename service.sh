#!/system/bin/sh
MODDIR=${0%/*}
SYS_CERT_DIR=/system/etc/security/cacerts
APEX_CERT_DIR=/apex/com.android.conscrypt/cacerts

DEBUG=1
if [ "$DEBUG" = "1" ]; then
    LOGFILE="/data/local/tmp/burpca_autotrust_service_$(date '+%Y%m%d_%H%M%S').log"
    exec >> "$LOGFILE" 2>&1
    set -x
else
    LOGFILE="/data/local/tmp/burpca_autotrust_service.log"
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

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

has_mount() {
    local pid=$1
    grep -q " $APEX_CERT_DIR " "/proc/$pid/mountinfo"
}

monitor_zygote() {
    (
    while true; do
        zygote_pids=""
        for name in zygote zygote64; do
            for p in $(pidof $name 2>/dev/null); do
                zygote_pids="$zygote_pids $p"
            done
        done

        for zp in $zygote_pids; do
            if ! has_mount "$zp"; then
                children=$(echo "$zp" | xargs -n1 ps -o pid -P  | grep -v PID)

                if [ -z "$children" ]; then
                    children=$(ps | awk -v PPID=$zp '$3==PPID { print $2 }')
                fi

                if [ "$(echo "$children" | wc -l)" -lt 5 ]; then
                    /system/bin/sleep 1s
                    continue
                fi

                log "Injecting into zygote ($zp)"
                /system/bin/nsenter --mount=/proc/$zp/ns/mnt -- /bin/mount --rbind $SYS_CERT_DIR $APEX_CERT_DIR

                for pid in $children; do
                    if ! has_mount "$pid"; then
                        log "  Injecting into child $pid"
                        /system/bin/nsenter --mount=/proc/$pid/ns/mnt -- /bin/mount --rbind $SYS_CERT_DIR $APEX_CERT_DIR
                    fi
                done
            fi
        done

        sleep 5
    done
    )&
}

main() {
    log "BurpCA AutoTrust service.sh started"

    while [ "$(getprop sys.boot_completed)" != 1 ]; do
        /system/bin/sleep 1s
    done

    if [ -d "$APEX_CERT_DIR" ]; then
        log "APEX certs detected, preparing environment"

        cp -f "$APEX_CERT_DIR"/* "$MODDIR$SYS_CERT_DIR" 2>/dev/null || log "Warning: No APEX certs copied"

        run_cmd mount -t tmpfs tmpfs "$SYS_CERT_DIR"
        cp -f "$MODDIR$SYS_CERT_DIR"/* "$SYS_CERT_DIR"/
        run_cmd chown root:root "$SYS_CERT_DIR"/*
        run_cmd chmod 644 "$SYS_CERT_DIR"/*
        run_cmd chcon u:object_r:system_security_cacerts_file:s0 "$SYS_CERT_DIR"/*

        monitor_zygote
    else
        log "No APEX container found on device, skipping APEX cert injection"
    fi

    log "BurpCA AutoTrust service.sh finished"
}

main