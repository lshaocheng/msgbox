import AppKit
@preconcurrency import ApplicationServices
import Combine
import ServiceManagement

struct ChatApp: Identifiable {
    let id: String
    let name: String
    var url: URL?
    var state: UnreadState = .unknown(String(localized: "Waiting for a check"))
    var icon: NSImage?
    var stateLabel: String {
        id == "com.hnc.Discord" && state == .clear ? String(localized: "0 unread (no numeric badge)") : state.label
    }

    @MainActor static let supported = [ChatApp(id: "com.tencent.xinWeChat", name: String(localized: "WeChat")),
                                      ChatApp(id: "com.tencent.qq", name: "QQ"),
                                      ChatApp(id: "com.tdesktop.Telegram", name: "Telegram"),
                                      ChatApp(id: "com.hnc.Discord", name: "Discord")]
}

@MainActor
final class Monitor: ObservableObject {
    @Published var apps: [ChatApp]
    @Published private(set) var loginStatus = SMAppService.mainApp.status
    @Published var trusted = false
    @Published var notice: String?
    @Published var refreshing = false
    @Published var lastUpdated: Date?
    @Published var suspended = false
    private let reader = DockReader()
    private let defaults: UserDefaults
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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let disabled = Set(defaults.stringArray(forKey: "disabledAppIDs") ?? [])
        apps = ChatApp.supported.filter { !disabled.contains($0.id) }
        timer.schedule(deadline: .distantFuture)
        timer.resume()
    }

    func isEnabled(_ app: ChatApp) -> Bool { apps.contains { $0.id == app.id } }

    func setEnabled(_ enabled: Bool, for app: ChatApp) {
        guard ChatApp.supported.contains(where: { $0.id == app.id }), isEnabled(app) != enabled else { return }
        var disabled = Set(defaults.stringArray(forKey: "disabledAppIDs") ?? [])
        if enabled { disabled.remove(app.id) } else { disabled.insert(app.id) }
        defaults.set(disabled.sorted(), forKey: "disabledAppIDs")
        generation += 1
        apps = ChatApp.supported.filter { !disabled.contains($0.id) }.map { target in
            apps.first(where: { $0.id == target.id }) ?? target
        }
        discoveryDate = .distantPast
        refresh()
    }

    func start() {
        guard !started else { return }
        started = true
        timer.setEventHandler { [weak self] in self?.refresh() }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
                Task { @MainActor in
                    guard let self, self.apps.contains(where: { $0.id == bundleID }) else { return }
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
        let wasTrusted = trusted
        trusted = AXIsProcessTrusted()
        if trusted && !wasTrusted { notice = nil }
        if Date().timeIntervalSince(discoveryDate) > 60 {
            var discovered = apps
            for i in discovered.indices {
                let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: discovered[i].id)
                if discovered[i].url != url {
                    discovered[i].url = url
                    discovered[i].icon = url.map { NSWorkspace.shared.icon(forFile: $0.path) }
                }
            }
            if discovered.map(\.url) != apps.map(\.url) { apps = discovered }
            discoveryDate = Date()
        }
        let runningIDs = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let snapshots = apps.map { TargetSnapshot(id: $0.id, url: $0.url,
            running: runningIDs.contains($0.id)) }
        let interval = MonitoringPolicy.interval(trusted: trusted, running: snapshots.contains(where: \.running),
                                                 lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled)
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
            if apps.map(\.state) != results {
                var updated = apps
                for i in updated.indices { updated[i].state = results[i] }
                apps = updated
            }
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
            notice = String(localized: "\(app.name) is missing or macOS could not locate it.")
            discoveryDate = .distantPast
            refresh()
            return
        }
        // LaunchServices also sends the reopen request that activate() alone does not.
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] _, error in
            Task { @MainActor in
                self?.notice = error == nil ? String(localized: "Asked macOS to open \(app.name). The app controls which window appears.") : String(localized: "Could not open \(app.name). Check the app in Finder.")
                self?.discoveryDate = .distantPast
                self?.refresh()
            }
        }
    }

    func openAccessibilitySettings() {
        // Register this build with macOS only after the user clicks the permission button.
        trusted = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")!
        if NSWorkspace.shared.open(url) {
            notice = String(localized: "Enable Msgbox in Privacy & Security → Accessibility, then return here.")
        } else {
            notice = String(localized: "Could not open System Settings. Open Privacy & Security → Accessibility and enable Msgbox.")
        }
    }

    func refreshLoginStatus() { loginStatus = SMAppService.mainApp.status }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard !enabled || Bundle.main.bundleURL.path.hasPrefix("/Applications/") else {
            notice = String(localized: "Open Msgbox from Applications before enabling Launch at Login.")
            return
        }
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            notice = nil
        } catch { notice = String(localized: "Could not change Launch at Login: \(error.localizedDescription)") }
        refreshLoginStatus()
    }

    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
}
