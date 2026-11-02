import Foundation

enum UnreadState: Equatable, Sendable {
    case clear, unread(Int?), notInstalled, notRunning, permissionRequired, unknown(String)

    var hasUnread: Bool { if case .unread = self { return true }; return false }
    var label: String {
        switch self {
        case .clear: return "0 条未读（无角标）"
        case .unread(let count): return count.map { "\($0) 条未读" } ?? "有未读"
        case .notInstalled: return "未安装"
        case .notRunning: return "未运行"
        case .permissionRequired: return "需要辅助功能权限"
        case .unknown(let reason): return "未知：\(reason)"
        }
    }

    static func badge(_ value: String?) -> Self {
        guard let value else { return .unknown("Dock 未提供角标属性") }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return .clear }
        if ["•", "●", "!"].contains(text) { return .unread(nil) }
        let lowerBound = text.hasSuffix("+")
        let digits = lowerBound ? String(text.dropLast()) : text
        guard !digits.isEmpty, digits.utf8.allSatisfy({ (48...57).contains($0) }),
              let count = Int(digits) else { return .unknown("无法识别角标格式") }
        if lowerBound { return count > 0 ? .unread(nil) : .unknown("无法识别角标格式") }
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
    static func totalLabel(_ states: [UnreadState]) -> String {
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
        return incomplete ? (total > 0 ? "\(total)+" : "?") : String(total)
    }

    static func interval(trusted: Bool, running: Bool) -> TimeInterval { trusted && running ? 3 : 15 }
    static func ordered(_ states: [UnreadState]) -> [Int] {
        states.indices.sorted {
            states[$0].hasUnread == states[$1].hasUnread ? $0 < $1 : states[$0].hasUnread
        }
    }
}
