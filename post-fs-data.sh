#!/system/bin/sh

# 侧载风驰ko：开机早期只做校验。
# 与「慕容显示增强」原脚本一致：风驰节点在安装阶段写入 DTBO，开机时 KO 仅
# 校验并复用（probe_only=1），绝不在 post-fs-data 阶段动态创建节点。
# ro.boot.prjname 等敏感属性不在开机早期触碰（由 service.sh 在系统启动完成后处理）。

MODDIR=${0%/*}
HMBIRD_HELPER="$MODDIR/scripts/hmbird_apply.sh"

if [ -f "$HMBIRD_HELPER" ]; then
    sh "$HMBIRD_HELPER" apply >/dev/null 2>&1 || true
fi

exit 0
