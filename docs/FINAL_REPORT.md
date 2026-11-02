# 最终报告

日期：2026-11-02，Asia/Shanghai。项目：`the repository root`。

## Telegram 漏计定位与恢复（2026-11-02 15:48）

用户已确认微信、QQ 正常；Telegram 可见数字实际在顶部菜单栏。仅查询 Telegram Dock 图标的临时诊断发现 AXStatusLabel 支持但返回 noValue。系统设置中 Telegram 通知总开关 off，角标开关因此禁用。经用户明确授权，改为通知 on、角标 on、桌面/通知中心/锁屏显示关闭、声音 off；没有修改聊天内设置或读取消息。

恢复无诊断代码的正式版并重新登记既有 Msgbox 辅助功能授权、重启后，CUA 于 15:48:52 实际读到 **Telegram=8、微信=1、QQ=0、合计=9**，15:49:04 截图一致。Telegram 正数角标读取和计入合计通过；三款应用都已有正数读取证据，微信/QQ 已观察到归零变化。Telegram 已读清零、物理菜单栏总数、长期稳定性仍未验证。

临时诊断已完全移除，正式版 SHA-256 与前次 13/13 测试二进制完全一致（08f9f82d0c1a9ffdcf1ed686736e7c77e87fc39faefcc70e0effd9a06e613354）；本次 Release build/analyze 和安全检查通过，没有对相同源码重复运行 XCTest。证据 logs/unread-live-validation.txt、logs/telegram-dock-probe-values.txt、logs/build-telegram-final.log、logs/security-audit-telegram-final.txt。

## 未读角标总数开发记录（2026-11-02）

菜单栏与展开列表合计改为三应用数字角标之和，各行显示对应应用的数量。12、3、7 → 22；有未知数量或读取失败时显示已知数加 +，没有已知正数时显示 ?。不将失败当作零，不读取聊天正文。下文“未读应用数”是历史版本行为，已由此变更替代。

最终 Xcode XCTest 13/13 通过（logs/tests-dock-no-badge-xcode.txt），Release build/analyze 与源码/二进制审查通过（logs/build-dock-no-badge-release.log、logs/security-audit-dock-no-badge.txt）。已更新 ~/Applications/Msgbox.app。用户重新授权后实际读到 QQ=1；修复将 AXError.noValue（角标无值）误归为读取错误的问题。最终经用户授权仅恢复 Msgbox 条目并重启，15:18:51 CUA 读取到微信=0、QQ=1、Telegram=0、列表合计=1，与用户确认的 Dock 状态相同。证据 logs/unread-live-validation.txt。15:20:55 微信已自动从 0 更新到 2，QQ=1、Telegram=0、合计=3，验证真实数字求和。Telegram 正数到达、三应用清除变化和物理菜单栏数字仍待验证；没有把当前状态匹配声称为完整兼容性通过。本次未进行真实消息发送或清除、睡眠或性能复测。

**无人值守可完成的开发与验证已完成；剩余为辅助功能授权、真实消息/窗口、物理睡眠与长期人工验收。没有声称真实微信、QQ、Telegram 检测已通过。**

## 最新结果：菜单栏图标与点击入口已恢复（2026-11-02）

**用户确认：已看到图标，点击能打开列表。** 本次未改产品源代码；修复的是本机系统菜单栏显示开关的宿主关联。

- 关闭 Hidden Bar、从 Finder 启动同一 Release、复制到用户 Applications 目录后启动，均仍有 `Starting to track blocked host`；不是仅由 Xcode 或 Hidden Bar 遮挡导致。
- 只读进程与应用元数据确认：当前 Codex 宿主实际是 `/Applications/ChatGPT.app`，Bundle ID `com.openai.codex`；系统显示名称为 ChatGPT，菜单栏开关此前 off。Codex Computer Use 是另一个条目。
- 用户明确授权开启 ChatGPT 的菜单栏显示。14:46:29 操作后，Control Center 立即记录 Msgbox 的 `Unblocking host`，系统设置新增 Msgbox 独立条目且为 on。证据 `logs/menubar-chatgpt-enabled.log`；用户随后完成可见与点击验收。
- 电脑操作工具仍无法读取 Control Center 的完整 UI（超时）；正常退出并自动重载一次 Control Center 后仍存在该工具限制。没有以日志代替物理点击，点击结果来自用户本人确认。
- Hidden Bar 已恢复运行，原设置未改；全局“Reset Control Center”只查看说明后取消。没有修改受保护台账、轮换 Bundle ID、增加数据访问权限或处理 XPC 警告。
- 同一已验证 Release 原样复制至 `~/Applications/Msgbox.app`，当前运行该副本。不要与 Xcode 的另一个副本同时启动。代码未变化，无需重复编译和 XCTest；最近有效回归仍为 12/12 通过。

系统列表归属异常的创建过程未逆向确认；本机开关与解除阻止的因果关系由单项操作前后日志证实。真实未读检测和三应用完整兼容性仍未通过验收。

## 后续修复：启动可见入口（2026-11-02）

用户反馈进程已运行，但展开 Hidden Bar 后仍看不到图标。已验证 SF Symbol 可以生成（天然尺寸 23×17），但 CUA 再次超时，尚不能判断实际菜单栏不可见的原因，不能断言是 Hidden Bar 或刘海遮挡。

修复的是已确认的可发现性缺口：启动及 applicationShouldHandleReopen 直接展示复用现有 PopoverView/Monitor 的原生列表窗口；关闭后仍保持菜单栏运行，点击菜单栏收起列表窗口并展开原 Popover，不增加权限或后台功能。图标示意 docs/menu-bar-icon.png。

最新 **12/12 XCTest 通过，0 失败**，包括窗口复用、可关闭、与 Popover 共用 Monitor、重新打开后可见；见 logs/tests-startup-window.log 与 logs/Tests-startup-window.xcresult。Xcode 当前工程 BuildProject 构建成功，0 错误。Release build/analyze 和安全审查另见 logs/build-startup-window-release.log、logs/security-audit-startup-window.txt。

下文 11 项测试及空闲性能数字是初版证据，保留以供审查；本次未重新测量带启动窗口的 CPU/内存或替代人工菜单栏点击验收。需要在 Xcode 停止旧进程并重新运行，或打开更新后的 Release 包才能得到新行为。测量脚本现在会默认覆盖启动列表窗口可见的状态。

## 已验证

| 项目 | 结果与证据 |
|---|---|
| 原生工程 | `Msgbox.xcodeproj`，共享 Msgbox Scheme，Swift 6，macOS 26+，无第三方依赖；Debug 和 Release 构建成功 |
| 编译与审查 | Swift 严格并发无源码警告；Release analyze 成功；已人工审阅四个 Swift 源文件、工程、权限配置和测试边界 |
| 单元测试 | **11/11 通过，0 失败**，约 0.65 秒；`logs/tests-final.log`、`logs/Tests-final.xcresult` |
| 状态模型 | 数字/布尔角标、清除、未知、未安装、未运行、无权限、排序和未读应用数；失败不会映射成零 |
| 异常流程 | 无权限 reader 不查询 UI；缺失应用主动打开返回明确错误；睡眠/屏幕状态组合的模拟生命周期通过 |
| Popover 布局 | 20 次原生 NSHostingView 布局构造通过，宽度 350、合理高度；覆盖权限与未知状态；这是布局测试，不是物理点击验收 |
| 菜单栏配置 | 单个 NSStatusItem 创建点，LSUIElement=true 和 accessory policy；普通/有未读符号及应用数逻辑已实现。2026-11-02 用户已确认图标可见且点击能打开列表（人工验收） |
| 安装与运行状态 | 本机微信、QQ、Telegram 的安装包 Bundle ID/版本与正在运行进程已用宿主只读探针确认，见 FEASIBILITY.md |
| 运行启动 | 实际运行 Release 183.52 秒，无崩溃，采样结束由脚本 SIGTERM；日志为空，无应用错误输出 |
| 源码安全/离线 | `scripts/audit.py` 通过；未引入网络 API、HTTP URL、聊天窗口/消息属性、AX 写操作或自动授权请求 |
| 二进制依赖与签名 | 仅系统 framework/Swift runtime；Hardened Runtime；Release 去除 Xcode 默认注入的 get-task-allow 调试 entitlement，最终签名复核见 logs/binary-audit.txt |
| 网络运行采样 | 19 次每约 10 秒 `lsof -nP -a -p <MsgboxPID> -i` 检查，均无网络 socket；未关闭/修改用户网络设置 |
| 额外离线启动 | 临时进程 sandbox 拒绝所有直接网络操作后，Release 仍运行 20 秒；`logs/offline-smoke.txt`。sandbox-exec 仅为开发诊断，不随应用使用 |

测试包含：解析/异常格式、未读到达与清除、退出与重启、撤权优先级、排序计数、轮询频率、无权限读取、睡眠/屏幕唤醒、布局重复构造和缺失应用打开错误。具体用例见 MsgboxTests/UnreadStateTests.swift。

## 资源测量

方法：Release 原生 arm64 进程启动后空闲，界面未展开、无 Accessibility 授权、三目标运行；Python wait4 收集**仅此进程** CPU/rusage，ps 采 RSS，每约 10 秒采一次，共 19 次；一次 1 秒 sample 查看主线程。包括启动开销、样本采集的观察扰动，未减去预热。完整数据 `logs/idle-metrics.json`，调用栈 `logs/idle-sample.txt`。

| 指标 | 本次结果 |
|---|---|
| 总时长 | 183.52 秒 |
| CPU 用户 / 内核 | 0.1403 / 0.0446 秒 |
| 平均单核 CPU | 0.1007%（CPU 秒数 / 墙钟秒数 × 100） |
| 启动 10 秒后 RSS | 约 72.1–74.2 MiB，最后约 72.3 MiB；首个刚启动样本不作稳定 RSS 基线 |
| 最大 RSS（wait4） | 75.2 MiB |
| 10 秒时 sample physical footprint | 14.8 MiB，峰值 15.1 MiB；与 RSS 是不同指标 |
| 1 秒主线程样本 | 主要等待在 mach_msg / 系统事件循环 |
| 网络 socket | 19/19 个采样均为 0 |
| 解析微基准 | Debug 每轮 10,000 次解析，10 轮平均约 0.019 秒；存在预热波动，无性能回归基线 |

这只能说明**短时无权限路径的 CPU 低且未观察到持续 RSS 增长**。不代表授权后 Dock 查询、整夜运行或实际功耗通过。没有测量精确唤醒次数/能耗；context switches 不是唤醒次数。未以 root 运行 powermetrics。未做全时段抓包，socket 快照不能排除采样间瞬时连接；源码检查和网络拒绝启动提供互补证据。

性能二进制与最终二进制源码相同；最后一次只收紧 Release 签名注入配置，不改变运行逻辑。

## 三应用真实兼容性

| 应用 | 本机版本 / Bundle ID | 安装/进程识别 | Dock 角标 | 窗口激活 |
|---|---|---|---|---|
| 微信 | 4.1.13 / com.tencent.xinWeChat | 已验证 | 未验证 | 未验证 |
| QQ | 7.0.1 / com.tencent.qq | 已验证 | 未验证 | 未验证 |
| Telegram | 7.3.3 / com.tdesktop.Telegram | 已验证 | 未验证 | 未验证 |

宿主 Dock 进程可识别，但当前 AXIsProcessTrusted=false，AXChildren 返回 -25211（apiDisabled）。没有尝试绕过权限。AXStatusLabel 是未公开属性，当前 OS 和各应用的可用性待人工确认。读取失败、无图标、缺失属性或未知格式均显示未知；属性缺失不会当作零。

## 需要人工验证

- 一个菜单栏图标、无 Dock 图标、点击 Popover、反复开关、浅深色和 VoiceOver 体验。
- 用户手动对**实际 Msgbox.app**授予辅助功能权限；真实角标到达/清除/撤权/重启更新。
- 三应用真实打开/激活和最小化窗口恢复行为；系统接受激活请求不保证窗口一定恢复，界面会说明限制。
- 真实睡眠、屏幕关闭/唤醒后恢复。单元测试仅注入生命周期逻辑，不改变本机电源状态。
- 授权路径性能、一晚或更长稳定性、真实能耗和精确唤醒。
- 完整步骤及期待结果在 HUMAN_ACCEPTANCE.md，不需提供任何消息正文。

## 失败与外部阻塞

- 没有未修复的编译或 XCTest 失败。
- 图形自动检查工具 CUA 获取本机 Msgbox 时返回 `timeoutReached (-10005)`，没有取得 UI 状态，实际点击检查未执行；没有用其他全局控制工具绕过。
- 起初沙箱探针看不到真实应用进程，且 Swift 默认 module cache 写路径受限。已改用可写 module cache 并在获准的只读宿主探针确认真实进程；不会将沙箱空列表当作应用未运行。
- Xcode 测试首次 SDK stat cache 等待后自行完成，没有修改系统服务或缓存。曾尝试结束该已消失的子进程，返回 no such process，未影响测试。
- 构建日志含当前环境 CoreSimulator 服务不可用信息、系统 XCTest 已签名库不 strip 警告、未使用 AppIntents 的元数据提示；macOS 构建/测试成功，未修改与本工程无关的系统服务。

## 取舍与风险

- 使用系统 API 自行实现，没有复制 Doll 代码、添加依赖、后台服务或联网功能。
- 不启用 App Sandbox，以便使用跨进程 Dock Accessibility；开启 Hardened Runtime，Release 无调试 entitlement。授予的 Accessibility 是系统级能力，代码将其使用限制在只读 Dock 属性；不请求全盘/录屏/输入监控等权限。
- 事件可靠性未被验证，采用单个低频 timer；有权限且有目标运行 3 秒，否则 15 秒；睡眠/屏幕关闭停计时。AX 独立 actor、0.2 秒消息超时、有界发现、最多一个在途刷新。
- Dock 非公开属性、应用角标设置、不同发行渠道的 Bundle ID 或安装路径，都可能让状态变为未知。当前只收录本机实际验证的三个 Bundle ID。
- 数字是角标读数；静音、关闭角标或应用自身逻辑可能使其不同于全部聊天未读。没有权限/未知时菜单栏不显示未读数字，并不代表已确认零未读，需打开列表查看。
- 本地 ad-hoc 构建重签名/换路径可能使已有授权失效，需人工重新添加；没有发布签名/公证，不提供部署或分发声明。

## 恢复方式与交付

Xcode 打开 Msgbox.xcodeproj → Msgbox / My Mac → ⌘R；⌘U 跑测试。命令行与测量脚本见 README.md。可运行包在 `build-release/Build/Products/Release/Msgbox.app`。详细进度 PROGRESS.md。

回来后从 HUMAN_ACCEPTANCE.md 第 1–3 节继续。若授权后始终未知，记录 OS/应用版本及本工具状态，下一次开发先验证 Dock 属性兼容性，不追加权限、读取聊天窗口或私有数据库。

没有初始化 Git、提交、推送、部署、修改系统权限或安装软件。测试/测量创建的进程均已结束；没有添加自动启动项。到此停止无人值守工作，不空转。

## 用户授权后的开关实测（2026-11-02）

经本次明确授权，已通过系统设置 UI 将 Codex Computer Use 的菜单栏显示开关 off→on，并复核保持开启；没有改动其他权限/应用设置。重启本项目 Release 后列表可见，但 Control Center 仍出现 blocked host，之后收到 clientRequestsVisibility=true 更新；尚未验证图标恢复。系统“允许在菜单栏中”仍不含 Msgbox。证据 logs/controlcenter-after-codex-menu-enabled.log，不能把开关操作成功当作图标修复。

## XPC 警告调用栈排查补充（2026-11-02）

已通过 Xcode 调试器捕获系统窗口缩放菜单服务 NSThemeWidgetZoomMenuServiceViewController 的异步 Foundation/XPC 解码入口，详见 logs/xpc-decoder-stack.txt。该入口断点并非精确警告发出点；后续收窄到警告方法未取得命中，因此具体 warning 来源及其与菜单栏 blocked 的关系仍未确认。没有据此断言安全问题已修复或图标缺失原因已定位。产品源代码未改，全部临时断点已移除并恢复 Msgbox 运行。
