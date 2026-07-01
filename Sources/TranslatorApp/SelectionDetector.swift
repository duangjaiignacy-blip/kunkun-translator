import AppKit
import CoreGraphics

final class SelectionDetector {
    var onSelected: ((SelectionInfo) -> Void)?
    var onCancel: (() -> Void)?
    var onNoText: ((NSPoint) -> Void)?
    /// 判断某个屏幕坐标是否落在当前小圆点上。落在圆点上的点击不应触发取消，
    /// 否则会把还没来得及响应点击手势的圆点关掉（竞态）。
    var isPointInBubble: ((NSPoint) -> Bool)?

    private var tap: CFMachPort?
    private var runLoopSrc: CFRunLoopSource?

    private var dragStart: NSPoint = .zero
    private var dragDistance: CGFloat = 0
    private var isMouseDown = false
    private var modifierHeldAtDown = false

    private let minDragDistance: CGFloat = 4

    func start() {
        stop()
        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.keyDown.rawValue)

        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, ctx in
                guard let ctx else { return Unmanaged.passUnretained(event) }
                let me = Unmanaged<SelectionDetector>.fromOpaque(ctx).takeUnretainedValue()
                me.process(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Log.error("SelectionDetector: 创建 event tap 失败 — 辅助功能权限可能没给")
            return
        }
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        tap = port
        runLoopSrc = src
        Log.info("SelectionDetector started")
    }

    func stop() {
        if let port = tap { CGEvent.tapEnable(tap: port, enable: false) }
        if let src = runLoopSrc { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        tap = nil
        runLoopSrc = nil
    }

    private func process(type: CGEventType, event: CGEvent) {
        guard SettingsStore.shared.enabled else { return }
        let loc = NSEvent.mouseLocation

        switch type {
        case .keyDown:
            DispatchQueue.main.async { self.onCancel?() }

        case .leftMouseDown:
            // 点在小圆点上：让点击穿到圆点本身，别关掉它，也别开始新的框选。
            if isPointInBubble?(loc) == true { return }
            isMouseDown = true
            dragStart = loc
            dragDistance = 0
            modifierHeldAtDown = event.flags.contains(.maskAlternate)
            DispatchQueue.main.async { self.onCancel?() }

        case .leftMouseDragged:
            guard isMouseDown else { return }
            dragDistance = max(dragDistance, hypot(loc.x - dragStart.x, loc.y - dragStart.y))

        case .leftMouseUp:
            defer { isMouseDown = false }
            guard isMouseDown else { return }
            guard dragDistance >= minDragDistance else { return }

            if SettingsStore.shared.triggerMode == .modifierSelection && !modifierHeldAtDown {
                return
            }

            let mouseUp = loc
            let app = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
            Log.info("mouseUp dragDist=\(Int(dragDistance)) app=\(app)")
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 80_000_000)
                if let info = await SelectionReader.read(mouseUpPoint: mouseUp) {
                    Log.info("selection ok via \(info.via) bytes=\(info.text.count)")
                    self.onSelected?(info)
                } else {
                    Log.warn("selection empty — AX & 剪贴板都没拿到")
                    self.onNoText?(mouseUp)
                }
            }

        default:
            break
        }
    }
}
