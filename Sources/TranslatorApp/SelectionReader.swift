import AppKit
import ApplicationServices

struct SelectionInfo {
    var text: String
    var bounds: CGRect?
    var sourceApp: String?
    var mouseUpPoint: NSPoint
    var via: String   // "ax" | "clipboard"
}

enum SelectionReader {
    static func read(mouseUpPoint: NSPoint) async -> SelectionInfo? {
        if let r = readViaAX(mouseUpPoint: mouseUpPoint) {
            return r
        }
        Log.info("AX 拿不到，尝试 Cmd+C 兜底  fallback=\(SettingsStore.shared.useClipboardFallback)")
        if SettingsStore.shared.useClipboardFallback {
            if let r = await readViaClipboard(mouseUpPoint: mouseUpPoint) {
                return r
            }
        }
        return nil
    }

    /// 由 ⌥⇧T 全局快捷键触发：不依赖 mouseUp，用当前鼠标位置
    static func readNow() async -> SelectionInfo? {
        let pt = NSEvent.mouseLocation
        return await read(mouseUpPoint: pt)
    }

    private static func readViaAX(mouseUpPoint: NSPoint) -> SelectionInfo? {
        let system = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focusedRef)
        guard err == .success, let focused = focusedRef,
              CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            Log.warn("AX focused element 取不到 err=\(err.rawValue)")
            return nil
        }
        let el = focused as! AXUIElement

        var selRef: CFTypeRef?
        let sErr = AXUIElementCopyAttributeValue(el, kAXSelectedTextAttribute as CFString, &selRef)
        guard sErr == .success, let text = selRef as? String else {
            Log.warn("AX kAXSelectedText 取不到 err=\(sErr.rawValue)")
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, containsEnglishLetters(trimmed) else {
            Log.info("AX 拿到的文字 不含英文，跳过：\(text.prefix(30))")
            return nil
        }

        var bounds: CGRect?
        var rangeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
           let rangeRef {
            var bRef: CFTypeRef?
            if AXUIElementCopyParameterizedAttributeValue(el, kAXBoundsForRangeParameterizedAttribute as CFString, rangeRef, &bRef) == .success,
               let bRef {
                var rect = CGRect.zero
                AXValueGetValue(bRef as! AXValue, .cgRect, &rect)
                if rect.width > 0 && rect.height > 0 { bounds = rect }
            }
        }

        let capped = trimmed.count > 800 ? String(trimmed.prefix(800)) : trimmed
        return SelectionInfo(
            text: capped, bounds: bounds,
            sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName,
            mouseUpPoint: mouseUpPoint, via: "ax"
        )
    }

    private static func readViaClipboard(mouseUpPoint: NSPoint) async -> SelectionInfo? {
        let pb = NSPasteboard.general
        let savedString = pb.string(forType: .string)
        let prevChangeCount = pb.changeCount

        // 模拟 Cmd+C
        let src = CGEventSource(stateID: .combinedSessionState)
        let cKey: CGKeyCode = 0x08
        let down = CGEvent(keyboardEventSource: src, virtualKey: cKey, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: cKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags   = .maskCommand
        // 用 cghidEventTap 注入最底层；某些 App 用 session tap 不响应
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        // 最多等 700ms 看剪贴板是否变化
        var got = false
        for _ in 0..<35 {
            try? await Task.sleep(nanoseconds: 20_000_000)
            if pb.changeCount > prevChangeCount { got = true; break }
        }
        if got {
            try? await Task.sleep(nanoseconds: 60_000_000)
        }

        let copied = pb.string(forType: .string)
        // 还原原内容
        if let savedString, savedString != copied {
            pb.clearContents()
            pb.setString(savedString, forType: .string)
        }

        guard let raw = copied else {
            Log.warn("Cmd+C: 剪贴板没拿到 string")
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, containsEnglishLetters(trimmed) else {
            Log.info("Cmd+C: 内容不含英文 \(trimmed.prefix(30))")
            return nil
        }
        let capped = trimmed.count > 800 ? String(trimmed.prefix(800)) : trimmed
        return SelectionInfo(
            text: capped, bounds: nil,
            sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName,
            mouseUpPoint: mouseUpPoint, via: "clipboard"
        )
    }

    private static func containsEnglishLetters(_ s: String) -> Bool {
        for scalar in s.unicodeScalars where scalar.isASCII {
            if (0x41...0x5A).contains(scalar.value) || (0x61...0x7A).contains(scalar.value) { return true }
        }
        return false
    }
}
