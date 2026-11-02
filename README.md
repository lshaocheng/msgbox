# Msgbox

完全离线的 macOS 26+ 菜单栏聊天角标聚合器。Swift 6、SwiftUI、AppKit，无依赖。

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

当前可直接打开 `~/Applications/Msgbox.app`（与已验证 Release 构建相同）。Xcode 构建路径与它是不同副本，调试前先退出已运行的 Msgbox，避免重复实例。Hidden Bar 已恢复运行；图标为两个重叠对话气泡。

## 状态含义

- 菜单栏数字是**微信、QQ、Telegram 已读取的未读角标数字之和**；展开列表分别显示各应用数量，并显示合计。例如 12、3、7 合计为 22。
- 只汇总 Dock 提供的角标，不代表聊天内的全部未读；关闭角标或静音设置可影响结果。
- 数字为已读取的角标值；`99+` 或固定圆点显示“有未读”。
- 部分应用有未读但无精确数值，或读取失败/无权限时，合计显示已知数加 `+`（如 `12+`）；没有已知正数时显示 `?`，不伪装成 0。未安装/未运行的应用不计入合计。
- 成功读取空字符串、`0` 或系统明确返回 `AXError.noValue`（角标没有值）时显示“0 条未读（无角标）”；不支持角标属性、未知格式、读取错误一律显示“未知”。
- “未安装”“未运行”“需要辅助功能权限”分别显示。无权限时仍可主动打开聊天应用。
- 单击列表项调用系统打开/激活接口；最小化/特殊窗口由聊天应用控制，界面不会把接受请求声称为窗口已恢复。

真实兼容性尚待人工验收，尤其 Dock 的非公开 `AXStatusLabel` 属性，参见 [技术验证](docs/FEASIBILITY.md)、[人工验收](docs/HUMAN_ACCEPTANCE.md)、[最终报告](docs/FINAL_REPORT.md)。不含联网、消息内容、自动更新、自动启动或后台服务。

## Telegram 顶部有数字但未计入

Telegram 顶部菜单栏的数字与底部 Dock 角标是两个显示入口。Msgbox 读取底部 Dock；顶部有数字不能证明 Dock 已提供角标。本机排查发现 macOS 系统设置 → 通知 → Telegram 的“允许通知”关闭，导致“应用图标角标”也被禁用。经用户授权，已开启通知总开关并仅保留应用角标，关闭桌面、通知中心、锁屏显示和声音。2026-11-02 15:48:52 正式版实际读到 Telegram=8、微信=1、QQ=0、合计=9，已验证 Telegram 正数角标计入合计。顶部菜单栏数字自身不作为读取来源。

本地临时签名在构建变化后可能需要重新添加固定路径的 Msgbox 辅助功能授权并重启应用；不要用给开发工具额外授权替代。
