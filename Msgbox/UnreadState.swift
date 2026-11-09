import Foundation

enum UnreadState: Equatable, Sendable {
    case clear, unread(Int?), notInstalled, notRunning, permissionRequired, unknown(String)

    var hasUnread: Bool { if case .unread = self { return true }; return false }
    var label: String {
        switch self {
        case .clear: return String(localized: "0 unread (no badge)")
        case .unread(let count):
            return count.map { count in String(localized: "\(count) unread") } ?? String(localized: "Unread activity")
        case .notInstalled: return String(localized: "Not installed")
        case .notRunning: return String(localized: "Not running")
        case .permissionRequired: return String(localized: "Accessibility permission required")
        case .unknown(let reason): return String(localized: "Unknown: \(reason)")
        }
    }

    static func badge(_ value: String?) -> Self {
        guard let value else { return .unknown(String(localized: "Dock did not expose a badge attribute")) }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return .clear }
        if ["•", "●", "!"].contains(text) { return .unread(nil) }
        let lowerBound = text.hasSuffix("+")
        let digits = lowerBound ? String(text.dropLast()) : text
        guard !digits.isEmpty, digits.utf8.allSatisfy({ (48...57).contains($0) }),
              let count = Int(digits) else { return .unknown(String(localized: "Unrecognized badge format")) }
        if lowerBound { return count > 0 ? .unread(nil) : .unknown(String(localized: "Unrecognized badge format")) }
        return count == 0 ? .clear : .unread(count)
    }

    static func resolve(installed: Bool, running: Bool, trusted: Bool, badge: Self) -> Self {
        if !installed { return .notInstalled }
        if !running { return .notRunning }
        if !trusted { return .permissionRequired }
        return badge
    }
}

struct TargetSnapshot: Sendable {
    let id: String
    let url: URL?
    let running: Bool
}

enum MonitoringPolicy {
    static func totalLabel(_ states: [UnreadState], compact: Bool = false) -> String {
        var total = 0
        var incomplete = false
        for state in states {
            switch state {
            case .unread(let count):
                if let count {
                    let sum = total.addingReportingOverflow(count)
                    total = sum.overflow ? Int.max : sum.partialValue
                    incomplete = incomplete || sum.overflow
                } else { incomplete = true }
            case .unknown, .permissionRequired: incomplete = true
            case .clear, .notInstalled, .notRunning: break
            }
        }
        if compact && total >= 1000 { return "999+" }
        if compact && total == 0 && !incomplete { return "" }
        return incomplete ? (total > 0 ? "\(total)+" : "?") : String(total)
    }

    static func interval(trusted: Bool, running: Bool, lowPower: Bool = false) -> TimeInterval {
        trusted && running ? (lowPower ? 6 : 3) : 15
    }
    static func ordered(_ states: [UnreadState]) -> [Int] {
        states.indices.sorted {
            states[$0].hasUnread == states[$1].hasUnread ? $0 < $1 : states[$0].hasUnread
        }
    }
}
