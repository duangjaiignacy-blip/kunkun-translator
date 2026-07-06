import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    private var selection: SelectionDetector?
    private var bubble: BubbleController?
    private var hotkey: HotkeyMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("App launched")

        // 监听"再次启动"通知，弹出主界面
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("TranslatorApp.ShowMain"),
            object: nil, queue: .main
        ) { _ in
            Log.info("Re-open requested → 显示主界面")
            WindowManager.shared.showMain()
        }

        statusBar = StatusBarController()
        bubble = BubbleController()

        let detector = SelectionDetector()
        detector.onSelected = { [weak self] info in
            // 浮标模式才在框选后弹圆点；纯快捷键模式下框选不打扰。
            guard SettingsStore.shared.interactionMode.bubbleEnabled else { return }
            self?.bubble?.show(info: info)
        }
        detector.onCancel = { [weak self] in
            self?.bubble?.dismissBubble()
        }
        detector.onNoText = { _ in
            // selection empty; keep quiet in bubble mode.
            // 选区内容为空或宿主 App 不暴露选中文本时，不再打扰用户。
            Log.info("selection empty; bubble toast suppressed")
        }
        detector.isPointInBubble = { [weak self] p in
            self?.bubble?.bubbleContains(p) ?? false
        }
        selection = detector

        let hk = HotkeyMonitor()
        hk.onTrigger = { [weak self] in
            // 快捷键模式才响应；纯浮标模式下忽略快捷键。
            guard SettingsStore.shared.interactionMode.hotkeyEnabled else { return }
            Task { @MainActor in
                let mouseLoc = NSEvent.mouseLocation
                if let info = await SelectionReader.readNow() {
                    // 直接弹翻译框并翻译，跳过小圆点。
                    self?.bubble?.showResultDirectly(info: info)
                } else {
                    self?.bubble?.showToast("未读到选中文字（先选中文本再按快捷键）", at: mouseLoc, kind: .warning)
                }
            }
        }
        hotkey = hk

        let trusted = Permissions.isAccessibilityTrusted(prompt: true)
        Log.info("AX trusted at launch = \(trusted) — binary=\(Bundle.main.executablePath ?? "?")")
        detector.start()
        hk.start()

        if SettingsStore.shared.apiKey.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                WindowManager.shared.showMain(tab: .settings)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Log.info("reopen hasVisibleWindows=\(flag)")
        if !flag {
            WindowManager.shared.showMain()
        }
        return true
    }
}
