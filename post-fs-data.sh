#!/system/bin/sh

# 侧载风驰ko：开机早期侧载独立风驰 KO（hmbird.ko），并自动重设设备云控 ID。
# 检测逻辑与原「慕容显示增强」的 scripts/hmbird_backend.sh apply 路径保持一致。

MODDIR=${0%/*}
HMBIRD_HELPER="$MODDIR/scripts/hmbird_apply.sh"
PRJNAME_HELPER="$MODDIR/scripts/prjname_apply.sh"

# 先重设设备云控 ID（只改 ro.boot.prjname，不清数据、不重启服务），
# 让稍后启动的 COSA 按目标项目号拉取风驰云控。
if [ -f "$PRJNAME_HELPER" ]; then
    sh "$PRJNAME_HELPER" apply >/dev/null 2>&1 || true
fi

# 再按 ColorOS/Realme UI 与 SoC 门控侧载独立风驰 KO。
if [ -f "$HMBIRD_HELPER" ]; then
    sh "$HMBIRD_HELPER" apply >/dev/null 2>&1 || true
fi

exit 0
