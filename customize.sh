#!/system/bin/sh

# 风驰 DTBO 刷入脚本：持久 DTBO 后端。
# 云控 ID 流程仍按原模块执行；风驰节点由 hmbird_dtbo.sh 写入当前 slot 的 DTBO。
SKIPUNZIP=0

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

prjname_for_soc() {
    case "$1" in
        SM8850|SM8850P|SM8845) printf '%s\n' 24831 ;;
        SM8750|SM8750P)        printf '%s\n' 24851 ;;
        SM8650|SM8650P)        printf '%s\n' 23851 ;;
        MT6991|MT6993)         printf '%s\n' 24813 ;;
        MT6995)                printf '%s\n' 25815 ;;
        *) return 1 ;;
    esac
}

echo ""
echo "********************************************"
echo "  风驰 DTBO：风驰节点 + 设备云控"
echo "********************************************"

# 云控属性必须在 DTBO 处理完成后再设置。DTBO 写入器只按节点结构工作，
# 与机型名、project-id 和显示清单无关；云控流程仍在写入成功后执行。
apply_cloud_control() {
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
else
    UI_FAMILY=$(detect_ui_family) || UI_FAMILY=
    SOC_MODEL=$(detect_soc) || SOC_MODEL=
    if [ -z "$UI_FAMILY" ]; then
        echo "- 未识别 ColorOS/Realme UI，跳过设备云控 ID 设置"
    elif [ -z "$SOC_MODEL" ]; then
        echo "- 未识别受支持 SoC，跳过设备云控 ID 设置"
    else
        PRJNAME=$(prjname_for_soc "$SOC_MODEL") || PRJNAME=
        if [ -z "$PRJNAME" ]; then
            echo "- SoC=$SOC_MODEL 无云控 ID 映射，跳过"
        else
            echo "- SoC=$SOC_MODEL, UI=$UI_FAMILY → 设备云控 ID=$PRJNAME"
            "$RESETPROP" ro.boot.prjname "$PRJNAME" ||
                echo "! resetprop ro.boot.prjname 执行失败"
            CURRENT_PRJNAME=$(getprop ro.boot.prjname 2>/dev/null)
            [ "$CURRENT_PRJNAME" = "$PRJNAME" ] ||
                echo "! ro.boot.prjname 校验失败：当前=$CURRENT_PRJNAME 期望=$PRJNAME"
            if pm path com.oplus.cosa >/dev/null 2>&1; then
                if pm clear com.oplus.cosa >/dev/null 2>&1; then
                    echo "- 已清除应用增强数据（com.oplus.cosa）"
                else
                    echo "! 清除应用增强数据失败"
                fi
            else
                echo "- 未检测到 com.oplus.cosa，跳过数据清除"
            fi
            setprop persist.sys.oplus.gameswitch.enable 0
            sleep 2
            setprop persist.sys.oplus.gameswitch.enable 1
            echo "- 已重启游戏助手服务（persist.sys.oplus.gameswitch.enable 0→1）"
        fi
    fi
fi
}

MODPATH=${MODPATH:-${0%/*}}
INSTALLED_MOD_PATH=/data/adb/modules/sideload_hmbird

# 更新安装时沿用已验证的原厂 DTBO 基线，避免把上一次写入的镜像当成原厂。
if [ "$INSTALLED_MOD_PATH" != "$MODPATH" ]; then
    for relative_path in img/dtbo.img img/dtbo.img.sha256 img/dtbo.img.gz; do
        source_file="$INSTALLED_MOD_PATH/$relative_path"
        target_file="$MODPATH/$relative_path"
        if [ -f "$source_file" ] && [ ! -L "$source_file" ] && [ ! -f "$target_file" ]; then
            mkdir -p "${target_file%/*}" || abort "无法保留 DTBO 备份目录"
            cp -p "$source_file" "$target_file" || abort "无法保留 DTBO 备份"
        fi
    done
fi

BIN_DIR="$MODPATH/bin"
for install_tool in avbtool/avbtool openssl dtc mkdtimg unpack_dtbo pack_dtbo; do
    [ -f "$BIN_DIR/$install_tool" ] || abort "缺少 DTBO 工具：$install_tool"
    chmod 0755 "$BIN_DIR/$install_tool" || abort "无法设置 DTBO 工具权限"
done
chmod 0755 "$BIN_DIR/avbtool/"*.so 2>/dev/null

ui_print "正在生成并写入风驰 DTBO 节点"
HMBIRD_LOG="$MODPATH/runtime/hmbird_dtbo_install.log"
mkdir -p "${HMBIRD_LOG%/*}" 2>/dev/null
if sh "$MODPATH/scripts/hmbird_dtbo.sh" prepare >"$HMBIRD_LOG" 2>&1; then
    ui_print "风驰 DTBO 写入成功"
else
    ui_print "HMBIRD DTBO 失败原因："
    tail -n 12 "$HMBIRD_LOG" 2>/dev/null | while IFS= read -r hmbird_line; do
        [ -n "$hmbird_line" ] && ui_print "$hmbird_line"
    done
    abort "风驰 DTBO 写入失败，已停止安装"
fi

# DTBO 生成、AVB 合成和分区回读均成功后，才执行原模块的云控流程。
apply_cloud_control

ui_print "风驰节点已写入当前 slot 的 DTBO，请重启设备"
exit 0
