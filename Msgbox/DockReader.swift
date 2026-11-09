import AppKit
import ApplicationServices

// Actor isolation keeps synchronous Accessibility messaging off the UI thread.
actor DockReader {
    private var dockPID: pid_t = 0
    private var cachedItems: [String: AXUIElement] = [:]

    func read(_ targets: [TargetSnapshot], trusted: Bool) -> [UnreadState] {
        guard trusted, targets.contains(where: { $0.running && $0.url != nil }) else {
            cachedItems.removeAll()
            return targets.map { UnreadState.resolve(installed: $0.url != nil, running: $0.running,
                                                      trusted: trusted, badge: .unknown(String(localized: "Not checked"))) }
        }
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            cachedItems.removeAll()
            return targets.map { UnreadState.resolve(installed: $0.url != nil, running: $0.running,
                                                      trusted: trusted, badge: .unknown(String(localized: "Dock unavailable"))) }
        }
        if dockPID != dock.processIdentifier {
            cachedItems.removeAll()
            dockPID = dock.processIdentifier
        }
        cachedItems = cachedItems.filter { entry in targets.contains { $0.id == entry.key && $0.running } }
        let deadline = Date().addingTimeInterval(1)
        let application = AXUIElementCreateApplication(dockPID)
        AXUIElementSetMessagingTimeout(application, 0.2)
        // Only the Dock's direct list children are examined; never chat windows or notifications.
        var scanBudget = 256
        if targets.contains(where: { $0.running && cachedItems[$0.id] == nil }),
           let roots = attribute(application, kAXChildrenAttribute as String).value as? [AXUIElement] {
            for root in roots.prefix(16) {
                guard Date() < deadline else { break }
                guard attribute(root, kAXRoleAttribute as String).value as? String == kAXListRole as String,
                      let items = attribute(root, kAXChildrenAttribute as String).value as? [AXUIElement] else { continue }
                for item in items.prefix(scanBudget) {
                    guard Date() < deadline else { break }
                    scanBudget -= 1
                    guard attribute(item, kAXSubroleAttribute as String).value as? String == kAXApplicationDockItemSubrole as String,
                          let url = attribute(item, kAXURLAttribute as String).value as? URL,
                          let target = targets.first(where: { $0.url?.standardizedFileURL == url.standardizedFileURL }) else { continue }
                    cachedItems[target.id] = item
                }
                if scanBudget == 0 { break }
            }
        }
        return targets.map { target in
            var state: UnreadState = .unknown(String(localized: "App icon missing from the Dock"))
            if target.running, let item = cachedItems[target.id] {
                // shortcut: AXStatusLabel is undocumented; fail closed until each OS/app version is accepted.
                let result = attribute(item, "AXStatusLabel")
                state = Self.badgeState(value: result.value as? String, error: result.error, appID: target.id)
                if result.error != .success && result.error != .noValue {
                    cachedItems.removeValue(forKey: target.id)
                }
            }
            return UnreadState.resolve(installed: target.url != nil, running: target.running, trusted: trusted, badge: state)
        }
    }

    nonisolated static func badgeState(value: String?, error: AXError, appID: String? = nil) -> UnreadState {
        switch error {
        case .success:
            let state = UnreadState.badge(value)
            // Discord channel activity dots are not numeric notification counts.
            if appID == "com.hnc.Discord", state == .unread(nil) { return .clear }
            return state
        // Dock reports noValue when the supported status label has no badge.
        case .noValue: return .clear
        case .apiDisabled: return .unknown(String(localized: "Accessibility access denied"))
        case .attributeUnsupported: return .unknown(String(localized: "Dock does not support reading badges"))
        default: return .unknown(String(localized: "Could not read Dock badge"))
        }
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> (error: AXError, value: CFTypeRef?) {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return (error, value)
    }
}
