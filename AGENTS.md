# AGENTS.md

Agent 指南：ScrcpyMenu — macOS 菜单栏 scrcpy GUI 工具。

## 项目概览

- 纯 Swift Package（executable target，Swift 6.0 tools，macOS 13+），无 Xcode 工程、无第三方依赖
- AppKit `NSStatusItem` + `NSMenu` 实现；Bundle ID `com.yugy.scrcpy-menu`；`LSUIElement=true`（无 Dock 图标）
- 默认分支：`main`；GitHub: kyze8439690/ScrcpyMenu

## 构建与常用命令

| 命令 | 作用 |
|---|---|
| `make build` | 双架构（arm64 + x86_64）release 编译 + lipo 合并 → `build/ScrcpyMenu` |
| `make app` | 打包**开发版** `ScrcpyMenu Dev.app`（橙色图标、bundle id `com.yugy.scrcpy-menu.dev`、ad-hoc 签名），与 Release 正式版并存区分 |
| `make zip VERSION=vX.Y.Z` | DEV=0 打包正式版 `ScrcpyMenu.app` + ditto 打 release zip → `build/` |
| `make icon` | 重新生成 `Resources/AppIcon.icns`（SF Symbol 程序化绘制） |
| `make run` | 构建并启动 |
| `make clean` | 清理 `.build`、`build/`、`ScrcpyMenu.app` |

注意：`swift build --arch arm64 --arch x86_64` 需要完整 Xcode；只有 CLT 时必须用 Makefile 的 per-arch + lipo 方式。

## 代码结构（Sources/ScrcpyMenu/）

- `main.swift` — 入口，`setActivationPolicy(.accessory)`，挂 AppDelegate
- `AppDelegate.swift` — @MainActor UI 编排核心：status item、菜单构建（`rebuildMenu`）、`menuWillOpen` 时自动刷新设备、创建 DeviceManager/ScrcpyManager 并连接回调（onStateChange → rebuildMenu，onFailure → alert）
- `DependencyChecker.swift` — scrcpy/adb 查找：固定目录（/opt/homebrew/bin、/usr/local/bin，adb 另有 ~/Library/Android/sdk/platform-tools）→ $PATH 兜底
- `DeviceManager.swift` — `adb devices -l` 解析（parseDevices）、串行队列 + 缓存、Shell.run 带 5s 超时；无轮询，靠 menuWillOpen/手动 Refresh 触发
- `ScrcpyProcess.swift` — ScrcpyManager 进程管理：toggle 启停、日志写 `~/Library/Logs/ScrcpyMenu/`、启动 <3s 非零退出判定为失败并回调、`stopAll` 退出清理（SIGTERM → 2s → SIGKILL）
- `Models.swift` — AndroidDevice（serial/model/state）、DeviceState

## 约定与注意事项

- 不添加注释，除非被要求；遵循现有代码风格
- 菜单栏图标必须用 template 渲染的 SF Symbol（深浅色自适应），不要用 emoji/彩色图
- 设备列表不轮询；所有 adb 调用必须有超时（当前 5s）
- 只管理本应用启动的 scrcpy 进程
- 版本号在 `Resources/Info.plist`；CI release 时由 tag 注入，无需手动改
- 无测试 target（用户决定暂不写测试）

## 发布流程

1. 提交并推送 main
2. `git tag vX.Y.Z && git push origin vX.Y.Z`
3. `.github/workflows/release.yml` 自动：注入版本号 → `make zip` → `gh release create`（--generate-notes）
