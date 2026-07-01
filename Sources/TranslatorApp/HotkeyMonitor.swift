import AppKit

final class HotkeyMonitor {
    var onTrigger: (() -> Void)?

    private var monitor: Any?

    func start() {
        stop()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // ⌥⇧T : keyCode 17, flags = option + shift
            if flags == [.option, .shift] && event.keyCode == 17 {
                self?.onTrigger?()
            }
        }
        if monitor == nil {
            Log.warn("HotkeyMonitor 无法启动 — 检查辅助功能权限")
        } else {
            Log.info("HotkeyMonitor started: ⌥⇧T")
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }
}
