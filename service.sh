#!/system/bin/sh

# 云控 ID 只在系统完全启动后重设，避免在开机早期触碰敏感属性。
MODDIR=${0%/*}
PRJNAME_HELPER="$MODDIR/scripts/prjname_apply.sh"

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 1
done

[ -f "$PRJNAME_HELPER" ] &&
    sh "$PRJNAME_HELPER" apply >/dev/null 2>&1 || true
exit 0
