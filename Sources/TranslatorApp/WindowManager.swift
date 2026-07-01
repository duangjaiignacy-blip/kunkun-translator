import AppKit
import SwiftUI

final class WindowManager: NSObject, NSWindowDelegate {
    static let shared = WindowManager()

    private var mainWin: NSWindow?

    func showMain(tab: MainTab? = nil) {
        if mainWin == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 920, height: 700),
                styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
            w.title = "困困翻译助手"
            w.titlebarAppearsTransparent = true
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            w.contentView = NSHostingView(rootView: MainView())
            mainWin = w
        }
        if let t = tab, let mw = mainWin {
            mw.contentView = NSHostingView(rootView: MainView(initialTab: t))
        }
        // 先切换激活策略并把窗口置前成为 key window，再激活 App。
        // 顺序很重要：菜单栏应用(.accessory)若激活时机不对，窗口拿不到键盘焦点，
        // 导致输入框里 ⌘V 粘贴、⌘A 全选等标准快捷键失效。
        NSApp.setActivationPolicy(.regular)
        mainWin?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // 再补一次 key，确保内容视图里的第一响应者（输入框）真正接管键盘。
        DispatchQueue.main.async { [weak self] in
            self?.mainWin?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            let hasVisible = NSApp.windows.contains { $0.isVisible && !($0 is NSPanel) }
            if !hasVisible {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
