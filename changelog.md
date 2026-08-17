# 更新日志

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
