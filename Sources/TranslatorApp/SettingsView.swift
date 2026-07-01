import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = SettingsStore.shared
    @State private var logSnapshot: String = ""
    @State private var logRevealed = false
    @State private var testStatus: TestStatus = .idle
    @State private var modelFetchStatus: ModelFetchStatus = .idle
    @State private var revealKey = false

    enum TestStatus: Equatable {
        case idle
        case testing
        case ok(String)
        case fail(String)
    }

    enum ModelFetchStatus: Equatable {
        case idle
        case loading
        case ok(Int)
        case fail(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                providerCard
                triggerCard
                speechCard
                permissionCard
                logCard
                Spacer(minLength: 8)
            }
            .padding(22)
        }
        .scrollContentBackground(.hidden)
        .frame(minWidth: 640, minHeight: 560)
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [
                        Color(red: 0.50, green: 0.35, blue: 0.95),
                        Color(red: 0.85, green: 0.50, blue: 1.0)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("设置").font(.system(size: 22, weight: .black))
                Text("配置 AI 服务商、触发方式与朗读")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var providerCard: some View {
        cardBox(title: "AI 服务商", icon: "brain") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("服务商").frame(width: 80, alignment: .leading)
                    Picker("", selection: providerBinding) {
                        ForEach(LLMProvider.allCases) { p in Text(p.rawValue).tag(p) }
                    }
                    .labelsHidden()
                }
                row("API Key") {
                    HStack(spacing: 6) {
                        if revealKey {
                            TextField("sk-...（存于系统钥匙串）", text: $settings.apiKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("sk-...（存于系统钥匙串）", text: $settings.apiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        Button {
                            if let s = NSPasteboard.general.string(forType: .string) {
                                settings.apiKey = s.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .buttonStyle(.bordered)
                        .help("从剪贴板粘贴 Key")

                        Button {
                            revealKey.toggle()
                        } label: {
                            Image(systemName: revealKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.bordered)
                        .help(revealKey ? "隐藏" : "显示明文，方便核对")
                    }
                }
                row("Base URL") {
                    TextField("", text: $settings.baseURL)
                        .textFieldStyle(.roundedBorder)
                }
                modelRow
                row("目标语言") {
                    TextField("中文", text: $settings.targetLanguage)
                        .textFieldStyle(.roundedBorder)
                }
                HStack(spacing: 8) {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        Label(testStatus == .testing ? "测试中…" : "测试连接", systemImage: "wifi")
                    }
                    .buttonStyle(.bordered)
                    .disabled(testStatus == .testing || settings.apiKey.isEmpty)

                    switch testStatus {
                    case .idle: EmptyView()
                    case .testing:
                        ProgressView().controlSize(.small)
                    case .ok(let msg):
                        Label(msg, systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.system(size: 12))
                    case .fail(let msg):
                        Label(msg, systemImage: "xmark.octagon.fill").foregroundStyle(.red).font(.system(size: 12)).lineLimit(2)
                    }
                    Spacer()
                }
                providerHints
            }
        }
    }

    /// 切换 provider 走原子方法，避免 key 串账户。
    private var providerBinding: Binding<LLMProvider> {
        Binding(
            get: { settings.provider },
            set: { newValue in
                guard newValue != settings.provider else { return }
                settings.switchProvider(to: newValue)
                testStatus = .idle
                modelFetchStatus = .idle
            }
        )
    }

    /// 模型行：支持在线拉取的服务商（硅基流动/自定义）显示下拉 + 刷新；其它手填。
    @ViewBuilder
    private var modelRow: some View {
        if settings.provider.supportsModelCatalog {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("模型").frame(width: 80, alignment: .leading)
                    Picker("", selection: $settings.model) {
                        // 当前选中的 model 若不在列表里，也补一条，避免选中态丢失
                        ForEach(modelOptions, id: \.self) { m in Text(m).tag(m) }
                    }
                    .labelsHidden()

                    Button {
                        Task { await refreshModels() }
                    } label: {
                        if modelFetchStatus == .loading {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("刷新", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(modelFetchStatus == .loading || settings.apiKey.isEmpty)
                }
                modelFetchHint
            }
        } else {
            row("模型名") {
                TextField("", text: $settings.model)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    /// 下拉里展示的模型：优先用刷新拿到的在线列表，否则兜底清单；
    /// 并保证当前 model 一定在内（防止选中态消失）。
    private var modelOptions: [String] {
        var base = settings.fetchedModels.isEmpty ? settings.provider.fallbackModels : settings.fetchedModels
        if !settings.model.isEmpty && !base.contains(settings.model) {
            base.insert(settings.model, at: 0)
        }
        return base
    }

    @ViewBuilder
    private var modelFetchHint: some View {
        switch modelFetchStatus {
        case .idle:
            hint("点「刷新」用你的 Key 拉取该平台当前在线模型；没刷新时是内置常用项。")
        case .loading:
            EmptyView()
        case .ok(let n):
            Label("已拉取 \(n) 个在线模型", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green).font(.system(size: 11))
        case .fail(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange).font(.system(size: 11)).lineLimit(2)
        }
    }

    private func refreshModels() async {
        modelFetchStatus = .loading
        do {
            let ids = try await ModelCatalog.fetchModels(baseURL: settings.baseURL, apiKey: settings.apiKey)
            settings.fetchedModels = ids
            // 当前 model 不在新列表里时，自动选第一个，避免发请求时用了无效 id
            if !ids.contains(settings.model), let first = ids.first {
                settings.model = first
            }
            modelFetchStatus = .ok(ids.count)
        } catch {
            modelFetchStatus = .fail(error.localizedDescription)
        }
    }

    private var providerHints: some View {
        Group {
            switch settings.provider {
            case .siliconflow:
                hint("API Key 申请：cloud.siliconflow.cn → 一个 Key 可切 DeepSeek / GLM / MiniMax / MiMo 等多家模型。")
            case .deepseek:
                hint("API Key 申请：platform.deepseek.com/api_keys")
            case .qwen:
                hint("API Key 申请：dashscope.console.aliyun.com/apiKey（用 OpenAI 兼容协议）")
            case .kimi:
                hint("API Key 申请：platform.moonshot.cn/console/api-keys")
            case .custom:
                hint("自定义服务商：填写 OpenAI 兼容的 /v1 Base URL 与模型名即可")
            }
        }
    }

    private var triggerCard: some View {
        cardBox(title: "触发方式", icon: "hand.tap.fill") {
            VStack(alignment: .leading, spacing: 10) {
                row("交互方式") {
                    Picker("", selection: $settings.interactionMode) {
                        ForEach(InteractionMode.allCases) { m in Text(m.rawValue).tag(m) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                // 框选细节仅在浮标启用时才有意义
                if settings.interactionMode.bubbleEnabled {
                    row("浮标触发") {
                        Picker("", selection: $settings.triggerMode) {
                            ForEach(TriggerMode.allCases) { t in Text(t.rawValue).tag(t) }
                        }
                        .labelsHidden()
                    }
                }
                Toggle("启用全局翻译", isOn: $settings.enabled)
                Toggle("AX 读不到时用 Cmd+C 兜底（短暂占用剪贴板）", isOn: $settings.useClipboardFallback)
                VStack(alignment: .leading, spacing: 4) {
                    if settings.interactionMode.hotkeyEnabled {
                        tip("• 快捷键：选中英文后按 ⌥ + ⇧ + T，直接弹出翻译框。")
                    }
                    if settings.interactionMode.bubbleEnabled {
                        tip("• 浮标：框选英文 → 选区右上方小圆点 → 点圆点翻译。")
                    }
                    tip("• 网页 / Electron App 里框选不灵时，用快捷键最稳。")
                }
            }
        }
    }

    private var speechCard: some View {
        cardBox(title: "朗读", icon: "speaker.wave.2.fill") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text("口音").frame(width: 50, alignment: .leading)
                    Picker("", selection: $settings.englishAccent) {
                        ForEach(EnglishAccent.allCases) { a in Text(a.rawValue).tag(a) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                HStack(spacing: 12) {
                    Text("语速").frame(width: 50, alignment: .leading)
                    Slider(value: $settings.speechRate, in: 0.15...0.55, step: 0.05)
                    Text(String(format: "%.2f", settings.speechRate))
                        .font(.system(size: 12, design: .monospaced))
                        .frame(width: 44, alignment: .trailing)
                }
                HStack(spacing: 8) {
                    Button("试听美式") { Speaker.shared.speak("Hello, this is the Kunkun translator.", lang: "en-US") }
                        .buttonStyle(.bordered)
                    Button("试听英式") { Speaker.shared.speak("Hello, this is the Kunkun translator.", lang: "en-GB") }
                        .buttonStyle(.bordered)
                    Button { Speaker.shared.stop() } label: { Image(systemName: "stop.fill") }
                        .buttonStyle(.bordered).help("停止朗读")
                }
                tip("• 系统会自动使用已下载的高质量语音包，建议在「系统设置 → 辅助功能 → 朗读内容」中下载增强语音。")
            }
        }
    }

    private var permissionCard: some View {
        cardBox(title: "辅助功能权限", icon: "shield.lefthalf.filled") {
            let ok = Permissions.isAccessibilityTrusted()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(ok ? .green : .orange)
                    Text(ok ? "已获得辅助功能权限" : "未获得辅助功能权限")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button("打开系统设置") { Permissions.openAccessibilitySettings() }
                        .buttonStyle(.bordered)
                }
                Text("授权后必须重启 App 才会生效。")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    private var logCard: some View {
        cardBox(title: "诊断 / 日志", icon: "doc.text.magnifyingglass") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button("刷新日志") { logSnapshot = Log.tail(lines: 80) }
                    Button("在 Finder 显示") {
                        NSWorkspace.shared.activateFileViewerSelecting([Log.fileURL])
                    }
                    Button("复制全部") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(Log.tail(lines: 1000), forType: .string)
                    }
                    Spacer()
                    Button("清空") { Log.clear(); logSnapshot = "" }
                        .foregroundStyle(.red)
                }
                DisclosureGroup("查看最近 80 行", isExpanded: $logRevealed) {
                    ScrollView {
                        Text(logSnapshot.isEmpty ? "(点上面「刷新日志」)" : logSnapshot)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                    .padding(8)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func row<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        HStack {
            Text(title).frame(width: 80, alignment: .leading)
            content()
        }
    }

    private func tip(_ text: String) -> some View {
        Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
    }

    private func hint(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle").font(.system(size: 11)).foregroundStyle(.blue)
            Text(text).font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func cardBox<C: View>(title: String, icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.purple, .blue],
                                                    startPoint: .leading, endPoint: .trailing))
                Text(title).font(.system(size: 14, weight: .bold))
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    private func testConnection() async {
        testStatus = .testing
        do {
            let r = try await LLMClient.shared.translate(text: "hello")
            if !r.translation.isEmpty {
                testStatus = .ok("通了：hello → \(r.translation)")
            } else {
                testStatus = .fail("返回空内容")
            }
        } catch {
            testStatus = .fail(error.localizedDescription)
        }
    }
}
