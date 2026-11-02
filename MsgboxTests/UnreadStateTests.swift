import XCTest
import AppKit
import SwiftUI
import ApplicationServices
@testable import Msgbox

final class UnreadStateTests: XCTestCase {
    func testDockNoBadgeIsDistinctFromReadFailure() {
        XCTAssertEqual(DockReader.badgeState(value: nil, error: .noValue), .clear)
        XCTAssertEqual(DockReader.badgeState(value: "1", error: .success), .unread(1))
        for error in [AXError.attributeUnsupported, .cannotComplete, .invalidUIElement, .apiDisabled] {
            guard case .unknown = DockReader.badgeState(value: "1", error: error) else {
                return XCTFail("Read failures must not reuse a count or become zero")
            }
        }
        guard case .unknown = DockReader.badgeState(value: nil, error: .success) else {
            return XCTFail("Unexpected missing success value must remain unknown")
        }
    }

    func testBadgeParsing() {
        for text in ["", "  ", "0", "000"] { XCTAssertEqual(UnreadState.badge(text), .clear) }
        for (text, count) in [("1", 1), ("42", 42), (" 12\n", 12)] {
            XCTAssertEqual(UnreadState.badge(text), .unread(count))
        }
        for text in ["99+", "•", "●", "!"] { XCTAssertEqual(UnreadState.badge(text), .unread(nil)) }
    }

    func testFailureIsNeverZeroOrUnread() {
        for text in [nil, "new message", "-1", "1.0", "1,234", "0+", "+", "１２", "١", "1 2", String(repeating: "9", count: 100)] {
            let state = UnreadState.badge(text)
            guard case .unknown = state else { return XCTFail("Invalid badge must be unknown") }
            XCTAssertFalse(state.hasUnread)
        }
    }

    func testStatePrecedence() {
        XCTAssertEqual(UnreadState.resolve(installed: false, running: true, trusted: false, badge: .unread(8)), .notInstalled)
        XCTAssertEqual(UnreadState.resolve(installed: true, running: false, trusted: true, badge: .unread(8)), .notRunning)
        XCTAssertEqual(UnreadState.resolve(installed: true, running: true, trusted: false, badge: .clear), .permissionRequired)
        XCTAssertEqual(UnreadState.resolve(installed: true, running: true, trusted: true, badge: .unknown("failed")), .unknown("failed"))
    }

    func testArrivalClearExitRestartAndRevocation() {
        var state = UnreadState.resolve(installed: true, running: true, trusted: true, badge: .badge(""))
        XCTAssertFalse(state.hasUnread)
        state = .resolve(installed: true, running: true, trusted: true, badge: .badge("4"))
        XCTAssertEqual(state, .unread(4))
        state = .resolve(installed: true, running: true, trusted: true, badge: .badge("0"))
        XCTAssertEqual(state, .clear)
        state = .resolve(installed: true, running: false, trusted: true, badge: .unread(4))
        XCTAssertEqual(state, .notRunning)
        state = .resolve(installed: true, running: true, trusted: true, badge: .badge(nil))
        guard case .unknown = state else { return XCTFail("Restart must not preserve old unread count") }
        state = .resolve(installed: true, running: true, trusted: false, badge: .unread(4))
        XCTAssertEqual(state, .permissionRequired)
    }

    func testUnreadTotalAndStableSort() {
        let states: [UnreadState] = [.unknown("failed"), .unread(120), .unread(nil)]
        XCTAssertEqual(MonitoringPolicy.totalLabel(states), "120+")
        XCTAssertEqual(MonitoringPolicy.totalLabel([.unread(12), .unread(3), .unread(7)]), "22")
        XCTAssertEqual(MonitoringPolicy.totalLabel([.clear, .notRunning, .notInstalled]), "0")
        XCTAssertEqual(MonitoringPolicy.totalLabel([.permissionRequired, .clear, .unread(nil)]), "?")
        XCTAssertEqual(MonitoringPolicy.totalLabel([.unread(2), .permissionRequired]), "2+")
        XCTAssertEqual(MonitoringPolicy.totalLabel([.unread(Int.max), .unread(1)]), "\(Int.max)+")
        XCTAssertEqual(MonitoringPolicy.ordered(states), [1, 2, 0])
        XCTAssertEqual(MonitoringPolicy.ordered([.clear, .notRunning, .notInstalled]), [0, 1, 2])
    }

    func testLowFrequencyPolicy() {
        XCTAssertEqual(MonitoringPolicy.interval(trusted: true, running: true), 3)
        XCTAssertEqual(MonitoringPolicy.interval(trusted: true, running: true, lowPower: true), 6)
        for (trusted, running) in [(false, false), (false, true), (true, false)] {
            XCTAssertEqual(MonitoringPolicy.interval(trusted: trusted, running: running), 15)
        }
    }

    func testCompactCountKeepsExactListNumbers() {
        XCTAssertEqual(MonitoringPolicy.totalLabel([.clear], compact: true), "")
        XCTAssertEqual(MonitoringPolicy.totalLabel([.unread(999)], compact: true), "999")
        for count in [1000, 1001, 12345] {
            XCTAssertEqual(MonitoringPolicy.totalLabel([.unread(count)], compact: true), "999+")
            XCTAssertEqual(MonitoringPolicy.totalLabel([.unread(count)]), String(count))
            XCTAssertEqual(UnreadState.unread(count).label, "\(count) 条未读")
        }
        XCTAssertEqual(MonitoringPolicy.totalLabel([.unread(600), .unread(700)], compact: true), "999+")
        XCTAssertEqual(MonitoringPolicy.totalLabel([.permissionRequired], compact: true), "?")
    }

    @MainActor
    func testOverlayStatusImagesHaveFixedSizeAndReadableCounts() {
        for value in ["", "1", "99", "999", "999+"] {
            let image = StatusIcon.image(count: value)
            XCTAssertEqual(image.size, NSSize(width: 32, height: 22))
            XCTAssertTrue(image.isTemplate, "Native template must adapt to light/dark menu bars")
            XCTAssertNotNil(image.tiffRepresentation)
            let size = (value as NSString).size(withAttributes: [.font: StatusIcon.font])
            XCTAssertLessThanOrEqual(size.width, 25)
            XCTAssertLessThanOrEqual(size.height, 12)
        }
    }

    @MainActor
    func testAdditionalChatAppUsesExistingCountAndSort() {
        var apps = ChatApp.supported
        apps.append(ChatApp(id: "test.additional-chat", name: "Additional Chat", state: .unread(42)))
        XCTAssertEqual(Set(apps.map(\.id)).count, apps.count)
        XCTAssertEqual(MonitoringPolicy.ordered(apps.map(\.state)).first, 3)
        XCTAssertEqual(MonitoringPolicy.totalLabel(apps.map(\.state)), "42+")
    }

    func testParserPerformance() {
        measure {
            for i in 0..<10_000 {
                XCTAssertEqual(UnreadState.badge(String(i)), i == 0 ? .clear : .unread(i))
            }
        }
    }

    @MainActor
    func testSleepScreenAndWakeLifecycle() {
        let monitor = Monitor()
        monitor.start()
        defer { monitor.stop() }
        monitor.powerChanged(NSWorkspace.willSleepNotification)
        XCTAssertTrue(monitor.suspended)
        monitor.powerChanged(NSWorkspace.screensDidSleepNotification)
        monitor.powerChanged(NSWorkspace.didWakeNotification)
        XCTAssertTrue(monitor.suspended, "Screen still off")
        monitor.powerChanged(NSWorkspace.screensDidWakeNotification)
        XCTAssertFalse(monitor.suspended)
        monitor.powerChanged(NSWorkspace.screensDidSleepNotification)
        XCTAssertTrue(monitor.suspended)
        monitor.powerChanged(NSWorkspace.screensDidWakeNotification)
        XCTAssertFalse(monitor.suspended)
    }

    @MainActor
    func testPopoverLayoutCanBeCreatedRepeatedly() {
        let monitor = Monitor()
        defer { monitor.stop() }
        for i in 0..<20 {
            monitor.trusted = i.isMultiple(of: 2)
            monitor.apps[0].state = .unread(12)
            monitor.apps[1].state = .permissionRequired
            monitor.apps[2].state = .unknown("Dock 角标不可读取")
            let host = NSHostingView(rootView: PopoverView(monitor: monitor))
            let size = host.fittingSize
            XCTAssertEqual(size.width, 350, accuracy: 1)
            XCTAssertGreaterThan(size.height, 150)
            XCTAssertLessThan(size.height, 800)
        }
    }

    @MainActor
    func testOpeningMissingAppReportsFailure() {
        let monitor = Monitor()
        defer { monitor.stop() }
        monitor.open(ChatApp(id: "invalid.msgbox.test.missing-app", name: "Test"))
        XCTAssertEqual(monitor.notice, "Test 未安装或系统无法定位它。")
    }

    @MainActor
    func testStartupListWindowUsesSharedMonitorAndIsReused() {
        let delegate = AppDelegate()
        defer { delegate.monitor.stop(); delegate.listWindow.close() }
        let window = delegate.listWindow
        XCTAssertTrue(window === delegate.listWindow)
        XCTAssertEqual(window.title, "聊天未读 · Msgbox")
        XCTAssertTrue(window.styleMask.contains(.closable))
        XCTAssertFalse(window.isReleasedWhenClosed)
        guard let host = window.contentViewController as? NSHostingController<PopoverView> else {
            return XCTFail("List window must use the existing native list")
        }
        XCTAssertTrue(host.rootView.monitor === delegate.monitor)
        XCTAssertTrue(delegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false))
        XCTAssertTrue(window.isVisible)
        XCTAssertTrue(delegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: true))
        XCTAssertTrue(window === delegate.listWindow, "Reopen must not create duplicate windows")
    }

    func testReaderWithoutPermissionDoesNotReadUI() async {
        let reader = DockReader()
        let targets = [TargetSnapshot(id: "not.installed", url: nil, running: false),
                       TargetSnapshot(id: "test", url: URL(fileURLWithPath: "/Applications/Test.app"), running: true)]
        let states = await reader.read(targets, trusted: false)
        XCTAssertEqual(states, [.notInstalled, .permissionRequired])
    }
}
