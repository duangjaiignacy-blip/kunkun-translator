import SwiftUI
import AppKit
import Translation

/// 苹果系统离线翻译封装。
///
/// 背景：`TranslationSession` 不能自己 new，只能由 SwiftUI 的 `.translationTask` 闭包提供。
/// 所以这里挂一个**离屏隐藏的 NSHostingView** 承载带 `.translationTask` 的视图，
/// 通过一个共享的 driver（ObservableObject）把「翻译请求」喂进去、把「结果」回调出来，
/// 再用 continuation 把回调式 API 包成 `async` 函数给外部直接 await。
///
/// 体积/内存：零额外体积，语言包由系统按需下载（几十 MB），几乎不占内存。
/// 能力边界：只给译文，没有音标/词性/释义/例句（那是 LLM 才有的）。
@available(macOS 15.0, *)
@MainActor
final class AppleTranslator {
    static let shared = AppleTranslator()

    private let driver = TranslationDriver()
    private var hostingView: NSHostingView<TranslationHostView>?
    private var hostWindow: NSWindow?

    private init() {
        setupHiddenHost()
    }

    /// 把承载 .translationTask 的隐藏视图挂到一个离屏窗口里，使其参与视图生命周期。
    private func setupHiddenHost() {
        let root = TranslationHostView(driver: driver)
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(x: 0, y: 0, width: 1, height: 1)

        // 离屏窗口：放在可见区域外，不激活、不抢焦点，仅用于驱动翻译视图。
        let win = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered, defer: false
        )
        win.contentView = host
        win.isReleasedWhenClosed = false
        win.level = .normal
        win.alphaValue = 0
        win.ignoresMouseEvents = true
        win.orderBack(nil)   // 入窗口层级但不可见

        self.hostingView = host
        self.hostWindow = win
    }

    /// 离线翻译一段文本。失败（语言包没下、不支持等）返回 nil。
    /// - Parameters:
    ///   - text: 源文本（英文）
    ///   - target: 目标语言代码，默认中文
    func translate(_ text: String, target: String = "zh-Hans") async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return await driver.requestTranslation(text: trimmed, target: target)
    }
}

/// 桥接 driver：持有当前待翻译请求 + 把结果交回 continuation。
@available(macOS 15.0, *)
@MainActor
final class TranslationDriver: ObservableObject {
    /// 改变它会触发视图重建 .translationTask 的 configuration，从而执行一次翻译。
    @Published var config: TranslationSession.Configuration?

    private var pendingText: String = ""
    private var continuation: CheckedContinuation<String?, Never>?

    /// 发起一次翻译，挂起直到 .translationTask 回调把结果送回来。
    func requestTranslation(text: String, target: String) async -> String? {
        // 上一个请求若还没完成，先放掉（返回 nil），避免 continuation 泄漏。
        if let c = continuation {
            continuation = nil
            c.resume(returning: nil)
        }
        pendingText = text
        return await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            self.continuation = cont
            // 设置 configuration 触发 translationTask 执行；target 用系统识别源语言→指定目标。
            self.config = TranslationSession.Configuration(
                source: nil,
                target: Locale.Language(identifier: target)
            )
        }
    }

    /// 由视图的 .translationTask 闭包调用，拿到 session 后真正执行翻译。
    func perform(with session: TranslationSession) async {
        let text = pendingText
        guard !text.isEmpty else { return }
        var result: String? = nil
        do {
            let response = try await session.translate(text)
            result = response.targetText
        } catch {
            Log.warn("Apple 离线翻译失败：\(error.localizedDescription)")
            result = nil
        }
        finish(with: result)
    }

    /// 把结果交回等待的 continuation，并清空状态。
    func finish(with result: String?) {
        guard let c = continuation else { return }
        continuation = nil
        config = nil
        c.resume(returning: result)
    }
}

/// 承载 .translationTask 的隐藏视图。它本身不渲染任何可见内容。
@available(macOS 15.0, *)
struct TranslationHostView: View {
    @ObservedObject var driver: TranslationDriver

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(driver.config) { session in
                await driver.perform(with: session)
            }
    }
}
