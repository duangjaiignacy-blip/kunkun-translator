import AppKit

final class StatusBarController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    override init() {
        super.init()
        if let btn = item.button {
            // 用 SF Symbol 做更精致的图标，模板色自动适配菜单栏
            let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            if let img = NSImage(systemSymbolName: "character.bubble.fill", accessibilityDescription: "困困翻译助手")?
                .withSymbolConfiguration(cfg) {
                img.isTemplate = true
                btn.image = img
                btn.imagePosition = .imageOnly
            } else {
                btn.title = "译"
            }
            btn.toolTip = "困困翻译助手"
        }
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()
        let header = NSMenuItem(title: "困困翻译助手", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: SettingsStore.shared.enabled ? "✓ 启用全局翻译" : "✗ 已暂停",
                                action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())

        menu.addItem(makeItem("打开主界面…", action: #selector(openMain), key: ","))
        menu.addItem(.separator())
        menu.addItem(makeItem("生词本", action: #selector(openVocab)))
        menu.addItem(makeItem("学习总结", action: #selector(openSummary)))
        menu.addItem(makeItem("设置", action: #selector(openSettings)))
        menu.addItem(.separator())
        menu.addItem(makeItem("辅助功能权限…", action: #selector(openAX)))
        menu.addItem(.separator())
        menu.addItem(makeItem("退出", action: #selector(quit), key: "q"))
        item.menu = menu
    }

    private func makeItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc private func toggleEnabled() {
        SettingsStore.shared.enabled.toggle()
        rebuildMenu()
    }
    @objc private func openMain()     { WindowManager.shared.showMain() }
    @objc private func openSettings() { WindowManager.shared.showMain(tab: .settings) }
    @objc private func openVocab()    { WindowManager.shared.showMain(tab: .vocabulary) }
    @objc private func openSummary()  { WindowManager.shared.showMain(tab: .summary) }
    @objc private func openAX()       { Permissions.openAccessibilitySettings() }
    @objc private func quit()         { NSApp.terminate(nil) }
}
