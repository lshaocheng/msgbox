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
    lazy var listWindow: NSWindow = {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 350, height: 460),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "聊天未读 · Msgbox"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: PopoverView(monitor: monitor))
        window.center()
        return window
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "MsgboxUnreadApps"
        item.isVisible = true
        item.button?.image = NSImage(systemSymbolName: "bubble.left.and.bubble.right", accessibilityDescription: "聊天未读聚合器")
        item.button?.target = self
        item.button?.action = #selector(toggle)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PopoverView(monitor: monitor))
        monitor.$apps.sink { [weak self] apps in
            let total = MonitoringPolicy.totalLabel(apps.map(\.state))
            self?.item.button?.title = " \(total)"
            self?.item.button?.image = NSImage(systemSymbolName: apps.contains { $0.state.hasUnread } ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right", accessibilityDescription: "未读角标总数：\(total)")
            self?.item.button?.toolTip = "未读角标总数：\(total)；+ 表示数量不完整，? 表示数量未知；展开查看各应用"
        }.store(in: &subscriptions)
        monitor.start()
        showAppList()
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

    func applicationWillTerminate(_ notification: Notification) { monitor.stop() }

    @objc private func toggle() {
        listWindow.close()
        if popover.isShown { popover.performClose(nil); return }
        guard let button = item.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate()
        monitor.refresh()
    }
}

struct PopoverView: View {
    @ObservedObject var monitor: Monitor
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
                Button("退出") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }
        }.padding(18).frame(width: 350).fixedSize(horizontal: false, vertical: true)
    }
}
