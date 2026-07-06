import AppKit
import SwiftUI

final class BubbleController {
    private var bubblePanel: NSPanel?
    private var resultPanel: NSPanel?
    private var toastPanel: NSPanel?
    private var current: SelectionInfo?
    private let bubbleSize: CGFloat = 22
    private var toastTimer: Timer?

    func show(info: SelectionInfo) {
        if let c = current, c.text == info.text,
           bubblePanel?.isVisible == true || resultPanel?.isVisible == true {
            return
        }
        resultPanel?.orderOut(nil)
        current = info
        showBubble(for: info)
    }

    func dismissBubble() {
        bubblePanel?.orderOut(nil)
    }

    /// 快捷键模式：跳过小圆点，直接在选区/鼠标旁弹出翻译框并立即翻译。
    func showResultDirectly(info: SelectionInfo) {
        current = info
        bubblePanel?.orderOut(nil)
        openResult()
    }

    /// 某个屏幕坐标是否落在当前可见的小圆点上（含一点点容差）。
    func bubbleContains(_ p: NSPoint) -> Bool {
        guard let panel = bubblePanel, panel.isVisible else { return false }
        return panel.frame.insetBy(dx: -6, dy: -6).contains(p)
    }

    func dismissAll() {
        bubblePanel?.orderOut(nil)
        resultPanel?.orderOut(nil)
        toastPanel?.orderOut(nil)
        current = nil
    }

    // MARK: - 失败/状态提示气泡（2 秒消失）

    func showToast(_ message: String, at point: NSPoint, kind: ToastKind = .warning) {
        let panel = toastPanel ?? makeToastPanel()
        let host = NSHostingView(rootView: ToastView(text: message, kind: kind))
        host.frame = NSRect(x: 0, y: 0, width: 260, height: 44)
        panel.contentView = host
        panel.setContentSize(NSSize(width: 260, height: 44))
        panel.setFrameOrigin(NSPoint(x: point.x + 14, y: point.y + 14))
        panel.orderFrontRegardless()
        toastPanel = panel
        toastTimer?.invalidate()
        toastTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.toastPanel?.orderOut(nil)
        }
    }

    private func makeToastPanel() -> NSPanel {
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 260, height: 44),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .statusBar
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isOpaque = false
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        return p
    }

    // MARK: - 小圆点

    private func showBubble(for info: SelectionInfo) {
        guard let screen = NSScreen.screens.first else { return }
        let nsOrigin: NSPoint
        if let b = info.bounds, b.width > 0, b.height > 0 {
            let topRightX = b.maxX
            let topY = b.minY
            nsOrigin = NSPoint(x: topRightX + 4, y: screen.frame.height - topY - bubbleSize)
        } else {
            nsOrigin = NSPoint(x: info.mouseUpPoint.x + 8, y: info.mouseUpPoint.y + 8)
        }
        let frame = NSRect(x: nsOrigin.x, y: nsOrigin.y, width: bubbleSize, height: bubbleSize)
        let panel = bubblePanel ?? makeBubblePanel()
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        bubblePanel = panel
        Log.info("bubble shown at \(Int(frame.origin.x)),\(Int(frame.origin.y)) bounds=\(info.bounds != nil)")
    }

    private func makeBubblePanel() -> NSPanel {
        let p = NSPanel(contentRect: .init(x: 0, y: 0, width: bubbleSize, height: bubbleSize),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .statusBar
        p.backgroundColor = .clear
        p.hasShadow = false
        p.isOpaque = false
        p.ignoresMouseEvents = false
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        let host = NSHostingView(rootView: BubbleView(onTap: { [weak self] in self?.openResult() }))
        host.frame = NSRect(x: 0, y: 0, width: bubbleSize, height: bubbleSize)
        p.contentView = host
        return p
    }

    private func openResult() {
        Log.info("打开翻译卡片 text=\(current?.text.prefix(30) ?? "")")
        guard let info = current else { return }
        bubblePanel?.orderOut(nil)
        let size = NSSize(width: 380, height: 320)
        guard let screen = NSScreen.screens.first else { return }
        // 定位锚点：优先用圆点位置；圆点没显示过（快捷键直弹）时用选区 bounds，再退到鼠标点。
        let anchor = anchorFrame(for: info, screenHeight: screen.frame.height)
        let bubbleFrame = anchor
        var origin = NSPoint(x: bubbleFrame.maxX + 6, y: bubbleFrame.maxY - size.height)
        if origin.x + size.width > screen.frame.maxX - 8 {
            origin.x = max(8, bubbleFrame.minX - size.width - 6)
        }
        if origin.y < 8 { origin.y = 8 }
        if origin.y + size.height > screen.frame.maxY - 8 {
            origin.y = screen.frame.maxY - size.height - 8
        }
        let rect = NSRect(origin: origin, size: size)
        let panel = resultPanel ?? makeResultPanel(size: size)
        let view = TranslationView(
            text: info.text, sourceApp: info.sourceApp,
            onClose: { [weak self] in self?.resultPanel?.orderOut(nil) }
        )
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: size)
        panel.contentView = host
        panel.setFrame(rect, display: true)
        panel.orderFrontRegardless()
        resultPanel = panel
    }

    /// 计算翻译框定位锚点（屏幕坐标系，原点左下）。
    /// 圆点可见 → 用圆点 frame；否则用选区 bounds（AX 坐标原点左上，需翻转）；再退到鼠标点。
    private func anchorFrame(for info: SelectionInfo, screenHeight: CGFloat) -> NSRect {
        if let panel = bubblePanel, panel.isVisible {
            return panel.frame
        }
        if let b = info.bounds, b.width > 0, b.height > 0 {
            let x = b.maxX
            let y = screenHeight - b.minY - bubbleSize
            return NSRect(x: x + 4, y: y, width: bubbleSize, height: bubbleSize)
        }
        let p = info.mouseUpPoint
        return NSRect(x: p.x + 8, y: p.y + 8, width: bubbleSize, height: bubbleSize)
    }

    private func makeResultPanel(size: NSSize) -> NSPanel {
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                        backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .statusBar
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isOpaque = false
        p.isMovableByWindowBackground = true
        p.alphaValue = 0.96
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        return p
    }
}

enum ToastKind {
    case warning, info
}

struct ToastView: View {
    let text: String
    let kind: ToastKind
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: kind == .warning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundColor(kind == .warning ? .orange : .blue)
            Text(text).font(.system(size: 12)).lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.1), lineWidth: 1))
    }
}

struct BubbleView: View {
    let onTap: () -> Void
    @State private var hover = false
    var body: some View {
        Circle()
            .fill(LinearGradient(colors: [.blue, .purple],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Text("译").font(.system(size: 10, weight: .bold)).foregroundColor(.white))
            .shadow(color: .black.opacity(0.3), radius: hover ? 5 : 2, x: 0, y: 1)
            .scaleEffect(hover ? 1.18 : 1.0)
            .animation(.easeOut(duration: 0.12), value: hover)
            .onHover { hover = $0 }
            .onTapGesture { onTap() }
            .frame(width: 22, height: 22)
    }
}

struct TranslationView: View {
    let text: String
    let sourceApp: String?
    let onClose: () -> Void

    @State private var loading = true
    @State private var result: TranslationResult?
    @State private var errorMsg: String?
    @State private var saved = false
    @State private var streamingText: String = ""   // 流式阶段实时译文
    @State private var enriching = false             // 是否正在后台补释义

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                header
                Divider()
                content
                Spacer(minLength: 0)
                footer
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 1))

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14)).foregroundColor(.secondary)
            }
            .buttonStyle(.borderless).padding(6)
        }
        .task(id: text) { await load() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(text).font(.system(size: 14, weight: .semibold)).lineLimit(3).textSelection(.enabled)
            Spacer()
            Button { Speaker.shared.speak(text) } label: { Image(systemName: "speaker.wave.2.fill") }
                .buttonStyle(.borderless).help("朗读")
        }
        .padding(.trailing, 18)
    }

    @ViewBuilder
    private var content: some View {
        if loading && !streamingText.isEmpty {
            // 流式阶段：译文逐字蹦出
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(streamingText).font(.system(size: 16, weight: .bold)).textSelection(.enabled)
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.small)
                        Text("翻译中…").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        } else if loading {
            HStack { ProgressView().controlSize(.small); Text("翻译中…").foregroundColor(.secondary) }
        } else if let err = errorMsg {
            Text(err).font(.callout).foregroundColor(.red)
        } else if let r = result {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(r.translation).font(.system(size: 16, weight: .bold)).textSelection(.enabled)
                        if let p = r.pronunciation, !p.isEmpty {
                            Text(p).font(.caption).foregroundColor(.secondary)
                        }
                        if r.isOffline {
                            Label("离线", systemImage: "wifi.slash")
                                .font(.caption2)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.orange.opacity(0.18)).clipShape(Capsule())
                                .foregroundColor(.orange)
                                .help("当前无网络，使用苹果系统离线翻译，仅有译文")
                        }
                    }
                    if let pos = r.partOfSpeech, !pos.isEmpty {
                        Text(pos).font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15)).clipShape(Capsule())
                    }
                    if !r.definitions.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(r.definitions, id: \.self) { Text("• \($0)").font(.system(size: 13)) }
                        }
                    }
                    if !r.examples.isEmpty {
                        Divider()
                        Text("例句").font(.caption.bold()).foregroundColor(.secondary)
                        ForEach(r.examples, id: \.self) { Text($0).font(.system(size: 12)).foregroundColor(.secondary) }
                    }
                    if enriching {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.small)
                            Text("补充释义中…").font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            // 显示这条译文来自哪个模型（离线降级时显示「苹果离线翻译」）。
            Text(modelLabel).font(.caption2).foregroundColor(.secondary)
                .lineLimit(1).truncationMode(.middle)
                .help(modelLabel)
            Spacer()
            Button(action: save) {
                Label(saved ? "已加入生词本" : "加入生词本",
                      systemImage: saved ? "checkmark.circle.fill" : "star").font(.caption)
            }
            .buttonStyle(.borderedProminent).controlSize(.small)
            .disabled(saved || result == nil)
        }
    }

    /// 左下角标签：离线结果显示「苹果离线翻译」，否则显示当前模型名。
    private var modelLabel: String {
        if result?.isOffline == true { return "苹果离线翻译" }
        let m = SettingsStore.shared.model
        return m.isEmpty ? "—" : m
    }

    private func load() async {
        loading = true; errorMsg = nil; result = nil; saved = false
        streamingText = ""; enriching = false
        do {
            // 阶段1：流式译文，逐字更新 streamingText
            let translation = try await LLMClient.shared.translateStream(text: text) { partial in
                streamingText = partial
            }
            // 译文完成 → 先展示只有译文的卡片
            result = TranslationResult(translation: translation, pronunciation: nil,
                                       partOfSpeech: nil, definitions: [], examples: [], isOffline: false)
            loading = false
            Log.info("stream translate ok: \(text.prefix(40))")

            // 阶段2：后台补音标/词性/释义/例句
            enriching = true
            if let enriched = await LLMClient.shared.enrich(text: text, translation: translation) {
                result = enriched
            }
            enriching = false
        } catch {
            // 流式失败 → 回退到原有的一次性翻译（内含断网离线降级）
            Log.warn("stream 失败(\(error.localizedDescription))，回退非流式")
            do {
                result = try await LLMClient.shared.translate(text: text)
            } catch {
                errorMsg = error.localizedDescription
                Log.error("translate failed: \(error.localizedDescription)")
            }
            loading = false
            enriching = false
        }
    }

    private func save() {
        guard let r = result else { return }
        let item = VocabularyItem(
            word: text, context: nil, translation: r.translation,
            pronunciation: r.pronunciation, partOfSpeech: r.partOfSpeech,
            definitions: r.definitions, examples: r.examples, sourceApp: sourceApp
        )
        VocabularyStore.shared.add(item)
        saved = true
    }
}
