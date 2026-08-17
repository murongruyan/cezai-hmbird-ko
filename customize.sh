#!/system/bin/sh

# 侧载风驰ko 刷入脚本（customize.sh）
# 参照「慕容调度」风驰配置的设备云控流程，刷入时按 SoC 自动设置设备云控 ID：
#   1) resetprop ro.boot.prjname <按 SoC 的云控 ID>
#   2) 校验属性已生效
#   3) 清除应用增强数据（pm clear com.oplus.cosa），让 COSA 按新项目号重新走一遍
#   4) 重启游戏助手服务（persist.sys.oplus.gameswitch.enable 0 → 1）
# 任何一步不满足条件都会跳过并继续安装，不影响 KO 侧载本身（KO 在开机时另行按
# ColorOS/Realme UI 与 SoC 门控加载）。

echo ""
echo "********************************************"
echo "  侧载风驰ko：设备云控 ID 自动设置"
echo "********************************************"

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

RESETPROP=
if [ -x /data/adb/ksu/bin/resetprop ]; then
    RESETPROP=/data/adb/ksu/bin/resetprop
elif [ -x /data/adb/magisk/resetprop ]; then
    RESETPROP=/data/adb/magisk/resetprop
elif command -v resetprop >/dev/null 2>&1; then
    RESETPROP=resetprop
fi

if [ -z "$RESETPROP" ]; then
    echo "- 未找到 resetprop，跳过设备云控 ID 设置"
    exit 0
fi

UI_FAMILY=$(detect_ui_family) || {
    echo "- 未识别 ColorOS/Realme UI，跳过设备云控 ID 设置"
    exit 0
}
SOC_MODEL=$(detect_soc) || {
    echo "- 未识别受支持 SoC，跳过设备云控 ID 设置"
    exit 0
}
PRJNAME=$(prjname_for_soc "$SOC_MODEL") || {
    echo "- SoC=$SOC_MODEL 无云控 ID 映射，跳过"
    exit 0
}

echo "- SoC=$SOC_MODEL, UI=$UI_FAMILY → 设备云控 ID=$PRJNAME"
"$RESETPROP" ro.boot.prjname "$PRJNAME" || {
    echo "! resetprop ro.boot.prjname 执行失败"
    exit 0
}
CURRENT_PRJNAME=$(getprop ro.boot.prjname 2>/dev/null)
if [ "$CURRENT_PRJNAME" != "$PRJNAME" ]; then
    echo "! ro.boot.prjname 校验失败：当前=$CURRENT_PRJNAME 期望=$PRJNAME"
    exit 0
fi
echo "- ro.boot.prjname 已设置为 $PRJNAME"

# 参考项目后续动作 1：清除应用增强数据，让 COSA 按新项目号重新走一遍
if pm path com.oplus.cosa >/dev/null 2>&1; then
    if pm clear com.oplus.cosa >/dev/null 2>&1; then
        echo "- 已清除应用增强数据（com.oplus.cosa）"
    else
        echo "! 清除应用增强数据失败"
    fi
else
    echo "- 未检测到 com.oplus.cosa，跳过数据清除"
fi

# 参考项目后续动作 2：重启游戏助手服务
setprop persist.sys.oplus.gameswitch.enable 0
sleep 2
setprop persist.sys.oplus.gameswitch.enable 1
echo "- 已重启游戏助手服务（persist.sys.oplus.gameswitch.enable 0→1）"

echo "- 云控 ID 设置完成。此后每次开机模块会在 post-fs-data 自动重设 ro.boot.prjname（只改属性，不清数据）。"
exit 0
