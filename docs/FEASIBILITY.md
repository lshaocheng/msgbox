# 技术验证（2026-11-02）

环境：macOS 26.4.1 (25E253)、Xcode 26.6 (17F113)、Swift 6.3.3、Apple Silicon。

从实际安装包读取的标识与版本：

| 应用 | 本机路径 | Bundle ID | 版本 | 宿主环境进程 |
|---|---|---|---|---|
| 微信 | /Applications/WeChat.app | com.tencent.xinWeChat | 4.1.13 | 正在运行 |
| QQ | /Applications/QQ.app | com.tencent.qq | 7.0.1 | 正在运行 |
| Telegram | /Applications/Telegram.app | com.tdesktop.Telegram | 7.3.3 | 正在运行 |

沙箱内进程枚举曾返回空列表；在获准的只读宿主探针中确认三个应用均运行，Dock PID=638。AXIsProcessTrusted=false；Dock AXChildren 查询返回 -25211 (apiDisabled)。没有调用授权提示、修改 TCC 或读取聊天内容。原始结果见 logs/feasibility.txt 和 logs/feasibility-host.txt。

## 方案与边界

- NSWorkspace 定位安装包；NSRunningApplication 识别运行状态。用户点击后才 unhide / activate(.activateAllWindows) 或 NSWorkspace.openApplication（禁止新建重复实例）。系统接受请求不等于窗口恢复成功，界面明确提示最小化/特殊窗口限制。无 AX 写操作、无键盘模拟。
- 只查询 Dock 的一层 AXList / AXApplicationDockItem，以公开 AXURL 属性匹配实际安装路径，不按标题猜测，不遍历聊天窗口，不读通知。缓存匹配到的三个 Dock 元素；Dock PID 变化清空缓存，错误失效重查。
- AXStatusLabel 不在当前公开 SDK 常量中，属于不稳定属性。未获权限，无法确认此机 Dock 是否暴露该属性或三应用的实际角标格式。空字符串或数字 0 才视为无角标；缺失/错误/不支持/未知文本都为未知。数字读数、99+ 和固定圆点格式有单元测试，但不是兼容性证据。
- Dock 无角标也不能证明聊天内没有未读（应用可关闭角标、静音会话可能不计入）；本工具仅汇总 Dock 角标。
- 不订阅 AXObserver：当前无法验证 Dock 的角标通知支持与可靠性，避免实现未经验证的监听。采用单个 DispatchSourceTimer：有运行目标且有权限 3 秒，无目标或无权限 15 秒，500ms leeway；睡眠/屏幕关闭停止。NSWorkspace 启停事件触发更新。安装定位缓存 60 秒。
- AX 调用在独立 actor 执行，不阻塞主线程；消息超时 0.2 秒，发现最多 16 个根/256 个条目且 1 秒发现预算；预算在调用间检查，单次在途调用不能中断。最多一个刷新在途，状态代际丢弃睡眠/启停期间旧结果。
- 不启用 App Sandbox：跨进程 Dock AX 需要用户授予 Accessibility，不增加其他权限；Hardened Runtime 开启，无额外 entitlement。不通过禁用系统安全保护运行。
- 无外部依赖，未参考/复制 Doll 实现，无需引入其许可证。只依据公开系统头文件/API 自行编写。

## 参考官方资料

- [AXUIElementCopyAttributeValue](https://developer.apple.com/documentation/applicationservices/1462085-axuielementcopyattributevalue)
- [AXUIElementSetMessagingTimeout](https://developer.apple.com/documentation/applicationservices/1459345-axuielementsetmessagingtimeout)
- [NSRunningApplication](https://developer.apple.com/documentation/appkit/nsrunningapplication)
- [NSWorkspace.openApplication](https://developer.apple.com/documentation/appkit/nsworkspace/openapplication(at:configuration:completionhandler:))

真实角标、授权流程、聊天窗口激活和物理睡眠均需用户验收；不能标记兼容性通过。
