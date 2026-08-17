# 更新日志

## v1.2

- 新增 GitHub Actions 发版工作流：自动修改版本号、打 tag、打包 ZIP、发布 Release，更新日志自动截取。
- 每次开机自动重设设备云控 ID（ro.boot.prjname），仅改属性、不清数据、不重启服务。
- 刷入脚本按 SoC 设置云控 ID，并清除应用增强数据、重启游戏助手服务。
- 云控 ID 映射：SM8850 系 24831、SM8750 系 24851、SM8650 系 23851、MT6991/6993 24813、MT6995 25815。
- 新增 MT6995 支持（HMBIRD_EXT，insmod 以 SM8850 别名过渡）。
- 首次发布：独立风驰 KO 侧载、HMBIRD_EXT / HMBIRD_OGKI 自动分派、DTBO 节点校验复用。
