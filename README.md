# Msgbox

完全离线的 macOS 26+ 菜单栏聊天角标聚合器。Swift 6、SwiftUI、AppKit，无依赖。

## 安装与使用

正式安装：`/Applications/Msgbox.app`，在 Finder 的“应用程序”中打开。应用图标与菜单栏使用同一个双气泡图形。旧用户目录副本保存在项目 `build/previous-user-Msgbox.app`，不再作为日常入口。

本机版使用钥匙串中固定的 Apple Development 身份签名。更新请使用 `python3 scripts/install.py`：先构建、验证签名与已安装版本的身份一致，再备份和替换；缺少证书、临时签名或身份不匹配时停止，保留原安装。请先退出 Msgbox。首次从旧临时签名迁移使用 `python3 scripts/install.py --migrate-signature`，这一次可能需要重新授权，后续更新不再按每次构建的二进制哈希识别。备份位于忽略的 `build/installed-backups/`。多个 Apple Development 身份时，以环境变量 `MSGBOX_SIGNING_IDENTITY` 指定证书的 40 位指纹；不要更换开发团队、应用标识或日常安装路径。

这是仅供本机使用的开发签名版本；对外分发需要另行使用 Developer ID 并公证。证书与私钥保留在钥匙串，不放进项目或安装包。证书到期需要正常续签，同一团队更新仍须通过旧版签名要求校验。

菜单栏仅在有未读时把数字叠在图标右上角，没有数字底色、边框或胶囊。总数为 0 时只显示图标；达到 1000 时显示 `999+`。菜单项固定 38 pt，内部图标位置固定，不因数字位数改变挤动其他图标。展开列表保留系统提供的完整数量和合计。

点击菜单栏图标，在列表底部点“设置…”（⌘,）打开设置窗口。“软件筛选”可分别勾选微信、QQ、Telegram、Discord，默认全部勾选；取消后立即停止参与角标读取、合计和列表显示。选择自动保存在本机，重启后保留，也可全部取消；空列表会提示前往设置选择软件。“关于 Msgbox”显示版本、软件简介和隐私说明。

读取角标只需要**辅助功能**权限。缺少权限时，列表顶部显示用途和“前往辅助功能设置…”按钮，设置窗口也始终显示授权状态和入口。点击后由 macOS 登记当前应用、显示系统授权提示，并跳到“隐私与安全性 → 辅助功能”；是否开启由你决定。返回 Msgbox 会自动重新检测，无须手动刷新；若 macOS 尚未使首次授权生效，界面会提示退出重开一次。不需要给 Msgbox 开启录屏、全盘访问或通知权限。登录时启动是可选功能，系统要求批准时使用它自己的登录项设置入口。

设置内“登录时启动”使用 macOS 原生登录项，可随时开启或关闭；首次安装不自动开启。系统要求批准时会显示明确提示与设置入口，失败会显示原因；登录启动静默驻留菜单栏，手动打开显示列表。测试进程不创建菜单栏项，普通多副本启动会回到已运行实例。

## 构建与运行

1. 用 Xcode 26 打开 `Msgbox.xcodeproj`，选择 **Msgbox → My Mac**。
2. 按 ⌘R。启动时直接显示“聊天未读 · Msgbox”列表窗口，同时显示菜单栏气泡图标，不显示 Dock 图标；关闭窗口后继续从菜单栏使用。重新打开应用会再次显示同一列表窗口。
3. 默认不弹系统权限框；未授权时界面主动提示用途。点击“前往辅助功能设置…”后，在系统设置中开启当前 Msgbox，返回自动检测。
4. 按 ⌘U 执行 XCTest。Debug 名称为 `Msgbox Debug`，使用独立的 `local.msgbox.app.debug` 标识与临时签名，不覆盖日常正式版的授权。Release 必须使用固定 Apple Development 身份；本机安装脚本自动选取唯一可用证书和对应团队。

命令行（在项目目录）：

```sh
xcodebuild -project Msgbox.xcodeproj -scheme Msgbox -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build build
xcodebuild -project Msgbox.xcodeproj -scheme Msgbox -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build -resultBundlePath logs/Tests-new.xcresult test
python3 scripts/install.py
open /Applications/Msgbox.app
python3 scripts/test_install.py
python3 scripts/audit.py
python3 scripts/idle_measure.py
```

测量脚本需要在普通 macOS 用户终端运行，启动且最终结束它自己创建的 Release 实例；请先退出其他 Msgbox 实例。它只检查该进程，不读取其他聊天应用内容，不修改权限。结果位于 `logs/`。

## macOS 26 菜单栏图标缺失

先检查系统设置 → 菜单栏 → 允许在菜单栏中 → Msgbox。菜单栏显示与读取角标的辅助功能权限是两件事。

本机 2026-11-02 已定位并解决一次宿主关联问题：Msgbox 被系统关联到显示名称为 **ChatGPT**、Bundle ID 为 `com.openai.codex` 的开发工具。经用户授权开启 **ChatGPT** 的菜单栏显示后，Control Center 立即记录 `Unblocking host`，独立的 Msgbox 开关也出现并开启；用户已确认图标可见、点击能打开列表。此前只开启 Codex Computer Use 无效。此结论针对本机实测，不代表所有机器都需要开启 ChatGPT。

当前可直接打开 `/Applications/Msgbox.app`（与已验证 Release 构建相同）。Xcode 构建路径与它是不同副本，调试前先退出已运行的 Msgbox，避免重复实例。Hidden Bar 已恢复运行；图标为两个重叠对话气泡。

## 状态含义

- 菜单栏数字是**设置中已勾选应用的未读角标数字之和**（支持微信、QQ、Telegram、Discord）；展开列表分别显示所选应用数量，并显示合计。例如 12、3、7 合计为 22。
- 只汇总 Dock 提供的角标，不代表聊天内的全部未读；关闭角标或静音设置可影响结果。
- 数字为已读取的角标值；`99+` 或固定圆点显示“有未读”。
- 部分应用有未读但无精确数值，或读取失败/无权限时，合计显示已知数加 `+`（如 `12+`）；没有已知正数时显示 `?`，不伪装成 0。未安装/未运行的应用不计入合计。
- 成功读取空字符串、`0` 或系统明确返回 `AXError.noValue`（角标没有值）时显示“0 条未读（无角标）”；不支持角标属性、未知格式、读取错误一律显示“未知”。
- “未安装”“未运行”“需要辅助功能权限”分别显示。无权限时仍可主动打开聊天应用。
- 单击列表项统一调用系统打开应用接口，并复用已有进程。窗口已关闭但应用仍运行时也会收到重新打开请求；微信、QQ、Telegram 的这一场景已由用户确认恢复。特殊窗口的最终响应仍由聊天应用决定。

真实兼容性尚待人工验收，尤其 Dock 的非公开 `AXStatusLabel` 属性，参见 [技术验证](docs/FEASIBILITY.md)、[人工验收](docs/HUMAN_ACCEPTANCE.md)、[最终报告](docs/FINAL_REPORT.md)。不含联网、消息内容、自动更新或额外后台服务；登录时启动由用户自行选择。

## Telegram 顶部有数字但未计入

Telegram 顶部菜单栏的数字与底部 Dock 角标是两个显示入口。Msgbox 读取底部 Dock；顶部有数字不能证明 Dock 已提供角标。本机排查发现 macOS 系统设置 → 通知 → Telegram 的“允许通知”关闭，导致“应用图标角标”也被禁用。经用户授权，已开启通知总开关并仅保留应用角标，关闭桌面、通知中心、锁屏显示和声音。2026-11-02 15:48:52 正式版实际读到 Telegram=8、微信=1、QQ=0、合计=9，已验证 Telegram 正数角标计入合计。顶部菜单栏数字自身不作为读取来源。

旧临时签名在构建变化后可能需要重新授权。新的本机安装流程已禁止这种签名覆盖固定签名版本；不要用给开发工具额外授权替代 Msgbox 授权。若用户撤销权限或系统策略改变，仍需由用户重新开启。

## 省电与扩展

普通授权轮询 3 秒，低电量模式 6 秒，无权限/无目标 15 秒；睡眠和熄屏暂停。只响应受支持聊天应用的启停事件。应用图标按路径缓存，运行进程每轮只枚举一次，列表状态不变时不重复发布；菜单栏图片只在显示数字变化时更新，使用原生按钮和普通模板图片，避免 macOS 26 自定义菜单栏视图反复生成快照。

增加 Slack 等应用：在 `Msgbox/Monitor.swift` 的 `ChatApp.supported` 中添加一项实际 Bundle ID 和显示名称即可，共用 Dock 匹配、权限处理、合计、排序和打开逻辑；不需要新建适配器。可从目标安装包的 `Contents/Info.plist` 读取 Bundle ID。应额外验收该应用是否向 Dock 暴露数字角标；圆点或被应用缩写的数量无法恢复为精确消息数。Discord 已按此方式接入。

本项目已初始化本地 Git，功能、测试和文档一起提交；不跟踪构建产物、机器日志或密钥，不自动推送。应用本身不记录消息内容或数量历史。

应用图标可在普通 macOS 终端用 `swift scripts/generate_icon.swift` 重新生成。`docs/menu-bar-overlay-preview.png` 为同一绘制代码生成的无未读、3、999+ 放大对比。

## Discord 接入

支持正式版 Discord（`com.hnc.Discord`），默认勾选，复用 Dock 读取、合计、排序和打开逻辑；旧有软件筛选保持不变。可在设置中取消勾选。

Discord → User Settings → Notifications → Badges → Enable Unread Message Badge 应开启；若 macOS“系统设置 → 通知”中有 Discord，也需允许应用图标角标。数字按 Dock 实际提供的值计入合计，圆点显示“有未读”，不换算为消息数量。Discord 的普通频道未读与私信/提及角标可能不同，不能把角标当作所有频道消息总数。

2026-11-04 本机正式版已验证 Discord“有未读”角标、列表排序及打开调用；两处角标开关均已开启。数字角标和实际新消息到达/读后清除仍待人工验收。
