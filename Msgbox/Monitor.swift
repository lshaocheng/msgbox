import AppKit
import ApplicationServices
import Combine

struct ChatApp: Identifiable {
    let id: String
    let name: String
    var url: URL?
    var state: UnreadState = .unknown("等待检测")
    var icon: NSImage? { url.map { NSWorkspace.shared.icon(forFile: $0.path) } }
}

@MainActor
final class Monitor: ObservableObject {
    @Published var apps = [ChatApp(id: "com.tencent.xinWeChat", name: "微信"),
                           ChatApp(id: "com.tencent.qq", name: "QQ"),
                           ChatApp(id: "com.tdesktop.Telegram", name: "Telegram")]
    @Published var trusted = false
    @Published var notice: String?
    @Published var refreshing = false
    @Published var lastUpdated: Date?
    @Published var suspended = false
    private let reader = DockReader()
    private let timer = DispatchSource.makeTimerSource(queue: .main)
    private var observers: [NSObjectProtocol] = []
    private var discoveryDate = Date.distantPast
    private var sleeping = false
    private var screenOff = false
    private var generation = 0
    private var started = false
    private var activeInterval: TimeInterval?

    var totalLabel: String { MonitoringPolicy.totalLabel(apps.map(\.state)) }
    var sortedApps: [ChatApp] { MonitoringPolicy.ordered(apps.map(\.state)).map { apps[$0] } }

    init() {
        timer.schedule(deadline: .distantFuture)
        timer.resume()
    }

    func start() {
        guard !started else { return }
        started = true
        timer.setEventHandler { [weak self] in self?.refresh() }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.discoveryDate = .distantPast
                    self.generation += 1
                    self.refresh()
                }
            })
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification,
                     NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let name = note.name
                Task { @MainActor in self?.powerChanged(name) }
            })
        }
        refresh()
    }

    func powerChanged(_ name: Notification.Name) {
        switch name {
        case NSWorkspace.willSleepNotification: sleeping = true
        case NSWorkspace.didWakeNotification: sleeping = false
        case NSWorkspace.screensDidSleepNotification: screenOff = true
        case NSWorkspace.screensDidWakeNotification: screenOff = false
        default: return
        }
        generation += 1
        suspended = sleeping || screenOff
        if suspended {
            timer.schedule(deadline: .distantFuture)
            activeInterval = nil
        } else { refresh() }
    }

    func refresh() {
        guard !suspended, !refreshing else { return }
        refreshing = true
        trusted = AXIsProcessTrusted()
        if Date().timeIntervalSince(discoveryDate) > 60 {
            for i in apps.indices { apps[i].url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: apps[i].id) }
            discoveryDate = Date()
        }
        let snapshots = apps.map { TargetSnapshot(id: $0.id, url: $0.url,
            running: !NSRunningApplication.runningApplications(withBundleIdentifier: $0.id).isEmpty) }
        let interval = MonitoringPolicy.interval(trusted: trusted, running: snapshots.contains(where: \.running))
        if interval != activeInterval {
            timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(500))
            activeInterval = interval
        }
        let currentGeneration = generation
        let currentTrust = trusted
        Task {
            let results = await reader.read(snapshots, trusted: currentTrust)
            refreshing = false
            guard !suspended else { return }
            guard currentGeneration == generation else { refresh(); return }
            for i in apps.indices { apps[i].state = results[i] }
            lastUpdated = Date()
        }
    }

    func stop() {
        timer.cancel()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers.removeAll()
        generation += 1
        suspended = true
    }

    func open(_ app: ChatApp) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.id) else {
            notice = "\(app.name) 未安装或系统无法定位它。"
            discoveryDate = .distantPast
            refresh()
            return
        }
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.id).first {
            running.unhide()
            let accepted = running.activate(options: [.activateAllWindows])
            notice = accepted ? "已请求切换到\(app.name)。最小化或特殊窗口可能需要手动恢复。" : "系统未接受激活请求，请从 Dock 手动打开\(app.name)。"
        } else {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.createsNewApplicationInstance = false
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] _, error in
                Task { @MainActor in
                    self?.notice = error == nil ? "已请求打开\(app.name)。窗口显示由聊天应用决定。" : "无法打开\(app.name)，请从 Finder 检查应用。"
                    self?.discoveryDate = .distantPast
                    self?.refresh()
                }
            }
        }
    }

    func openAccessibilitySettings() {
        // Opening this local system pane never requests or grants trust automatically.
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
