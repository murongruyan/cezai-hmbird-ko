# 侧载风驰ko

从「慕容显示增强」模块中抽取的独立**风驰（hmbird）KO 侧载模块**。只包含 `bin/hmbird.ko` 及其开机加载逻辑，不包含 DTBO / DRM-KO 超频后端、WebUI 与授权组件。

开源仓库：https://github.com/murongruyan/cezai-hmbird-ko （GPL-3.0）

## 功能

- 开机早期（post-fs-data）自动侧载风驰 KO：按 `hmbird_<soc>_<当前内核版本>.ko` →
  同 SoC 其它内核版本 → `hmbird.ko` 的候选顺序加载，vermagic 不匹配时自动回退。
- 仅接受 ColorOS / Realme UI。
- 按 `ro.soc.model` 自动选择节点类型：
  - `SM8850 / SM8850P / SM8845 / MT6995` → `HMBIRD_EXT`
  - `SM8750 / SM8750P / SM8650 / SM8650P / MT6991 / MT6993` → `HMBIRD_OGKI`
- 每次开机自动重设设备云控 ID（`ro.boot.prjname`），**只改属性，不清数据、不重启服务**；
  刷入时（customize.sh）另执行一次完整的 COSA 刷新流程（见下）。
- DTBO 已有风驰节点时只校验并复用，不重复创建；否则在内核暴露完整
  `of_changeset_*` API 时创建动态节点。
- 加载状态与日志写入 `runtime/` 下的 `status.txt` / `runtime.log`（KO）与
  `prjname_status.txt` / `prjname.log`（云控 ID）。

## 设备云控 ID（ro.boot.prjname）映射

| SoC | 云控 ID（prjname） | 节点类型 |
| --- | --- | --- |
| SM8850 / SM8850P / SM8845 | 24831 | HMBIRD_EXT |
| SM8750 / SM8750P | 24851 | HMBIRD_OGKI |
| SM8650 / SM8650P | 23851 | HMBIRD_OGKI |
| MT6991 / MT6993 | 24813 | HMBIRD_OGKI |
| MT6995 | 25815 | HMBIRD_EXT |

## 开机自动重设（post-fs-data）

每次开机，`scripts/prjname_apply.sh` 按上表对 `ro.boot.prjname` 执行
`resetprop`（优先 KernelSU 自带 resetprop，其次 Magisk）并校验生效。
只改属性，不清除 `com.oplus.cosa` 数据、不重启游戏助手服务。

## 刷入脚本（customize.sh）

参照「慕容调度」风驰配置的设备云控流程，刷入时自动执行：

1. `resetprop ro.boot.prjname <云控 ID>`，并校验生效。
2. `pm clear com.oplus.cosa` 清除应用增强数据，让 COSA 按新项目号重新走一遍。
3. `setprop persist.sys.oplus.gameswitch.enable 0` → 等 2 秒 → 置回 `1`，重启游戏助手服务。

说明：

- 以上任一步不满足条件（非 ColorOS/Realme UI、SoC 无映射、无 resetprop、未安装
  com.oplus.cosa 等）只跳过对应步骤并继续安装，不影响 KO 侧载本身。
- 若后续拿到重新编译、白名单包含 MT6995 的 `hmbird.ko`，可删除
  `scripts/hmbird_apply.sh` 里的 `insmod_alias=SM8850` 别名（KO 内部校验限制的过渡方案，
  不影响节点行为）。

## 安装

1. 下载本仓库，将仓库根目录打包为 ZIP（根目录须包含 `module.prop` 与
   `customize.sh`），或从 Releases 下载成品。
2. 在 KernelSU / Magisk 管理器中刷入该 ZIP。
3. 重启。

## 状态查看

```sh
MODDIR=/data/adb/modules/sideload_hmbird
sh "$MODDIR/scripts/hmbird_apply.sh" status
sh "$MODDIR/scripts/prjname_apply.sh" status
cat "$MODDIR/runtime/status.txt"
cat "$MODDIR/runtime/prjname_status.txt"
```

KO 常见状态：
- `applied:node_present=Y,node_created=...`：节点已就绪（DTBO 复用或动态创建）。
- `applied:module_existing,type=...`：本机已有匹配的风驰模块，校验通过直接复用。
- `blocked:existing_module_mismatch`：已存在同名模块但参数不匹配，未加载。
- `unsupported:ui_family` / `unsupported:soc_model`：非 ColorOS/Realme UI 或不支持的 SoC。
- `error:insmod:N`：insmod 失败，返回码见日志。

云控 ID 常见状态：
- `applied:soc=...,prjname=...`：已按 SoC 重设并校验生效。
- `skipped:no_resetprop` / `skipped:unsupported_ui` / `skipped:unsupported_soc`：条件不满足，跳过。
- `error:verify_failed` / `error:resetprop_failed`：重设失败，见日志。

## 构建

KO 编译自 `src/ko/hmbird.c`：`bash src/ko/build.sh hmbird`（需准备目标设备内核树与
Kbuild 输出，见脚本内环境变量）。当前 `bin/hmbird.ko` 的 SoC 白名单不含 MT6995，
重新编译加入 MT6995 后，可按上文提示删除 `scripts/hmbird_apply.sh` 里的 insmod 别名。

### 用 GitHub Actions 云端编译（推荐）

KO 与设备内核 ABI 强绑定（vermagic / 符号 CRC），必须用对应机型的内核源码编译。
仓库内置「云端编译风驰 KO」工作流，**纯 GitHub 云端 runner 完成**，借鉴
[cctv18](https://github.com/cctv18) 的方案：aria2 16 连接拉取内核源码 zip +
预打包的 LLVM 工具链，只做 `modules_prepare`（不编整个内核），单个 SoC 十几分钟、
多个 SoC 并行构建。

用法：仓库页 Actions →「云端编译风驰 KO」→ Run workflow：

- `soc`：`all` = **动态枚举官方内核源码全部发布分支**（构建时实时拉取 7 个官方
  源码镜像仓库的分支，当前约 32 个，新 OTA 分支出现后自动纳入）；也可选单个 SoC；
- `kernel_branch`：覆盖分支（设备 OTA 与表中不一致时填对应分支）；
- `localversion`：覆盖内核版本后缀（设备 `uname -r` 中版本号之后的部分）；
- `attach_release`：`yes` 时把编译产物发布到 GitHub Release。

已知真机版本串的分支（见 `ko-localversions.json`）产出可直接加载的 KO；其余分支
产出占位构建（vermagic 为纯版本号），拿到对应设备 `uname -r` 后以 `localversion`
重编即可精确匹配。

| SoC | 默认内核源码分支（cctv18 镜像） | 工具链 |
| --- | --- | --- |
| sm8850 | `oneplus/sm8850_v_16.0.0_oneplus_15`（6.12） | LLVM Clang 19 |
| sm8750 | `oneplus/sm8750_v_16.0.0_oneplus_13_6.6.89`（6.6） | LLVM Clang 18 |
| sm8650 | `oneplus/sm8650_v_15.0.0_oneplus12_6.1.118`（6.1） | LLVM Clang 18 |
| mt6991 | `oneplus/mt6991_v_15.0.2_ace5_ultra_6.6.89`（6.6，天玑9400+） | LLVM Clang 18 |
| mt6993 | `oppo/mt6993_b_16.0.0_find_x9`（6.12，天玑9500） | LLVM Clang 19 |

MT6995 暂无公开内核源码，暂不支持云端编译；在源码发布前，该机型沿用
`hmbird.ko` + `soc_model=SM8850` 别名方案（vermagic 可能不匹配，见日志排查）。

产物为 `hmbird_<soc>_<内核版本>.ko`（文件名带内核小版本，多个 OTA 版本可共存于
`bin/`），Release 说明里会附该 KO 的 vermagic，可与设备 `cat /proc/version` 比对确认。

> 提示：KO 与内核 ABI 强绑定，同一 SoC 不同机型 / 不同 OTA 的 vermagic 可能不同；
> 加载失败（`error:insmod`）时按上文 `kernel_branch` + `localversion` 换成自己
> 机型/OTA 的分支重新编译（`localversion` 填设备 `uname -r` 中版本号之后的部分）。
> 目前内置版本：sm8850 6.12.23、sm8750 6.6.89 与 6.6.118、sm8650 6.1.118、
> mt6991 6.6.89、mt6993 6.12.23，另有通用 `hmbird.ko`（RMX5200 6.12）。

## 发版工作流（GitHub Actions）

仓库内置自动化发版，两种用法：

- **手动发版（推荐）**：仓库页 Actions → 「打包发布 Release」→ Run workflow，可填：
  - `version`：新版本号，如 `1.3`（可带 `v` 前缀；留空沿用 module.prop 当前版本）；
  - `version_code`：新 versionCode（留空保持不变）；
  - `changelog`：本版本更新日志（留空则自动截取）。

  运行后自动完成：修改 `module.prop` 版本 → 更新 `changelog.md` → 提交 → 打 tag
  `vX.Y` → 打包 ZIP（`sideload-hmbird-ko-vX.Y.zip`）→ 发布 GitHub Release。
- **推 tag 自动发版**：本地 `git tag v1.3 && git push origin v1.3`，自动打包并发布。
  更新日志优先截取 `changelog.md` 中该版本的章节；找不到时回退为上一 tag 以来的提交记录。

Release 更新日志的截取规则：`changelog.md` 中 `## vX.Y` 到下一个 `## ` 之间的内容
就是该版本的发版说明；手动发版时填写的 `changelog` 会自动写入 `changelog.md` 顶部。

## 打赏支持

如果这个模块对你有用，欢迎扫码支持一下。感谢打赏～

| 微信 | 支付宝 |
| :---: | :---: |
| ![微信打赏](img/wx.png) | ![支付宝打赏](img/zfb.jpg) |

感谢每一位支持的朋友！

## 说明

KO 与检测逻辑原样取自「慕容显示增强」（https://github.com/murongruyan/murongchaopin ，
作者：慕容茹艳），本仓库以 GPL-3.0 开源，仅为独立侧载包装。
