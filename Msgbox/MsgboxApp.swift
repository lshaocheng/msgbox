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
        window.title = String(localized: "Unread Chats · Msgbox")
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: PopoverView(monitor: monitor, onOpenSettings: { [weak self] in self?.showSettings() }))
        window.center()
        return window
    }()
    lazy var settingsWindow: NSWindow = {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 520),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = String(localized: "Settings · Msgbox")
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
            self?.item.button?.setAccessibilityLabel(String(localized: "Unread chats, total \(total)"))
            self?.item.button?.toolTip = String(localized: "Unread badge total: \(total). + means incomplete and ? means unknown. Open for details.")
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

    func applicationDidBecomeActive(_ notification: Notification) {
        guard NSClassFromString("XCTestCase") == nil else { return }
        monitor.refresh()
        monitor.refreshLoginStatus()
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
                Text("Unread Chats").font(.headline)
                Text("Total \(monitor.totalLabel)").monospacedDigit()
                Spacer()
                Button { monitor.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(monitor.refreshing || monitor.suspended)
                    .help("Refresh unread status").accessibilityLabel("Refresh unread status")
            }
            if !monitor.trusted && !monitor.apps.isEmpty {
                AccessibilityPermissionView(monitor: monitor)
                Divider()
            }
            if monitor.apps.isEmpty {
                Text("Choose apps to monitor in Settings.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(monitor.sortedApps) { app in
                Button { monitor.open(app) } label: {
                    HStack(spacing: 12) {
                        if let icon = app.icon { Image(nsImage: icon).resizable().frame(width: 32, height: 32) }
                        else { Image(systemName: "app.dashed").frame(width: 32, height: 32) }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(app.name).font(.body.weight(.medium))
                            Text(app.stateLabel).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if app.state.hasUnread { Image(systemName: "circle.fill").font(.caption2).foregroundStyle(.orange) }
                        Image(systemName: "arrow.up.forward").foregroundStyle(.secondary)
                    }.padding(8).contentShape(Rectangle())
                }.buttonStyle(.plain).help("Open or switch to \(app.name)")
                    .accessibilityLabel("\(app.name), \(app.stateLabel), open app")
            }
            Divider()
            Text("Counts come from Dock badges. + means incomplete and ? means unknown. Dots and badges like 99+ give no exact count.")
                .font(.caption).foregroundStyle(.secondary)
            if let notice = monitor.notice { Text(notice).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
            HStack {
                Text(monitor.suspended ? String(localized: "Monitoring paused") : monitor.lastUpdated.map { String(localized: "Updated at \($0.formatted(date: .omitted, time: .standard))") } ?? String(localized: "Waiting for a check"))
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button("Settings…", action: onOpenSettings).keyboardShortcut(",")
                Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }
        }.padding(18).frame(width: 350).fixedSize(horizontal: false, vertical: true)
    }
}

struct AccessibilityPermissionView: View {
    @ObservedObject var monitor: Monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(monitor.trusted ? String(localized: "Accessibility granted") : String(localized: "Accessibility permission required"),
                  systemImage: monitor.trusted ? "checkmark.shield" : "exclamationmark.shield")
                .font(.headline)
            Text("Msgbox uses Accessibility to read Dock badges. Chat content stays private.")
                .font(.caption).foregroundStyle(.secondary)
            if !monitor.trusted {
                Text("Enable Msgbox in System Settings, then return here.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("If access still appears off, quit and reopen Msgbox.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button("Open Accessibility Settings…") { monitor.openAccessibilitySettings() }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var monitor: Monitor

    var body: some View {
        Form {
            Section("Permissions") {
                AccessibilityPermissionView(monitor: monitor)
            }
            Section("Apps to Monitor") {
                ForEach(ChatApp.supported) { app in
                    Toggle(app.name, isOn: Binding(
                        get: { monitor.isEnabled(app) },
                        set: { monitor.setEnabled($0, for: app) })).toggleStyle(.checkbox)
                }
                Text("Only selected apps appear in the list and count toward the total. Choices are saved on this Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("General") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { monitor.loginStatus == .enabled || monitor.loginStatus == .requiresApproval },
                    set: { monitor.setLaunchAtLogin($0) }))
                if monitor.loginStatus == .requiresApproval {
                    Text("Launch at login is awaiting approval.").font(.caption).foregroundStyle(.secondary)
                    Button("Open Login Items Settings…") { monitor.openLoginSettings() }
                }
                if let notice = monitor.notice {
                    Text(notice).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            Section("About Msgbox") {
                Text("Msgbox \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                    .font(.headline)
                Text("See WeChat, QQ, Telegram, and Discord Dock badges in the menu bar. Click an app to open it.")
                Text("Msgbox works offline. It reads Dock badge metadata through Accessibility and keeps no count history.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
            .formStyle(.grouped).frame(width: 400, height: 520)
            .onAppear { monitor.refresh(); monitor.refreshLoginStatus() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                monitor.refresh()
                monitor.refreshLoginStatus()
            }
    }
}
