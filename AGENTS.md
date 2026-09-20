# AGENTS.md

## 构建与安装（重要）

每次改完代码需要验证时，**必须同时同步模拟器与真机**，不要只装其中一个。

一键脚本：

```
bash scripts/sync.sh
```

脚本会先构建并安装到模拟器，再构建并安装到真机（含启动）。可用环境变量覆盖：`SIM_UDID`、`DEVICE_UDID`、`DEVELOPMENT_TEAM`。

## 环境信息

- 模拟器 UDID：`928C09EA-3720-4D66-BA17-732A264FB76C`（iPhone 16 Pro），构建目录 `.build/dd`
- 真机 UDID：`00008030-000804100CE8802E`，构建目录 `.build/device`
- 真机 Team ID：`T8TG4WAR43`；免费账号签名 7 天过期，需重签并在手机信任开发者
- Bundle ID：`com.liuzixiang.Yijing64`
- `project.yml` 中 `CODE_SIGNING_ALLOWED/REQUIRED` 为 NO，真机构建需命令行覆盖

## 其他

- 新增 `YijingCore` 源文件后需先运行 `xcodegen generate` 重新生成工程
- 测试：`cd YijingCore && swift test`
- 提交信息使用中文，风格：`Add <主题>：<要点>`
