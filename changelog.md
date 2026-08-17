# 更新日志

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
