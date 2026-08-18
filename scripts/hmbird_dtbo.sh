#!/system/bin/sh

# 风驰 DTBO：安装阶段把风驰节点写入 DTBO（对齐原模块 prepare-dtbo 路径）。
# 节点写进 DTBO 分区后由内核直接从分区读取，与内核小版本/哈希无关，
# 不依赖 KO 加载成功；开机阶段不加载 KO，仅由内核读取持久节点。

MOD_DIR=${0%/*}
MOD_DIR=${MOD_DIR%/*}
BIN_DIR="$MOD_DIR/bin"
IMG_DIR="$MOD_DIR/img"
WORK_DIR="$MOD_DIR/workspace"
AVB_HELPER="$MOD_DIR/scripts/dtbo_avb.sh"
HMBIRD_PATCHER="$MOD_DIR/scripts/patch_hmbird_dtbo.awk"
CONFIG_DIR="$MOD_DIR/config"

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

prepare_hmbird_dtbo() {
    HMBIRD_PARTITION="$1"
    [ -n "$HMBIRD_PARTITION" ] || {
        HMBIRD_SLOT=$(getprop ro.boot.slot_suffix 2>/dev/null)
        HMBIRD_PARTITION="/dev/block/by-name/dtbo$HMBIRD_SLOT"
    }
    [ -b "$HMBIRD_PARTITION" ] || {
        echo "Error: HMBIRD DTBO target is not a block device: $HMBIRD_PARTITION" >&2
        return 1
    }
    SOC_MODEL=$(detect_soc) || {
        echo "Error: unsupported HMBIRD SoC" >&2
        return 1
    }
    HMBIRD_TYPE=$(expected_type "$SOC_MODEL") || {
        echo "Error: unsupported HMBIRD type" >&2
        return 1
    }
    [ -r "$AVB_HELPER" ] && [ -r "$HMBIRD_PATCHER" ] &&
        [ -x "$BIN_DIR/unpack_dtbo" ] && [ -x "$BIN_DIR/pack_dtbo" ] || {
        echo "Error: HMBIRD DTBO tooling is incomplete" >&2
        return 1
    }
    # KernelSU's installer enables BusyBox standalone mode.  Its BusyBox awk
    # differs from Android's awk and returns 3 for the structural parser, so
    # invoke the platform awk by absolute path for deterministic DTS parsing.
    HMBIRD_AWK=/system/bin/awk
    [ -x "$HMBIRD_AWK" ] || HMBIRD_AWK=$(command -v awk 2>/dev/null)
    [ -x "$HMBIRD_AWK" ] || {
        echo "Error: Android awk is unavailable" >&2
        return 1
    }
    . "$AVB_HELPER" || return 1

    HMBIRD_STOCK="$IMG_DIR/dtbo.img"
    HMBIRD_MANIFEST="$IMG_DIR/dtbo.img.sha256"
    HMBIRD_RECOVERY="$IMG_DIR/dtbo.img.gz"
    HMBIRD_PARTITION_SIZE=$(blockdev --getsize64 "$HMBIRD_PARTITION" 2>/dev/null)
    case "$HMBIRD_PARTITION_SIZE" in ''|*[!0-9]*|0) return 1 ;; esac

    mkdir -p "$IMG_DIR" "$WORK_DIR" "$BIN_DIR/dtbo_dts" || return 1

    # 原厂备份只创建一次：已有有效备份则复用；否则从当前分区提取，
    # 必须先通过官方 AVB 校验才允许当作基线（对齐原模块防护逻辑）。
    if ! dtbo_validate_stock_backup "$HMBIRD_STOCK" "$HMBIRD_MANIFEST" \
        "$HMBIRD_PARTITION_SIZE" "$BIN_DIR" >/dev/null 2>&1; then
        HMBIRD_CURRENT="$WORK_DIR/install-current.img"
        if ! dd if="$HMBIRD_PARTITION" of="$HMBIRD_CURRENT" bs=1 \
            count="$HMBIRD_PARTITION_SIZE" 2>/dev/null; then
            echo "Error: unable to read current DTBO" >&2
            return 1
        fi
        if ! dtbo_verify_official_image "$HMBIRD_CURRENT" \
            "$HMBIRD_PARTITION_SIZE" "$BIN_DIR" >/dev/null 2>&1; then
            echo "Error: current DTBO is not a verifiable official image" >&2
            return 1
        fi
        mv -f "$HMBIRD_CURRENT" "$HMBIRD_STOCK" || return 1
        dtbo_write_stock_manifest "$HMBIRD_STOCK" "$HMBIRD_MANIFEST" || return 1
        dtbo_write_stock_recovery "$HMBIRD_STOCK" "$HMBIRD_MANIFEST" \
            "$HMBIRD_RECOVERY" || return 1
    fi
    dtbo_validate_stock_backup "$HMBIRD_STOCK" "$HMBIRD_MANIFEST" \
        "$HMBIRD_PARTITION_SIZE" "$BIN_DIR" >/dev/null 2>&1 || {
        echo "Error: stock DTBO baseline failed validation" >&2
        return 1
    }

    # 解包 → 只按节点结构插入风驰节点（不读取机型、project-id 或显示清单）→ 打包
    for HMBIRD_STALE in "$BIN_DIR"/dtbo_dts/*.dts \
        "$BIN_DIR"/dtbo_dts/avb_info.cfg; do
        [ -f "$HMBIRD_STALE" ] && rm -f "$HMBIRD_STALE"
    done
    cd "$BIN_DIR" || return 1
    ./unpack_dtbo "$HMBIRD_STOCK" >/dev/null 2>&1 || {
        echo "Error: unable to unpack stock DTBO for HMBIRD" >&2
        return 1
    }
    HMBIRD_PATCH_COUNT=0
    HMBIRD_DTS_COUNT=0
    for HMBIRD_DTS in "$BIN_DIR"/dtbo_dts/*.dts; do
        [ -f "$HMBIRD_DTS" ] || continue
        HMBIRD_DTS_COUNT=$((HMBIRD_DTS_COUNT + 1))
        HMBIRD_PATCH_TMP="$HMBIRD_DTS.hmbird.$$"
        "$HMBIRD_AWK" -v requested_type="$HMBIRD_TYPE" -f "$HMBIRD_PATCHER" \
            "$HMBIRD_DTS" > "$HMBIRD_PATCH_TMP"
        HMBIRD_PATCH_RC=$?
        case "$HMBIRD_PATCH_RC" in
            0)
                mv -f "$HMBIRD_PATCH_TMP" "$HMBIRD_DTS" || return 1
                HMBIRD_PATCH_COUNT=$((HMBIRD_PATCH_COUNT + 1))
                ;;
            3)
                rm -f "$HMBIRD_PATCH_TMP"
                echo "Error: no unambiguous HMBIRD target structure in $HMBIRD_DTS" >&2
                return 1
                ;;
            *)
                rm -f "$HMBIRD_PATCH_TMP"
                echo "Error: malformed or conflicting HMBIRD structure in $HMBIRD_DTS" >&2
                return 1
                ;;
        esac
    done
    [ "$HMBIRD_DTS_COUNT" -gt 0 ] &&
        [ "$HMBIRD_PATCH_COUNT" -eq "$HMBIRD_DTS_COUNT" ] || {
        echo "Error: expected every DTBO entry to be patched (patched=$HMBIRD_PATCH_COUNT entries=$HMBIRD_DTS_COUNT)" >&2
        return 1
    }
    if [ "$HMBIRD_TYPE" = HMBIRD_OGKI ]; then
        echo "HMBIRD_OGKI: fragment@15/version_type/reboot_reason structure verified"
    else
        echo "HMBIRD_EXT: board overlay/config_type structure verified"
    fi
    ./pack_dtbo >/dev/null 2>&1 || {
        echo "Error: unable to pack hmbird-only DTBO" >&2
        return 1
    }

    HMBIRD_RAW="$BIN_DIR/new_dtbo.img"
    HMBIRD_FINAL="$WORK_DIR/hmbird-only-final.img"
    [ -f "$HMBIRD_RAW" ] || return 1
    dtbo_apply_stock_avb "$HMBIRD_STOCK" "$HMBIRD_RAW" "$HMBIRD_FINAL" \
        "$HMBIRD_PARTITION_SIZE" "$BIN_DIR" >/dev/null 2>&1 || {
        echo "Error: unable to apply stock AVB metadata" >&2
        return 1
    }
    dtbo_write_partition "$HMBIRD_FINAL" "$HMBIRD_PARTITION" >/dev/null 2>&1 || {
        echo "Error: unable to write hmbird-only DTBO" >&2
        return 1
    }
    HMBIRD_APPLIED_HASH=$(dtbo_hash_file "$HMBIRD_FINAL") || return 1
    [ "${#HMBIRD_APPLIED_HASH}" -eq 64 ] || return 1
    HMBIRD_PARTITION_NAME=${HMBIRD_PARTITION##*/}
    case "$HMBIRD_PARTITION_NAME" in
        dtbo|dtbo_a|dtbo_b) ;;
        *) return 1 ;;
    esac
    mkdir -p "$CONFIG_DIR" || return 1
    printf '%s\n' "$HMBIRD_APPLIED_HASH" > "$CONFIG_DIR/dtbo_applied.sha256" || return 1
    printf '%s\n' "$HMBIRD_PARTITION_NAME" > "$CONFIG_DIR/dtbo_target.txt" || return 1
    chmod 0600 "$CONFIG_DIR/dtbo_applied.sha256" "$CONFIG_DIR/dtbo_target.txt" 2>/dev/null
    echo "Success: 风驰 DTBO applied (type=$HMBIRD_TYPE, display modes unchanged)"
    return 0
}

case "$1" in
    prepare) prepare_hmbird_dtbo "$2" ;;
    *)
        echo "Usage: $0 {prepare [partition]}" >&2
        exit 64
        ;;
esac
