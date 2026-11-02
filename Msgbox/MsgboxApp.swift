import AppKit
import SwiftUI
import Combine

@main
struct MsgboxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let monitor = Monitor()
    private var item: NSStatusItem!
    private let popover = NSPopover()
    private var subscriptions = Set<AnyCancellable>()
    private var displayedCount: String?
    lazy var listWindow: NSWindow = {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 350, height: 460),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "聊天未读 · Msgbox"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: PopoverView(monitor: monitor, onOpenSettings: { [weak self] in self?.showSettings() }))
        window.center()
        return window
    }()
    lazy var settingsWindow: NSWindow = {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 520),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "设置 · Msgbox"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: SettingsView(monitor: monitor))
        window.center()
        return window
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // XCTest hosts must not leave another menu-bar item or monitor behind.
        guard NSClassFromString("XCTestCase") == nil else { return }
        if let id = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .filter({ $0.processIdentifier != ProcessInfo.processInfo.processIdentifier })
            .min(by: { ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }) {
            if let url = existing.bundleURL { NSWorkspace.shared.open(url) }
            else { existing.activate() }
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: 38)
        item.autosaveName = "MsgboxUnreadApps"
        item.isVisible = true
        item.button?.imagePosition = .imageOnly
        item.button?.imageScaling = .scaleNone
        item.button?.target = self
        item.button?.action = #selector(toggle)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PopoverView(monitor: monitor, onOpenSettings: { [weak self] in self?.showSettings() }))
        monitor.$apps.sink { [weak self] apps in
            let total = MonitoringPolicy.totalLabel(apps.map(\.state))
            let compact = MonitoringPolicy.totalLabel(apps.map(\.state), compact: true)
            if self?.displayedCount != compact {
                self?.item.button?.image = StatusIcon.image(count: compact)
                self?.displayedCount = compact
            }
            self?.item.button?.setAccessibilityLabel("聊天未读，合计 \(total)")
            self?.item.button?.toolTip = "未读角标总数：\(total)；+ 表示数量不完整，? 表示数量未知；展开查看各应用"
        }.store(in: &subscriptions)
        monitor.start()
        let loginLaunch = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !loginLaunch { showAppList() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showAppList()
        return true
    }

    private func showAppList() {
        popover.performClose(nil)
        listWindow.makeKeyAndOrderFront(nil)
        NSApp.activate()
        monitor.refresh()
    }

    func showSettings() {
        popover.performClose(nil)
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        if let item { NSStatusBar.system.removeStatusItem(item) }
    }

    @objc private func toggle() {
        listWindow.close()
        if popover.isShown { popover.performClose(nil); return }
        guard let button = item.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate()
        monitor.refresh()
    }
}

@MainActor
enum StatusIcon {
    static let size = NSSize(width: 32, height: 22)
    static let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold)

    static func image(count: String) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSImage(systemSymbolName: "bubble.left.and.bubble.right", accessibilityDescription: nil)?
            .draw(in: NSRect(x: 4, y: 2, width: 24, height: 18))
        if !count.isEmpty {
            let textSize = (count as NSString).size(withAttributes: [.font: font])
            let textRect = NSRect(x: size.width - textSize.width, y: size.height - textSize.height,
                                  width: textSize.width, height: textSize.height)
            // Clear only the covered strokes; the count has no background or border.
            textRect.fill(using: .clear)
            (count as NSString).draw(at: textRect.origin,
                                    withAttributes: [.font: font, .foregroundColor: NSColor.black])
        }
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

struct PopoverView: View {
    @ObservedObject var monitor: Monitor
    let onOpenSettings: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("聊天未读").font(.headline)
                Text("合计 \(monitor.totalLabel)").monospacedDigit()
                Spacer()
                Button { monitor.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(monitor.refreshing || monitor.suspended)
                    .help("刷新未读状态").accessibilityLabel("刷新未读状态")
            }
            if monitor.apps.isEmpty {
                Text("尚未选择软件，请在设置中勾选要统计的应用。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(monitor.sortedApps) { app in
                Button { monitor.open(app) } label: {
                    HStack(spacing: 12) {
                        if let icon = app.icon { Image(nsImage: icon).resizable().frame(width: 32, height: 32) }
                        else { Image(systemName: "app.dashed").frame(width: 32, height: 32) }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(app.name).font(.body.weight(.medium))
                            Text(app.state.label).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if app.state.hasUnread { Image(systemName: "circle.fill").font(.caption2).foregroundStyle(.orange) }
                        Image(systemName: "arrow.up.forward").foregroundStyle(.secondary)
                    }.padding(8).contentShape(Rectangle())
                }.buttonStyle(.plain).help("打开或切换到\(app.name)")
                    .accessibilityLabel("\(app.name)，\(app.state.label)，打开应用")
            }
            Divider()
            if !monitor.trusted {
                Text("仅为读取 Dock 角标需要辅助功能权限。不会读取聊天窗口、消息或通知正文。默认不请求权限。")
                    .font(.caption).foregroundStyle(.secondary)
                Button("打开辅助功能设置…") { monitor.openAccessibilitySettings() }
            }
            Text("数量来自各应用的 Dock 角标；+ 表示合计不完整，? 表示未知。圆点或 99+ 无法提供精确数量；无角标属性时无法确认未读状态。")
                .font(.caption).foregroundStyle(.secondary)
            if let notice = monitor.notice { Text(notice).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
            HStack {
                Text(monitor.suspended ? "已暂停监控" : monitor.lastUpdated.map { "更新于 \($0.formatted(date: .omitted, time: .standard))" } ?? "等待检测")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button("设置…", action: onOpenSettings).keyboardShortcut(",")
                Button("退出") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }
        }.padding(18).frame(width: 350).fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsView: View {
    @ObservedObject var monitor: Monitor

    var body: some View {
        Form {
            Section("软件筛选") {
                ForEach(ChatApp.supported) { app in
                    Toggle(app.name, isOn: Binding(
                        get: { monitor.isEnabled(app) },
                        set: { monitor.setEnabled($0, for: app) })).toggleStyle(.checkbox)
                }
                Text("只读取、统计和显示勾选的软件。选择自动保存在本机，可随时更改。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("通用") {
                Toggle("登录时启动", isOn: Binding(
                    get: { monitor.loginStatus == .enabled || monitor.loginStatus == .requiresApproval },
                    set: { monitor.setLaunchAtLogin($0) }))
                if monitor.loginStatus == .requiresApproval {
                    Text("自启动等待系统批准").font(.caption).foregroundStyle(.secondary)
                    Button("打开登录项设置…") { monitor.openLoginSettings() }
                }
                if let notice = monitor.notice {
                    Text(notice).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            Section("关于 Msgbox") {
                Text("Msgbox \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                    .font(.headline)
                Text("将微信、QQ 和 Telegram 的 Dock 未读角标汇总到菜单栏，点击列表即可打开对应软件。")
                Text("完全离线，仅读取 Dock 角标元数据，不读取聊天内容，也不保存未读数量历史。角标检测需要辅助功能权限。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
            .formStyle(.grouped).frame(width: 400, height: 520)
            .onAppear { monitor.refreshLoginStatus() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                monitor.refreshLoginStatus()
            }
    }
}
