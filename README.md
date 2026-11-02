# Msgbox

完全离线的 macOS 26+ 菜单栏聊天角标聚合器。Swift 6、SwiftUI、AppKit，无依赖。

## 安装与使用

正式安装：`/Applications/Msgbox.app`，在 Finder 的“应用程序”中打开。应用图标与菜单栏使用同一个双气泡图形。旧用户目录副本保存在项目 `build/previous-user-Msgbox.app`，不再作为日常入口。

菜单栏仅在有未读时把数字叠在图标右上角，没有数字底色、边框或胶囊。总数为 0 时只显示图标；达到 1000 时显示 `999+`。菜单项固定 38 pt，内部图标位置固定，不因数字位数改变挤动其他图标。展开列表保留系统提供的完整数量和合计。

点击菜单栏图标，在列表底部点“设置…”（⌘,）打开设置窗口。“软件筛选”可分别勾选微信、QQ、Telegram，默认全部勾选；取消后立即停止参与角标读取、合计和列表显示。选择自动保存在本机，重启后保留，也可全部取消；空列表会提示前往设置选择软件。“关于 Msgbox”显示版本、软件简介和隐私说明。

设置内“登录时启动”使用 macOS 原生登录项，可随时开启或关闭；首次安装不自动开启。系统要求批准时会显示明确提示与设置入口，失败会显示原因；登录启动静默驻留菜单栏，手动打开显示列表。测试进程不创建菜单栏项，普通多副本启动会回到已运行实例。

## 构建与运行

1. 用 Xcode 26 打开 `Msgbox.xcodeproj`，选择 **Msgbox → My Mac**。
2. 按 ⌘R。启动时直接显示“聊天未读 · Msgbox”列表窗口，同时显示菜单栏气泡图标，不显示 Dock 图标；关闭窗口后继续从菜单栏使用。重新打开应用会再次显示同一列表窗口。
3. 默认不请求权限。若需要检测角标，先阅读界面说明，再主动打开“辅助功能设置”，由你手动添加并开启实际构建的 `Msgbox.app`。授权后返回点击刷新。
4. 按 ⌘U 执行 XCTest。无开发团队也可本地 ad-hoc 构建；发布签名/公证不在 MVP 范围。

命令行（在项目目录）：

```sh
xcodebuild -project Msgbox.xcodeproj -scheme Msgbox -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build build
xcodebuild -project Msgbox.xcodeproj -scheme Msgbox -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build -resultBundlePath logs/Tests-new.xcresult test
xcodebuild -project Msgbox.xcodeproj -scheme Msgbox -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath build-release build analyze
open build-release/Build/Products/Release/Msgbox.app
python3 scripts/audit.py
python3 scripts/idle_measure.py
```

测量脚本需要在普通 macOS 用户终端运行，启动且最终结束它自己创建的 Release 实例；请先退出其他 Msgbox 实例。它只检查该进程，不读取其他聊天应用内容，不修改权限。结果位于 `logs/`。

## macOS 26 菜单栏图标缺失

先检查系统设置 → 菜单栏 → 允许在菜单栏中 → Msgbox。菜单栏显示与读取角标的辅助功能权限是两件事。

本机 2026-11-02 已定位并解决一次宿主关联问题：Msgbox 被系统关联到显示名称为 **ChatGPT**、Bundle ID 为 `com.openai.codex` 的开发工具。经用户授权开启 **ChatGPT** 的菜单栏显示后，Control Center 立即记录 `Unblocking host`，独立的 Msgbox 开关也出现并开启；用户已确认图标可见、点击能打开列表。此前只开启 Codex Computer Use 无效。此结论针对本机实测，不代表所有机器都需要开启 ChatGPT。

当前可直接打开 `/Applications/Msgbox.app`（与已验证 Release 构建相同）。Xcode 构建路径与它是不同副本，调试前先退出已运行的 Msgbox，避免重复实例。Hidden Bar 已恢复运行；图标为两个重叠对话气泡。

## 状态含义

- 菜单栏数字是**设置中已勾选应用的未读角标数字之和**（支持微信、QQ、Telegram）；展开列表分别显示所选应用数量，并显示合计。例如 12、3、7 合计为 22。
- 只汇总 Dock 提供的角标，不代表聊天内的全部未读；关闭角标或静音设置可影响结果。
- 数字为已读取的角标值；`99+` 或固定圆点显示“有未读”。
- 部分应用有未读但无精确数值，或读取失败/无权限时，合计显示已知数加 `+`（如 `12+`）；没有已知正数时显示 `?`，不伪装成 0。未安装/未运行的应用不计入合计。
- 成功读取空字符串、`0` 或系统明确返回 `AXError.noValue`（角标没有值）时显示“0 条未读（无角标）”；不支持角标属性、未知格式、读取错误一律显示“未知”。
- “未安装”“未运行”“需要辅助功能权限”分别显示。无权限时仍可主动打开聊天应用。
- 单击列表项统一调用系统打开应用接口，并复用已有进程。窗口已关闭但应用仍运行时也会收到重新打开请求；微信、QQ、Telegram 的这一场景已由用户确认恢复。特殊窗口的最终响应仍由聊天应用决定。

真实兼容性尚待人工验收，尤其 Dock 的非公开 `AXStatusLabel` 属性，参见 [技术验证](docs/FEASIBILITY.md)、[人工验收](docs/HUMAN_ACCEPTANCE.md)、[最终报告](docs/FINAL_REPORT.md)。不含联网、消息内容、自动更新或额外后台服务；登录时启动由用户自行选择。

## Telegram 顶部有数字但未计入

Telegram 顶部菜单栏的数字与底部 Dock 角标是两个显示入口。Msgbox 读取底部 Dock；顶部有数字不能证明 Dock 已提供角标。本机排查发现 macOS 系统设置 → 通知 → Telegram 的“允许通知”关闭，导致“应用图标角标”也被禁用。经用户授权，已开启通知总开关并仅保留应用角标，关闭桌面、通知中心、锁屏显示和声音。2026-11-02 15:48:52 正式版实际读到 Telegram=8、微信=1、QQ=0、合计=9，已验证 Telegram 正数角标计入合计。顶部菜单栏数字自身不作为读取来源。

本地临时签名在构建变化后可能需要重新添加固定路径的 Msgbox 辅助功能授权并重启应用；不要用给开发工具额外授权替代。

## 省电与扩展

普通授权轮询 3 秒，低电量模式 6 秒，无权限/无目标 15 秒；睡眠和熄屏暂停。只响应受支持聊天应用的启停事件。应用图标按路径缓存，运行进程每轮只枚举一次，列表状态不变时不重复发布；菜单栏图片只在显示数字变化时更新，使用原生按钮和普通模板图片，避免 macOS 26 自定义菜单栏视图反复生成快照。

增加 Slack、Discord 等应用：在 `Msgbox/Monitor.swift` 的 `ChatApp.supported` 中添加一项实际 Bundle ID 和显示名称即可，共用 Dock 匹配、权限处理、合计、排序和打开逻辑；不需要新建适配器。可从目标安装包的 `Contents/Info.plist` 读取 Bundle ID。应额外验收该应用是否向 Dock 暴露数字角标；圆点或被应用缩写的数量无法恢复为精确消息数。本次没有提前启用或接入它们。

本项目已初始化本地 Git，功能、测试和文档一起提交；不跟踪构建产物、机器日志或密钥，不自动推送。应用本身不记录消息内容或数量历史。

应用图标可在普通 macOS 终端用 `swift scripts/generate_icon.swift` 重新生成。`docs/menu-bar-overlay-preview.png` 为同一绘制代码生成的无未读、3、999+ 放大对比。
