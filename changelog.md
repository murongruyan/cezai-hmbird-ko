# 更新日志

## v1.15

- 工作流切换为纯 DTBO 校验与打包，不再编译、上传或打包任何 `hmbird.ko`。
- 发布包同时包含 `service.sh` 和全部 DTBO 工具脚本，安装路径与桌面修复版一致。
- 安装阶段固定调用 Android `/system/bin/awk`，避免 KernelSU standalone BusyBox
  `awk` 误判 HMBIRD 目标结构。

## v1.14

- 模块显示名改为“风驰 DTBO”，保留 `sideload_hmbird` ID 以支持覆盖升级和复用原厂备份。
- 刷入界面改为单一路径提示，移除“KO 侧载”和“不加载 hmbird.ko”等多余说明。
- EXT 结构补丁优先按真实 DTBO 的唯一板级 `oplus-gpio` overlay 处理，并兼容没有
  `compatible` 属性的生产 DTS；OGKI 继续严格使用 `fragment@15/__overlay__/reboot_reason`
  前的 `version_type` 节点。
- 固定使用 Android `/system/bin/awk` 解析 DTS，兼容 KernelSU 安装阶段的 BusyBox
  standalone 环境，修复补丁器被错误返回码判定为“目标结构不明确”。

## v1.13

- 风驰 DTBO 写入改为独立结构补丁器，不再调用显示超频版 `process_dts`。
- 写入路径不识别 `RMX5200`，不读取 `ro.boot.prjname` 或 DTBO `project-id`，不依赖显示刷新率清单。
- EXT 按板级 overlay 结构写入 `config_type`；OGKI 严格按
  `fragment@15/__overlay__/reboot_reason` 前插入 `version_type`。
- 保留 SoC 云控 ID 映射、COSA 清理、游戏助手重启和开机后云控重设流程。

## v1.12

- 补回 `config/display_mode_manifest.txt`，修复 `process_dts` 因缺少清单而直接退出。
- 调整安装顺序：先按原厂 `project-id` 生成并写回 DTBO，再设置云控 `ro.boot.prjname`；
  避免云控 ID 与 DTBO project-id 不同导致所有 DTS 被误判为不匹配。
- DTBO 失败时在安装界面回显最后的诊断行，便于定位分区、工具或结构错误。

## v1.11

- **切换为持久 DTBO 后端**：不再加载 `hmbird.ko`，安装时直接把风驰节点写入
  当前 slot 的 DTBO，并复用原厂 AVB 元数据。
- OGKI 使用 `fragment@15 -> __overlay__ -> oplus,hmbird -> version_type`，
  不再使用 live-OF 动态创建，避免 KO 在开机阶段卡住。
- 保留刷入时和开机后的设备云控 ID、COSA 清理及游戏助手服务流程。
- 移除桌面包中的全部 `hmbird*.ko` 与 KO 加载脚本；删除的 DTBO 安装入口重新恢复
  为单一路径，不再提供 KO/DTBO 二选一。

## v1.10

- **按目标收敛为纯 KO 后端**：安装脚本不再读取、备份、解包、重打包或写入
  DTBO；开机直接按 SoC 与完整 `uname -r` 候选加载风驰 KO，并通过 live-OF
  动态挂载节点。
- 保留原有设备云控流程：刷入时设置 `ro.boot.prjname`、清理 `com.oplus.cosa`、
  重启游戏助手服务；`service.sh` 在系统启动完成后再次设置云控 ID。
- OGKI 只使用带 `version_type` 修复的专用 KO，不回退到旧的 `config_type`
  通用 KO；增加 `probe` 命令用于只校验节点的故障排查。
- 移除 DTBO 工具、DTBO 后端脚本和会恢复/写入分区的卸载入口。

## v1.9

- **修复刷入后不开机**：`post-fs-data` 只以 `probe_only=1` 校验 DTBO
  已有节点，不再在开机早期修改 live device tree；`ro.boot.prjname`
  移到系统启动完成后的 `service.sh` 执行。
- 安装时提供 HMBIRD-only DTBO 路径，复用官方 AVB 信息并在写入后回读校验。
- OGKI 严格按 `fragment@15 -> __overlay__ -> oplus,hmbird -> version_type`
  生成，节点固定放在 `reboot_reason` 之前。结构缺失、重复或类型冲突时
  中止安装，不写入分区。
- 移除全局 `config_type -> version_type` 替换，避免修改 DTS 中的无关节点。
- 禁止 OGKI 运行时 `apply-create`；OGKI 必须使用持久 DTBO 节点。
- 更新安装保留原厂 DTBO 备份；卸载时仅在当前分区仍与本模块写入哈希
  一致时恢复原厂镜像，检测到其他 DTBO 修改时拒绝覆盖。

## v1.8

- **对齐原模块安装流程**：安装时二选一——音量+ = 写入 hmbird-only DTBO（风驰节点
  进分区，与内核小版本/哈希无关，不依赖 KO 加载成功，推荐）；音量- = 跳过 DTBO
  写入（仅保留开机 KO 校验）。
- 移植原模块 DTBO 工具链（unpack_dtbo / process_dts / pack_dtbo / dtc / mkdtimg /
  openssl / avbtool + dtbo_avb.sh），含原厂基线 AVB 校验、备份、恢复与写入防护。
- OGKI 类型写入 DTBO 时把节点子名纠正为官方 `version_type`（原 process_dts 写死
  `config_type`）；EXT 保持 `config_type`。
- 开机 KO 只校验（probe_only=1）、service.sh 云控 ID 重设不变。

## v1.7

- **修复不开机问题（对齐原脚本设计）**：风驰节点在开机早期只做校验复用
  （`probe_only=1`），不再于 post-fs-data 阶段用 of_changeset 动态创建节点；
  动态创建改为系统启动完成后手动执行 `scripts/hmbird_apply.sh apply-create`。
- `ro.boot.prjname` 自动重设从 post-fs-data 挪到 `service.sh`
  （等 `sys.boot_completed=1` 后执行），与原 APK 手动设置时机一致，
  不再在开机早期触碰敏感属性。

## v1.6

- **修复关键缺陷**：`oplus,hmbird` 子节点名随类型不同——HMBIRD_OGKI（SM8750 及
  以下、天玑）应为 `version_type`，HMBIRD_EXT（SM8850/SM8845）才是 `config_type`；
  原 KO 写死 `config_type` 导致 OGKI 机型校验失败拒载。现已按类型自动选择，
  KO 版本号更新为 `0.2-hmbird-type-child`（可用 `modinfo` 确认）。
- 云端编译改为**动态枚举官方内核源码全部分支**：构建时实时拉取 7 个官方源码
  镜像仓库（6.1/6.6/6.12，含天玑）的全部分支，当前约 32 个发布分支，一次并行编译。
- 已知真机版本串的分支产出可直接加载的 KO；未知版本串的分支产出占位构建
  （vermagic 为纯版本号），拿到设备 `uname -r` 后用 `localversion` 参数重编即可。
- KO 文件命名升级为完整内核版本串：`hmbird_<soc>_<uname -r>.ko`，
  同一 SoC 不同 OTA（不同 GKI 哈希 / 厂商 build ID）的构建可共存。
- 加载器按完整 `uname -r` 精确匹配 KO，未命中再回退同 SoC 其它版本、最后通用 KO。

## v1.5

- 加载器改为按当前内核小版本精确匹配：`hmbird_<soc>_<内核版本>.ko` 优先加载，
  匹配不到再回退同 SoC 其它版本、最后通用 `hmbird.ko`；多个 OTA 版本可共存于 `bin/`。
- `bin/` 内 KO 全部改为带内核版本号命名。
- 新增 `hmbird_sm8750_6.6.118.ko`（vermagic
  `6.6.118-android15-8-g93e223c276e7-abogki500782043-4k`，6.6.118 OTA 用）。

## v1.4

- 云端编译新增天玑构建腿：mt6991（天玑9400+，Ace5 Ultra，6.6.89）、
  mt6993（天玑9500，Find X9，6.12.23），vermagic 与真机精确匹配。
- `bin/` 新增 `hmbird_mt6991.ko`、`hmbird_mt6993.ko`，加载器按 SoC 优先加载对应 KO。
- MT6995 暂无公开内核源码，暂不支持云端编译（沿用通用 KO + SM8850 别名）。

## v1.3

- 新增「云端编译风驰 KO」工作流：借鉴 [cctv18](https://github.com/cctv18) 方案
  （aria2 多线程拉内核源码 zip + 预打包 LLVM 工具链 + 仅 modules_prepare），
  纯 GitHub 云端 runner 按 SoC 并行编译，单个 SoC 约 2 分钟。
- 支持 localversion 参数：把真机内核版本后缀烤进 KO，vermagic 与设备内核精确匹配。
- 新增按机型内核树编译的 `hmbird_sm8850.ko` / `hmbird_sm8750.ko` / `hmbird_sm8650.ko`。
- 加载器改为多候选顺序回退：机型 KO 加载失败（多为 vermagic 不匹配）自动尝试下一候选。
- 修复 v1.2 在 SM8750 上无法加载的问题（原 KO 为 RMX5200 6.12 内核构建，vermagic 不匹配）。

## v1.2

- 新增 GitHub Actions 发版工作流：自动修改版本号、打 tag、打包 ZIP、发布 Release，更新日志自动截取。
- 每次开机自动重设设备云控 ID（ro.boot.prjname），仅改属性、不清数据、不重启服务。
- 刷入脚本按 SoC 设置云控 ID，并清除应用增强数据、重启游戏助手服务。
- 云控 ID 映射：SM8850 系 24831、SM8750 系 24851、SM8650 系 23851、MT6991/6993 24813、MT6995 25815。
- 新增 MT6995 支持（HMBIRD_EXT，insmod 以 SM8850 别名过渡）。
- 首次发布：独立风驰 KO 侧载、HMBIRD_EXT / HMBIRD_OGKI 自动分派、DTBO 节点校验复用。
