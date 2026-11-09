<p align="center">
  <img src="docs/app-icon.png" width="96" height="96" alt="Msgbox 图标，两个重叠的聊天气泡">
</p>

<h1 align="center">Msgbox</h1>

<p align="center"><strong>在 Mac 菜单栏一眼看清，哪个聊天软件有未读。</strong></p>

<p align="center">macOS 26+ · 离线运行 · <a href="README.md">English</a></p>

工作用微信，群聊用 QQ，其他对话散在 Telegram 和 Discord。每次想确认有没有新消息，都要把几个应用点开一遍。Msgbox 把它们的 Dock 角标汇总到菜单栏。扫一眼看合计，点气泡看各个应用，再点对应那一行就能打开聊天软件。

<p align="center">
  <img src="docs/menu-bar-overlay-preview.png" width="384" height="104" alt="放大的菜单栏图标，分别显示无未读、3 条未读和 999+">
</p>

<p align="center"><em>菜单栏图标放大示意，分别为 0、3 和至少 1,000 条未读。</em></p>

[快速开始](#快速开始) · [支持的应用](#支持的应用) · [隐私](#隐私) · [常见问题](#常见问题) · [参与贡献](#参与贡献)

## 快速开始

**需要 macOS 26 或更新版本，以及 Xcode 26 或更新版本。** 当前预览版通过源码构建使用，界面为简体中文。

1. 克隆本仓库，或在 GitHub 页面选择 **Code → Download ZIP**，下载后解压。
2. 用 Xcode 打开 `Msgbox.xcodeproj`，选择 **Msgbox → My Mac**，按 **⌘R**。Debug 版使用本地临时签名，无需 Apple Developer 签名证书。
3. 在 Msgbox 中点击 **前往辅助功能设置…**，在 **系统设置 → 隐私与安全性 → 辅助功能** 中开启当前运行的副本。从 Xcode 启动时，该副本叫 **Msgbox Debug**。返回 Msgbox 后会自动检测。若系统尚未使授权生效，退出并重新打开该副本。
4. 打开一款受支持的聊天软件，点击菜单栏气泡查看角标。进入 **设置… → 软件筛选**，勾选想统计的应用。选择会保存在本机。

关闭列表窗口后，仍可从菜单栏使用。要安装到“应用程序”文件夹或设置登录时启动，请看[本机安装](#本机安装)。

## 支持的应用

| 应用 | macOS Bundle ID | 统计规则 |
| --- | --- | --- |
| 微信 | `com.tencent.xinWeChat` | 读取 Dock 数字角标 |
| QQ | `com.tencent.qq` | 读取 Dock 数字角标 |
| Telegram | `com.tdesktop.Telegram` | 读取 Dock 数字角标 |
| Discord | `com.hnc.Discord` | 只统计 Dock 中的精确数字，忽略活动圆点、`!` 和 `99+` 等缩写角标 |

兼容性取决于安装的客户端版本以及它是否向 Dock 提供角标。合计只覆盖已勾选且正在运行的应用，并受各应用的角标设置和通知规则影响。

| 显示 | 含义 |
| --- | --- |
| `22` | 已读取的数字相加为 22，例如 `12 + 3 + 7`。 |
| `12+` | 已知合计为 12，至少还有一个应用显示了无法换算的未读标记，或其状态暂时读不到。 |
| `?` | 合计不完整，且没有已知的正数。展开列表可查看原因。 |
| 只有气泡 | 检测到的合计为 0。 |
| `999+` | 已知合计至少为 1,000。展开列表可查看完整的已知数量。 |

## 隐私

Msgbox 离线运行，无需账号，也没有遥测。它通过 macOS 辅助功能读取所选应用的 Dock 图标元数据，范围限于 Dock，不读取聊天正文、窗口、通知或聊天数据库。应用筛选保存在 macOS 本机偏好设置中，未读数量不保存历史。

辅助功能是 macOS 提供的一项范围较广的权限，Msgbox 用它查询 Dock。读取代码见 [DockReader.swift](Msgbox/DockReader.swift)。应用无需录屏、全盘访问或通知权限。Mac 睡眠或屏幕休眠时会暂停轮询。

## 常见问题

- **菜单栏没有图标。** 在 **系统设置 → 菜单栏** 中允许显示 Msgbox 或 Msgbox Debug。图标显示由菜单栏设置控制，角标读取由辅助功能授权控制。
- **合计显示 `?`，或某个应用状态未知。** 确认目标应用已运行、图标在 Dock 中，并检查辅助功能授权是否给了正在运行的 Msgbox 副本。Msgbox 读取的 Dock 属性 `AXStatusLabel` 没有公开文档，不同 macOS 或客户端版本可能有差异。
- **Telegram 其他位置有数字，Dock 上却没有。** 在 **系统设置 → 通知 → Telegram** 中开启通知和“应用图标角标”。Msgbox 读取底部 Dock 的图标。横幅和声音可按需关闭。
- **Discord 有活动提示，合计却没变。** 在 **Discord → User Settings → Notifications** 中开启未读角标。如果 macOS 通知设置也有 Discord，允许应用图标角标。只有 Dock 提供精确数字时才会计入。
- **如何卸载。** 如果开启了“登录时启动”，先在 Msgbox 设置里关闭。退出 Msgbox，在辅助功能设置中移除对应条目，再删除运行过的应用副本。

## 本机安装

如果希望装到 `/Applications` 日常使用，请先退出 Msgbox。需要 Python 3，且钥匙串中有有效的 **Apple Development** 签名身份。在仓库根目录运行：

```sh
python3 scripts/install.py
open /Applications/Msgbox.app
```

安装脚本会构建 Release、检查新版本是否符合已安装版本的签名要求，并将旧版备份到 `build/installed-backups/`。若存在多个签名身份，用 `MSGBOX_SIGNING_IDENTITY` 指定所选证书的 40 位指纹。如果是首次从旧的临时签名版本迁移，运行 `python3 scripts/install.py --migrate-signature`，系统可能要求重新授予一次辅助功能权限。

该脚本生成供自己 Mac 使用的 Apple Development 签名版本。对外分发需要单独的 Developer ID 签名和公证流程。从“应用程序”打开后，可以在 **设置… → 通用** 中启用“登录时启动”。

## 参与贡献

来自不同 Mac 的兼容性反馈很有价值。发现角标和显示不一致时，欢迎在 GitHub 提交 Issue，附上 macOS 版本、聊天客户端版本和 Bundle ID、Dock 上的角标、Msgbox 的显示结果以及复现步骤。提供角标读数即可，请隐去聊天内容和账号信息。

目前优先验证 Discord 私信和提及产生的数字角标、读完后角标是否清除，以及不同 macOS 和客户端版本的兼容性。Discord 只统计精确数字的规则已有单元测试，真实消息到达与读后清除仍需要实机验证。

Msgbox 使用 Swift 6、SwiftUI 和 AppKit，无第三方依赖。想支持更多应用，可以从 [Monitor.swift](Msgbox/Monitor.swift) 的 Bundle ID 列表入手，先在真实客户端上核对 Dock 角标。[测试套件](MsgboxTests/UnreadStateTests.swift)覆盖角标解析、缺少权限、合计不完整和监控行为。

在仓库根目录构建或运行检查：

```sh
xcodebuild -project Msgbox.xcodeproj -scheme Msgbox -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build build
xcodebuild -project Msgbox.xcodeproj -scheme Msgbox -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build test
python3 scripts/audit.py
```

Debug 应用位于 `build/Build/Products/Debug/Msgbox.app`。[人工验收清单](docs/HUMAN_ACCEPTANCE.md)涵盖需要真实 macOS 界面和聊天客户端的检查。已有签名 Release 构建时，`python3 scripts/test_install.py` 可验证签名检查而无需安装，`python3 scripts/idle_measure.py` 可测量它启动的 Msgbox 进程。测量前先退出其他 Msgbox 实例。

## 许可证

本仓库尚未添加开源许可证。
