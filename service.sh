#!/system/bin/sh

# 侧载风驰ko：系统完全启动后才执行的轻量任务。
# 参照「慕容显示增强」原模块 service.sh 的等待方式（sys.boot_completed=1），
# 避免在开机早期触碰 ro.boot.prjname 等敏感属性——与原 APK 手动设置时机一致。

MODDIR=${0%/*}
PRJNAME_HELPER="$MODDIR/scripts/prjname_apply.sh"

# 等待系统启动完成
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 1
done

# 系统就绪后按 SoC 重设设备云控 ID（只改属性，不清数据、不重启服务）
if [ -f "$PRJNAME_HELPER" ]; then
    sh "$PRJNAME_HELPER" apply >/dev/null 2>&1 || true
fi

exit 0
