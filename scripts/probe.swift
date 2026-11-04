import AppKit
import ApplicationServices
for path in ["/Applications/WeChat.app", "/Applications/QQ.app", "/Applications/Telegram.app", "/Applications/Discord.app"] {
 if let bundle = Bundle(path: path), let id = bundle.bundleIdentifier {
 print("app=\(path) id=\(id) version=\(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "unknown") running=\(NSRunningApplication.runningApplications(withBundleIdentifier: id).count)")
 }
}
print("AX trusted=\(AXIsProcessTrusted()) (no prompt requested)")
if let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first {
 let ax = AXUIElementCreateApplication(dock.processIdentifier)
 AXUIElementSetMessagingTimeout(ax, 0.3)
 var value: CFTypeRef?
 let result = AXUIElementCopyAttributeValue(ax, kAXChildrenAttribute as CFString, &value)
 print("Dock pid=\(dock.processIdentifier) children result=\(result.rawValue)")
 // Do not traverse unrelated UI or log badge/title values.
}
