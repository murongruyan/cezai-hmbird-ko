# 风驰 DTBO

这是一个**持久 DTBO 风驰节点模块**。安装阶段从当前 slot 读取并校验原厂 DTBO，
只增加 `oplus,hmbird` 配置节点，再复用原厂 AVB 信息写回；重启后由内核直接读取
持久节点，不使用动态设备树注入。

风驰写入器只识别要写入的 HMBIRD 类型和 DTS 节点结构：不读取设备型号、
`ro.boot.prjname` 或 DTBO 项目标识，也不依赖显示刷新率清单。
因此设备云控 ID 与风驰 DTBO 写入是两个独立流程。

本包不包含显示超频、WebUI 或授权组件。开源仓库：
https://github.com/murongruyan/cezai-hmbird-ko （GPL-3.0）

## 节点类型

| SoC | 云控 ID（prjname） | HMBIRD 类型 |
| --- | --- | --- |
| SM8850 / SM8850P / SM8845 | 24831 | HMBIRD_EXT |
| SM8750 / SM8750P | 24851 | HMBIRD_OGKI |
| SM8650 / SM8650P | 23851 | HMBIRD_OGKI |
| MT6991 / MT6993 | 24813 | HMBIRD_OGKI |
| MT6995 | 25815 | HMBIRD_EXT |

表中的 SoC 决定 HMBIRD 节点类型；`customize.sh` 在 ColorOS / Realme UI 上继续执行
原来的云控流程，其他系统只跳过云控，不影响结构化 DTBO 写入：

1. 刷入时按 SoC 设置并校验 `ro.boot.prjname`。
2. 清理 `com.oplus.cosa`，让 COSA 按新项目号重新初始化。
3. 重启 `persist.sys.oplus.gameswitch.enable`（`0 → 1`）。
4. 每次开机由 `service.sh` 等待 `sys.boot_completed=1` 后再次设置云控 ID，
   不清数据、不重启游戏助手服务。

安装时会先完成 DTBO 生成和回读校验，再设置 `ro.boot.prjname`。这是必要的顺序：
云控属性只在 DTBO 生成、AVB 合成、分区回读全部成功后设置；即使云控属性设置失败，
也不会改变已经写入的节点。

## OGKI 结构

OGKI 必须在 `fragment@15` 的 `__overlay__` 里面增加节点，子节点名是
`version_type`，不是 `config_type`：

```dts
fragment@15 {
    target = <0xffffffff>;

    __overlay__ {
        oplus,hmbird {
            version_type {
                type = "HMBIRD_OGKI";
            };
        };

        reboot_reason {
            /* 保留原有 reboot_reason 内容 */
        };
    };
};
```

安装器在每个 DTS 中只处理唯一的 `fragment@15`，并要求唯一的 `__overlay__`、
`reboot_reason` 和 `oplus,hmbird` 结构。缺失、重复、类型冲突或无法定位时会直接
终止，不写入分区。

EXT 使用 `config_type` 结构。安装器在每个 DTS 中寻找唯一的板级 overlay：优先使用
唯一的直接子节点 `oplus-gpio`；没有该节点时，使用唯一含 `oplus_sim_detect` 的
overlay，仍找不到唯一结构就中止。这个锚点不涉及显示面板或刷新率节点，也不要求
`oplus-gpio` 额外带 `compatible` 属性。

OGKI 直接在每个 DTS 的 `fragment@15/__overlay__` 中处理，要求存在唯一的
`reboot_reason`，并把 `version_type` 节点放在它前面。两种类型都不调用显示超频版
`process_dts`。

## 安装与恢复

1. 在 KernelSU / Magisk 中刷入 ZIP。
2. 安装器验证当前 slot 的 DTBO 是可验证的原厂镜像；首次安装会保存
   `img/dtbo.img`、哈希清单和恢复副本。
3. 解包 DTBO，只添加 HMBIRD 节点，重新打包并复用原厂 AVB 元数据。
4. 写回当前 slot 的 `/dev/block/by-name/dtbo[_a|_b]`，回读和哈希校验后提示重启。
5. 重启后由内核直接读取持久节点。

如果当前 DTBO 不是可验证的官方基线，或原厂备份哈希不匹配，安装器会拒绝覆盖。
安装过程中不提供 KO/DTBO 二选一，也不在 `post-fs-data` 阶段写分区。

## 状态

安装成功后可查看：

```sh
MODDIR=/data/adb/modules/sideload_hmbird
cat "$MODDIR/config/dtbo_target.txt"
cat "$MODDIR/config/dtbo_applied.sha256"
sh "$MODDIR/scripts/prjname_apply.sh" status
cat "$MODDIR/runtime/prjname_status.txt"
```

本包不再提供 `hmbird_apply.sh`，也不包含任何 `hmbird*.ko`。因此不存在
`vermagic`、`SMP preempt mod_unload modversions aarch64` 或符号 CRC 的 KO 兼容性要求；
DTBO 方案的关键是节点结构、当前 slot 和 AVB 完整性。

## 重要提醒

DTBO 是启动配置的一部分。刷入前确认设备能进入恢复模式，并保留原厂 DTBO 备份。
不要把其他模块已经修改过的 DTBO 当作原厂基线继续覆盖；安装器检测到这种情况会
停止。若需要回退，应先停用本模块，再使用保存的原厂镜像恢复对应 slot。
