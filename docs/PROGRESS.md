# 进度

## 最新：应用安装、叠加数字与省电检查（2026-11-02）

- 菜单栏固定 38 pt，使用原生按钮和固定 32×22 pt 模板图片。数字直接叠在右上角，无底色、边框或胶囊；0 不绘制数字，1000 起显示 999+。展开列表保留完整可读数量和合计。
- 应用图标沿用双气泡 SF Symbol，标准 ICNS 已嵌入；正式安装 /Applications/Msgbox.app，旧用户目录副本存入忽略的 build/previous-user-Msgbox.app。
- 原生 ServiceManagement 登录时启动开关已实际开/关验证，用户当前选择开启；未登出/重启电脑验证。测试宿主不创建菜单栏项，多副本启动实测回到同一正式进程，重复图标问题已处理。
- 应用目录集中在 ChatApp.supported；新增应用共用 Reader、列表、合计、排序和激活。增加第四应用的回归通过，尚未实际接入 Slack/Discord。
- 图标按路径缓存、每轮一次进程枚举、未读状态变化才发布；菜单栏图片只在显示数字变化时生成。普通 3 秒、低电量 6 秒、无权限/目标 15 秒，睡眠/熄屏暂停。
- 排除过自定义子视图方案：授权后测得约 50.38% 单核 CPU，调用栈反复生成菜单栏快照。改回原生图片后 183.30 秒平均 0.6765%，RSS 102.4–107.3 MiB，19 次 sockets 均为 0。数据 logs/authorized-idle-metrics.json；不是实际电池功耗或整夜测量。最终无底色数字版复测 62.04 秒平均单核 CPU 0.6447%，RSS 113.3–113.6 MiB，7 次 sockets 均为 0。
- 最终 XCTest 16/16 通过；Release build/analyze、源码/签名审查通过。真实读取再次确认微信=1、Telegram=7、QQ=0、合计=8。最终包哈希与 Release 一致。
- 已初始化 Git 并提交基线 408e0ad，当前功能与文档另行提交；不包含构建产物、机器日志或消息历史。用户已确认柠檬清理处理好，停止修改；Hidden Bar 已恢复原设置。

## 最新：Telegram 真实正数读取通过（2026-11-02）

- 用户澄清可见数字位于顶部菜单栏；Dock 角标属性实际 noValue。定位 macOS Telegram 通知总开关 off，角标禁用。
- 经明确授权配置为仅角标，关闭桌面/通知中心/锁屏显示和声音；不打开聊天窗口、不读消息。
- 移除全部临时诊断，恢复此前 13/13 测试对应的正式版；Release build/analyze、安全检查通过，二进制哈希一致。
- 恢复同一 Msgbox 既有辅助功能授权并重启后，15:48:52 真实读取 Telegram=8、微信=1、QQ=0、合计=9，截图一致；Telegram 正数计入合计通过。已读清零、物理菜单栏总数和长期稳定性未验收。

## 最新：改为未读角标总数（2026-11-02）

- 按用户要求，菜单栏数字改为微信、QQ、Telegram 数字角标之和，展开列表显示各应用数量与合计；清除态显示 0 条未读（无角标）。
- 数字不完整时显示已知数加 +；没有已知正数时显示 ?。读取失败和无权限不当作零；合计处理整数溢出，不引入依赖。
- 最终 Xcode RunAllTests 13/13 通过，见 logs/tests-dock-no-badge-xcode.txt；Release build/analyze 成功，安全检查通过，见 build-dock-no-badge-release.log、security-audit-dock-no-badge.txt。命令行首次测试因沙箱无法连接 testmanagerd 失败，已由 Xcode 实际执行通过。
- 已更新 ~/Applications/Msgbox.app 并核对与 Release 可执行文件 SHA-256 一致。CUA 实际看到新版“聊天未读 合计 ?”及微信、QQ、Telegram 三行。
- 用户重新添加固定路径的构建后，实际读取 QQ=1，与用户反馈一致；微信/Telegram 无角标却被错误归为不可读取。修正 AXError.noValue 为 clear，保留不支持属性/超时/拒绝等错误为未知，并增加边界回归。
- 最终更新后经用户授权仅恢复 Msgbox 辅助功能条目，重启应用后 15:18:51 实际读到微信=0、QQ=1、Telegram=0、列表合计=1，与用户确认状态一致。15:20:55 又实际读到微信自动从 0 更新到 2、QQ=1、Telegram=0、合计=3，验证了微信正数角标到达和数值求和。Telegram 正数到达、三应用清除变化及物理菜单栏数字仍待验证。见 logs/unread-live-validation.txt。

## 阶段 1：环境与可行性

- 当前目录为空，无现有 Git 仓库或代码需要合并。
- 完成系统/工具链检查、本机三应用 Bundle ID 与运行状态只读验证。
- 当前未获辅助功能授权；Dock 拒绝访问。真实角标验证已转人工验收。
- 选定原生 SwiftUI + AppKit、只读 Dock AX、串行后台检测与低频轮询。详见 FEASIBILITY.md。

## 阶段 2：MVP

- 建立共享 Scheme 的原生 Xcode 工程，无第三方依赖。
- 实现单菜单栏图标、原生列表、未读应用数、排序、未知与权限降级、主动打开应用。
- 实现后台有界 Dock 查询、缓存、超时、睡眠/屏幕关闭暂停、启停事件更新。
- 首次 Debug 构建通过；修复并发捕获警告后切换 Swift 6 严格并发验证中。
- 已建立状态解析/失败处理/排序/生命周期/性能 XCTest；构建与自动测试进行中。

## 阶段 3：自动验证

- Debug / Release 编译与 Release 静态分析通过，Swift 6 严格并发源码无警告。
- XCTest 9/9 通过，0 失败；包括角标解析、异常格式、权限/安装/运行优先级、未读到达/清除/退出/重启状态、排序、轮询策略、模拟睡眠/唤醒、无权限 reader 和解析性能。
- 源码离线/隐私检查通过：无网络 API/HTTP URL、消息/窗口内容读取、AX 写操作、自动授权调用及额外 usage description/entitlement。
- Release 真实进程三分钟空闲资源与 sockets 采样正在执行。真实 Dock 授权后的路径与物理睡眠转人工验收。

## 阶段 4：收尾与交付

- 最终 XCTest **11/11 通过，0 失败**；新增 20 次 SwiftUI 布局构造与缺失应用打开错误验证。证据 logs/tests-final.log、logs/Tests-final.xcresult。
- Release 实际运行 183.52 秒：平均单核 CPU 0.1007%，启动 10 秒后 RSS 约 72.1–74.2 MiB，19 次网络 socket 检查均为 0；不代表授权后或长期功耗达标。
- 在临时拒绝网络操作的进程 sandbox 中额外空闲运行 20 秒通过；未修改系统网络设置。
- 签名审查发现并去除 Release 默认 get-task-allow；最终重新 build/analyze 成功，签名严格验证通过，Hardened Runtime 且无 entitlement；二进制仅依赖系统库，无直接网络符号。
- CUA 原生图形检查工具超时，未取得真实界面状态。实际点击、真实三应用角标/窗口、授权后性能、物理睡眠及长期稳定性移交人工验收。
- 已完成 README、HUMAN_ACCEPTANCE、FEASIBILITY、FINAL_REPORT 和全部构建/测试/测量日志。源码未再变化；签名配置收紧后复核 Release，未无意义重复全部测试。
- 无 Git 初始化/提交/推送/部署，无系统权限修改，无新安装软件。测试与测量进程结束，图形检查遗留的本项目实例已关闭。
- 无人值守工作完成，剩余全部是已列明的人工验收或 UI 工具外部阻塞，停止执行。

## 后续修复：启动后没有可见结果（2026-11-02）

- 用户确认 Hidden Bar 展开后仍找不到图标；SF Symbol 本身可生成，CUA 读取实际菜单栏仍超时，未将遮挡猜测当作根因。
- 确认当前没有其他可见入口，改为启动及重新打开应用时显示复用现有列表的原生窗口；关闭后继续菜单栏运行，点击菜单栏仍展开原 Popover。
- 新增窗口生命周期回归，12/12 XCTest 通过，0 失败；Xcode 当前工程重新构建成功，无错误。Release 与安全检查见后续日志。
- 更新 README、人工验收与最终报告；初版性能记录保留为历史基线，本次未重复性能测量。尚未人工确认当前屏幕的图标位置与点击结果。


## 后续排查：macOS 26 菜单栏图标仍不可见（2026-11-02）

- 用户截图确认启动列表窗口可见；菜单栏图标未见，系统菜单栏列表相应字母区间没有 Msgbox。
- 原生 Xcode 只读探针捕捉本应用 NSStatusBarWindow=(0,-22,38,22)，screen=nil；图像是有效模板，排除符号不存在或浅深色非模板问题。
- 只读偏好导出确认 `NSStatusItem VisibleCC Item-0=false`；未修改该状态。仍未确认 Control Center 对 Msgbox 的条目归属，不能仅凭 frame 判断根因。
- 一次原生 MenuBarExtra 替代实验构建成功但未获得有效屏幕位置，后续执行工具报错，已撤回。保持 AppKit 和可用列表窗口，最终 Xcode 构建成功、0 错误。
- 截图 Codex Computer Use 的菜单栏开关关闭；已把“由用户开启该显示开关再重启验证归属”的单项步骤写入人工验收。不要求其他系统权限或全局重置，不篡改系统策略。
- 见 logs/menu-bar-macos26.txt。本阶段问题尚未解决；剩余关键证据需要用户控制菜单栏显示开关。没有将构建成功误报为图标修复。


## 后续排查：XPC 警告与系统 blocked 状态（2026-11-02）

- 项目没有 NSXPC/NSSecureCoding 解码调用；控制台警告的精确调用来源未定位，未擅自屏蔽警告或关闭安全编码。
- 菜单栏项补上公开固定 autosaveName 和 isVisible=true 请求；未修改系统开关/偏好/受保护台账。2 秒后的独立布局诊断仍无有效屏幕，不能声称修复。
- 读取仅关联 Msgbox 的 Control Center 日志，明确记录请求显示 true，但 starting to track blocked host；独立 Release 启动也复现，排除了“仅 Xcode 测试进程”的解释。
- CUA 独立 Release 启动成功并读到真实列表窗口；菜单栏 UI 宿主读取仍超时。正常列表可用，菜单栏图标尚未修复。
- 移除诊断中重复创建同名 status item 的测试夹具，最终回归 12/12、0 失败（tests-status-final.log）。早先原始 app blocked 发生在重复夹具之前，保留原始日志与说明，不误用重复 scene 的清理信息作为根因。
- 编译/静态审查和安全检查已执行；系统阻止的具体归属仍未确认。前次 Codex Computer Use 开关建议没有解除用户问题，不再要求重复切换。

## 用户授权修改菜单栏显示开关（2026-11-02）

- 用户明确授权后，通过系统设置 UI 将“菜单栏 → 允许在菜单栏中 → Codex Computer Use”从 off 改为 on，操作后及最终再次读取均确认 on。
- 未修改辅助功能、录屏、全盘访问或其他应用开关。
- 仅退出并重新打开本项目 Release Msgbox，列表窗口正常显示。Control Center 最新日志仍包含 blocked host，随后收到具名菜单栏项的 clientRequestsVisibility=true 更新；未取得图标实际恢复的证据。日志 logs/controlcenter-after-codex-menu-enabled.log。
- 此次才是明确观察到开关 off→on 的实测；此前“用户报告仍无效”不能替代对开关实际值的核对。结果不支持将该开关视为已验证修复。系统列表仍没有 Msgbox 独立条目。

## XPC 解码警告的调试器排查（2026-11-02）

- Xcode 实际调试器中确认当前 Msgbox 未因该警告退出；暂时暂停后读取系统符号与调用栈。
- 捕获到 NSThemeWidgetZoomMenuServiceViewController（系统窗口缩放菜单）的异步 Foundation/XPC 解码调用，未出现 Msgbox 业务栈；这是解码入口断点，不能作为用户那条警告的精确触发证据。
- 已找到更窄的 Foundation 警告发出方法，但本次有限观察未捕获该断点；启动重现没有执行成功，不夸大定位结果。日志 logs/xpc-decoder-stack.txt。
- 一次可选调试表达式的自动审批超时，未视作已执行；全部本次临时断点已删除，已核实 Xcode 恢复 Running Msgbox。
- 未改产品源代码、解码白名单、日志开关或任何系统权限；没有源码变化，不重复构建/测试。

## 菜单栏修复完成：定位 ChatGPT 宿主显示开关（2026-11-02）

- 用户要求继续到实际看到图标并可点击。关闭 Hidden Bar、Finder 启动和标准用户 Applications 目录启动同一二进制仍 blocked；保留日志 menubar-finder-no-hiddenbar.log。
- 只读进程链及 Info.plist 确认 Codex 实际宿主为 /Applications/ChatGPT.app，Bundle ID com.openai.codex；系统 ChatGPT 菜单栏开关 off，与已 on 的 Codex Computer Use 不是同一条目。
- 用户明确授权开启 ChatGPT 显示开关。14:46:29 系统立即 Unblocking host，设置新增 Msgbox on；证据 logs/menubar-chatgpt-enabled.log。
- 用户明确反馈“已看到图标，点击能打开列表”，本项人工验收通过。工具读取 Control Center 超时，未声称自动点击通过。
- 为图形验收正常退出并自动重载一次 Control Center，保留设置；全局重置对话框已取消，未执行重置。恢复 Hidden Bar，关闭其偏好窗口，保留原自动隐藏设置。
- 未改产品源代码/签名/Bundle ID/安全权限，未重跑无变化的测试。已更新 README、HUMAN_ACCEPTANCE、FINAL_REPORT。当前运行 ~/Applications/Msgbox.app（原样复制的 Release）；真实角标兼容性仍未验收。
