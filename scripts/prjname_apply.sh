#!/system/bin/sh

# 风驰 DTBO：开机自动重设设备云控 ID（ro.boot.prjname）。
# 参照「慕容调度」风驰配置的映射，但只重设属性：
#  - 不清除应用增强数据（com.oplus.cosa 数据由刷入脚本处理）；
#  - 不重启游戏助手服务（开机阶段服务尚未/正在启动，无需干预）。

MOD_DIR=${0%/*}
MOD_DIR=${MOD_DIR%/*}
STATE_DIR="$MOD_DIR/runtime"
STATUS_FILE="$STATE_DIR/prjname_status.txt"
LOG_FILE="$STATE_DIR/prjname.log"

mkdir -p "$STATE_DIR" 2>/dev/null

detect_ui_family() {
    realme_ui=$(getprop ro.build.version.realmeui 2>/dev/null | tr -d '[:space:]')
    brand=$(getprop ro.product.brand 2>/dev/null | tr '[:upper:]' '[:lower:]')
    manufacturer=$(getprop ro.product.manufacturer 2>/dev/null | tr '[:upper:]' '[:lower:]')
    oplus_rom=$(getprop ro.build.version.oplusrom 2>/dev/null | tr -d '[:space:]')
    coloros=$(getprop ro.build.version.coloros 2>/dev/null | tr -d '[:space:]')
    if [ -n "$realme_ui" ] || [ "$brand" = realme ] || [ "$manufacturer" = realme ]; then
        printf '%s\n' realmeui
    elif [ -n "$coloros" ] || { [ "$brand" = oppo ] || [ "$brand" = oneplus ] ||
        [ "$manufacturer" = oppo ] || [ "$manufacturer" = oneplus ]; } && [ -n "$oplus_rom" ]; then
        printf '%s\n' coloros
    else
        return 1
    fi
}

detect_soc() {
    soc=$(getprop ro.soc.model 2>/dev/null | tr -d '[:space:]')
    case "$soc" in
        SM8850|SM8850P|SM8845|SM8750|SM8750P|SM8650|SM8650P|MT6991|MT6993|MT6995)
            printf '%s\n' "$soc" ;;
        *) return 1 ;;
    esac
}

# SoC → 设备云控 ID（ro.boot.prjname）
prjname_for_soc() {
    case "$1" in
        SM8850|SM8850P|SM8845) printf '%s\n' 24831 ;;
        SM8750|SM8750P)        printf '%s\n' 24851 ;;
        SM8650|SM8650P)        printf '%s\n' 23851 ;;
        MT6991|MT6993)        printf '%s\n' 24813 ;;
        MT6995)              printf '%s\n' 25815 ;;
        *) return 1 ;;
    esac
}

resolve_resetprop() {
    if [ -x /data/adb/ksu/bin/resetprop ]; then
        printf '%s\n' /data/adb/ksu/bin/resetprop
    elif [ -x /data/adb/magisk/resetprop ]; then
        printf '%s\n' /data/adb/magisk/resetprop
    elif command -v resetprop >/dev/null 2>&1; then
        printf '%s\n' resetprop
    else
        return 1
    fi
}

write_status() {
    printf '%s\n' "$1" > "$STATUS_FILE"
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)" "$1" >> "$LOG_FILE"
}

apply_prjname() {
    RESETPROP=$(resolve_resetprop) || {
        write_status skipped:no_resetprop
        return 0
    }
    detect_ui_family >/dev/null 2>&1 || {
        write_status skipped:unsupported_ui
        return 0
    }
    SOC_MODEL=$(detect_soc) || {
        write_status skipped:unsupported_soc
        return 0
    }
    PRJNAME=$(prjname_for_soc "$SOC_MODEL") || {
        write_status "skipped:no_prjname_map:soc=$SOC_MODEL"
        return 0
    }
    "$RESETPROP" ro.boot.prjname "$PRJNAME" 2>/dev/null || {
        write_status error:resetprop_failed
        return 0
    }
    CURRENT=$(getprop ro.boot.prjname 2>/dev/null)
    if [ "$CURRENT" = "$PRJNAME" ]; then
        write_status "applied:soc=$SOC_MODEL,prjname=$PRJNAME"
    else
        write_status "error:verify_failed:current=$CURRENT"
    fi
    return 0
}

case "$1" in
    apply) apply_prjname ;;
    status)
        printf 'feature=sideload_hmbird_prjname\n'
        [ -f "$STATUS_FILE" ] && printf 'status=%s\n' "$(sed -n '1p' "$STATUS_FILE")" || printf 'status=unknown\n'
        ;;
    *)
        echo "Usage: $0 {apply|status}" >&2
        exit 64
        ;;
esac
