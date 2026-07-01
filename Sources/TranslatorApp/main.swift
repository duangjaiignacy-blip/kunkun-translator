import AppKit
import Foundation

// 单实例：如果已经有一个 翻译助手 在跑，新进程发通知让旧实例打开主界面，自己退出
let bundleID = "com.local.translator"
let myPID = ProcessInfo.processInfo.processIdentifier
let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    .filter { $0.processIdentifier != myPID }

if !others.isEmpty {
    DistributedNotificationCenter.default().postNotificationName(
        Notification.Name("TranslatorApp.ShowMain"),
        object: nil, userInfo: nil, deliverImmediately: true
    )
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
