#!/system/bin/sh

# 侧载风驰ko：独立风驰 KO 加载器。
# 从「慕容显示增强」的 scripts/hmbird_backend.sh apply 路径抽取，仅保留 KO 侧载逻辑，
# 不包含 DTBO 打包/刷写。检测与参数完全保持原模块行为。

MOD_DIR=${0%/*}
MOD_DIR=${MOD_DIR%/*}
BIN_DIR="$MOD_DIR/bin"
KO_MODULE="$BIN_DIR/hmbird.ko"
STATE_DIR="$MOD_DIR/runtime"
STATUS_FILE="$STATE_DIR/status.txt"
LOG_FILE="$STATE_DIR/runtime.log"
SYS_MODULE_ROOT=${HMBIRD_SYS_MODULE_ROOT:-/sys/module}

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

expected_type() {
    case "$1" in
        SM8850|SM8850P|SM8845|MT6995) printf '%s\n' HMBIRD_EXT ;;
        SM8750|SM8750P|SM8650|SM8650P|MT6991|MT6993) printf '%s\n' HMBIRD_OGKI ;;
        *) return 1 ;;
    esac
}

module_parameter() {
    # Module parameters are read-only exports from hmbird.ko.  Treat a
    # missing parameter as an invalid pre-existing module rather than
    # assuming that any module with this name is ours.
    parameter="$1"
    [ -r "$SYS_MODULE_ROOT/hmbird/parameters/$parameter" ] || return 1
    sed -n '1p' "$SYS_MODULE_ROOT/hmbird/parameters/$parameter" 2>/dev/null |
        tr -d '[:space:]'
}

existing_module_matches() {
    [ "$(module_parameter ui_valid 2>/dev/null)" = 1 ] ||
        [ "$(module_parameter ui_valid 2>/dev/null)" = Y ] || return 1
    [ "$(module_parameter soc_valid 2>/dev/null)" = 1 ] ||
        [ "$(module_parameter soc_valid 2>/dev/null)" = Y ] || return 1
    [ "$(module_parameter type_valid 2>/dev/null)" = 1 ] ||
        [ "$(module_parameter type_valid 2>/dev/null)" = Y ] || return 1
    [ "$(module_parameter node_present 2>/dev/null)" = 1 ] ||
        [ "$(module_parameter node_present 2>/dev/null)" = Y ] || return 1
    [ "$(module_parameter selected_type 2>/dev/null)" = "$HMBIRD_TYPE" ] || return 1
    [ "$(module_parameter failure_code 2>/dev/null)" = 0 ] || return 1
}

detect_dynamic_of() {
    # The module has weak references so it can load on kernels without
    # CONFIG_OF_DYNAMIC.  Only allow live-node creation when the running
    # kernel advertises the complete changeset API.
    [ -r /proc/kallsyms ] || {
        printf '%s\n' 0
        return 0
    }
    for symbol in init destroy apply revert create_node add_prop_string; do
        grep -Eq "[[:space:]]of_changeset_${symbol}[[:space:]]" /proc/kallsyms 2>/dev/null || {
            printf '%s\n' 0
            return 0
        }
    done
    printf '%s\n' 1
}

write_status() {
    printf '%s\n' "$1" > "$STATUS_FILE"
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)" "$1" >> "$LOG_FILE"
}

apply_hmbird() {
    [ -r "$KO_MODULE" ] || {
        write_status blocked:ko_missing
        return 0
    }
    UI_FAMILY=$(detect_ui_family) || {
        write_status unsupported:ui_family
        return 0
    }
    SOC_MODEL=$(detect_soc) || {
        write_status unsupported:soc_model
        return 0
    }
    HMBIRD_TYPE=$(expected_type "$SOC_MODEL") || {
        write_status unsupported:hmbird_type
        return 0
    }
    if [ -d "$SYS_MODULE_ROOT/hmbird" ]; then
        if existing_module_matches; then
            write_status "applied:module_existing,type=$HMBIRD_TYPE"
        else
            write_status blocked:existing_module_mismatch
        fi
        return 0
    fi
    chmod 0600 "$KO_MODULE" 2>/dev/null
    DYNAMIC_OF=$(detect_dynamic_of)
    # hmbird.ko 二进制构建早于 MT6995 支持，其内部 SoC 白名单不接受 MT6995。
    # KO 的节点行为只取决于 ui_family/hmbird_type（soc_model 仅用于白名单校验），
    # 因此 MT6995 以同为 HMBIRD_EXT 类的 SM8850 作为 soc_model 传入，使校验通过并
    # 按 HMBIRD_EXT 校验/创建节点。重新编译包含 MT6995 白名单的 KO 后可删除该别名。
    KO_SOC_MODEL=$SOC_MODEL
    if [ "$SOC_MODEL" = MT6995 ]; then
        KO_SOC_MODEL=SM8850
        printf '%s soc_model=MT6995 insmod_alias=SM8850\n' \
            "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)" >> "$LOG_FILE"
    fi
    insmod "$KO_MODULE" enable=1 probe_only=0 \
        dynamic_of="$DYNAMIC_OF" ui_family="$UI_FAMILY" soc_model="$KO_SOC_MODEL" hmbird_type="$HMBIRD_TYPE" \
        >/dev/null 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
        write_status error:insmod:$rc
        return 0
    fi
    node_created=$(cat "$SYS_MODULE_ROOT/hmbird/parameters/node_created" 2>/dev/null)
    node_present=$(cat "$SYS_MODULE_ROOT/hmbird/parameters/node_present" 2>/dev/null)
    selected_type=$(cat "$SYS_MODULE_ROOT/hmbird/parameters/selected_type" 2>/dev/null)
    reinit=$(cat "$SYS_MODULE_ROOT/hmbird/parameters/consumer_reinit_supported" 2>/dev/null)
    if [ "$node_present" = Y ] || [ "$node_present" = 1 ]; then
        write_status "applied:node_present=$node_present,node_created=$node_created,type=$selected_type,consumer_reinit=$reinit"
    else
        write_status "error:node_missing:type=$selected_type"
    fi
    return 0
}

case "$1" in
    apply) apply_hmbird ;;
    status)
        printf 'feature=sideload_hmbird\n'
        [ -f "$STATUS_FILE" ] && printf 'status=%s\n' "$(sed -n '1p' "$STATUS_FILE")" || printf 'status=unknown\n'
        ;;
    *)
        echo "Usage: $0 {apply|status}" >&2
        exit 64
        ;;
esac
