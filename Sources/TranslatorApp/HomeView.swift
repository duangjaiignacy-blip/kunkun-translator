import SwiftUI
import AppKit

// MARK: - 困困翻译助手 · 总入口

struct HomeView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var vocab = VocabularyStore.shared
    @Binding var currentTab: MainTab

    @State private var hoverCard: String? = nil

    private var todayCount: Int {
        let cal = Calendar.current
        return vocab.items.filter { cal.isDateInToday($0.createdAt) }.count
    }
    private var weekCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return vocab.items.filter { $0.createdAt >= cutoff }.count
    }
    private var isReady: Bool { !settings.apiKey.isEmpty }
    private var axOK: Bool { Permissions.isAccessibilityTrusted() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                statusBanner
                quickTranslate
                featureGrid
                tipsFooter
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 28)
        }
        .frame(minWidth: 620, minHeight: 640)
    }

    // MARK: Hero — 渐变 banner

    // 主强调色：克制的靛紫，全局统一，不再花花绿绿
    private static let accent = Color(red: 0.42, green: 0.36, blue: 0.86)

    private var hero: some View {
        HStack(spacing: 18) {
            appLogo
            VStack(alignment: .leading, spacing: 7) {
                Text("困困翻译助手")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.primary)
                Text("选中任意 App 的英文 → 快捷键 / 浮标 → 译文 · 朗读 · 入生词本")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    chip(icon: "globe", text: "全局可用")
                    chip(icon: "command", text: "⌥⇧T 弹翻译框")
                    chip(icon: "lock.shield.fill", text: "钥匙串存 Key")
                }
                .padding(.top, 2)
            }
            Spacer()
            heroStats
        }
        .padding(20)
        .glassCard(cornerRadius: 20)
    }

    private var appLogo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [
                    Color(red: 0.55, green: 0.48, blue: 0.95),
                    Color(red: 0.42, green: 0.36, blue: 0.86)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 72, height: 72)
                .shadow(color: Self.accent.opacity(0.30), radius: 10, x: 0, y: 5)
            Text("困")
                .font(.system(size: 38, weight: .black))
                .foregroundStyle(.white)
        }
        .frame(width: 72, height: 72)
    }

    private func chip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
            Text(text).font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Self.accent)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(Self.accent.opacity(0.10)))
    }

    private var heroStats: some View {
        HStack(spacing: 18) {
            heroStatCol(value: "\(vocab.items.count)", label: "生词总数")
            Divider().frame(height: 34).opacity(0.4)
            heroStatCol(value: "\(todayCount)", label: "今日新增")
            Divider().frame(height: 34).opacity(0.4)
            heroStatCol(value: "\(weekCount)", label: "近 7 天")
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.5)))
    }

    private func heroStatCol(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 22, weight: .bold)).foregroundStyle(Self.accent).monospacedDigit()
            Text(label).font(.system(size: 10.5)).foregroundStyle(.secondary)
        }
    }

    // MARK: 状态横幅

    private var statusBanner: some View {
        HStack(spacing: 12) {
            statusPill(
                ok: isReady,
                title: isReady ? "API 已配置（\(settings.provider.rawValue)）" : "尚未配置 API Key",
                okIcon: "checkmark.seal.fill",
                badIcon: "exclamationmark.triangle.fill",
                action: { currentTab = .settings }
            )
            statusPill(
                ok: axOK,
                title: axOK ? "辅助功能已授权" : "未授权辅助功能",
                okIcon: "checkmark.shield.fill",
                badIcon: "lock.slash.fill",
                action: { Permissions.openAccessibilitySettings() }
            )
            statusPill(
                ok: settings.enabled,
                title: settings.enabled ? "全局翻译运行中" : "全局翻译已暂停",
                okIcon: "bolt.fill",
                badIcon: "pause.circle.fill",
                action: { settings.enabled.toggle() }
            )
        }
    }

    private func statusPill(ok: Bool, title: String, okIcon: String, badIcon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: ok ? okIcon : badIcon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ok ? Color.green : Color.orange)
                Text(title).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.cardBackground)
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(ok ? Color.green.opacity(0.25) : Color.orange.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: 快速翻译

    private var quickTranslate: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "bolt.horizontal.fill")
                    .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                Text("快速翻译")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text("或在任意 App 中框选英文")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            QuickTranslatePanel()
        }
        .padding(18)
        .glassCard(cornerRadius: 18)
    }

    // MARK: 功能卡片网格

    private var featureGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
        return LazyVGrid(columns: columns, spacing: 14) {
            featureCard(
                title: "生词本",
                subtitle: "管理 \(vocab.items.count) 个生词 · 评估熟悉度",
                icon: "books.vertical.fill",
                tint: Color(red: 0.36, green: 0.55, blue: 0.95),
                action: { currentTab = .vocabulary }
            )
            featureCard(
                title: "学习总结",
                subtitle: "今日 \(todayCount) · 近 7 天 \(weekCount) · AI 复盘",
                icon: "chart.line.uptrend.xyaxis",
                tint: Color(red: 0.90, green: 0.52, blue: 0.42),
                action: { currentTab = .summary }
            )
            featureCard(
                title: "设置",
                subtitle: "服务商：\(settings.provider.rawValue) · 模型：\(settings.model)",
                icon: "gearshape.2.fill",
                tint: Self.accent,
                action: { currentTab = .settings }
            )
            featureCard(
                title: "辅助功能权限",
                subtitle: axOK ? "已授权 · 一切就绪" : "去系统设置勾选 TranslatorApp",
                icon: axOK ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
                tint: axOK ? Color(red: 0.30, green: 0.68, blue: 0.55) : Color(red: 0.92, green: 0.58, blue: 0.30),
                action: { Permissions.openAccessibilitySettings() }
            )
        }
    }

    private func featureCard(title: String, subtitle: String, icon: String,
                             tint: Color, action: @escaping () -> Void) -> some View {
        let hovering = hoverCard == title
        return Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary)
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 16)
            .scaleEffect(hovering ? 1.012 : 1.0)
            .animation(.easeOut(duration: 0.15), value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hoverCard = $0 ? title : nil }
    }

    // MARK: 底部提示

    private var tipsFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                Text("使用小贴士").font(.system(size: 13, weight: .bold))
            }
            tip("选中英文后按 ⌥⇧T，直接弹出翻译框（推荐，网页 / Electron App 里最稳）。")
            tip("或开浮标模式：鼠标拖选英文，选区右上出现紫色小圆点，点它翻译。")
            tip("译卡里可朗读、加入生词本；两种方式在「设置 → 交互方式」里切换。")
            tip("生词本里可以打星标记熟悉度；学习总结里能让 AI 基于你的词表写复习建议。")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 14)
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").foregroundStyle(Self.accent)
            Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
}

// MARK: - 快速翻译面板（输入框 + 结果）

struct QuickTranslatePanel: View {
    @State private var input: String = ""
    @State private var loading = false
    @State private var result: TranslationResult?
    @State private var errorMsg: String?
    @State private var saved = false
    @State private var lastSubmitted: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            inputArea
            actionsRow
            if loading {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("翻译中…").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let err = errorMsg {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    Text(err).font(.system(size: 12)).foregroundStyle(.red)
                }
            } else if let r = result {
                resultCard(r)
            }
        }
    }

    private var inputArea: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            if input.isEmpty {
                Text("粘贴 / 输入要翻译的英文，按 ⌘↩ 翻译")
                    .foregroundStyle(.secondary.opacity(0.8))
                    .font(.system(size: 13))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $input)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .onSubmit { submit() }
        }
        .frame(minHeight: 80, maxHeight: 120)
    }

    private var actionsRow: some View {
        HStack(spacing: 8) {
            Button {
                if let s = NSPasteboard.general.string(forType: .string), !s.isEmpty {
                    input = s
                }
            } label: {
                Label("从剪贴板粘贴", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.bordered).controlSize(.small)

            Button {
                input = ""
                result = nil
                errorMsg = nil
                saved = false
            } label: {
                Label("清空", systemImage: "trash")
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(input.isEmpty && result == nil)

            Spacer()

            Button {
                submit()
            } label: {
                Label("翻译", systemImage: "wand.and.stars")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(loading || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func resultCard(_ r: TranslationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.translation)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [Color.purple, Color.blue],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .textSelection(.enabled)
                    if let p = r.pronunciation, !p.isEmpty {
                        Text(p).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    Speaker.shared.speak(lastSubmitted)
                } label: { Image(systemName: "speaker.wave.2.fill") }
                    .buttonStyle(.borderless).help("朗读原文")
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(r.translation, forType: .string)
                } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless).help("复制译文")
                Button {
                    let item = VocabularyItem(
                        word: lastSubmitted, context: nil, translation: r.translation,
                        pronunciation: r.pronunciation, partOfSpeech: r.partOfSpeech,
                        definitions: r.definitions, examples: r.examples, sourceApp: "困困翻译助手"
                    )
                    VocabularyStore.shared.add(item)
                    saved = true
                } label: {
                    Image(systemName: saved ? "star.fill" : "star")
                        .foregroundStyle(saved ? Color.yellow : .secondary)
                }
                .buttonStyle(.borderless).help("加入生词本")
                .disabled(saved)
            }
            if let pos = r.partOfSpeech, !pos.isEmpty {
                Text(pos).font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color.blue.opacity(0.15)))
            }
            if !r.definitions.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(r.definitions, id: \.self) { d in
                        Text("• \(d)").font(.system(size: 12))
                    }
                }
            }
            if !r.examples.isEmpty {
                Divider()
                Text("例句").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                ForEach(r.examples, id: \.self) { e in
                    Text(e).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.cardBackgroundSoft)
                RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [
                    Color.purple.opacity(0.12),
                    Color.blue.opacity(0.12)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.28), lineWidth: 1)
        )
    }

    private func submit() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        lastSubmitted = text
        loading = true
        errorMsg = nil
        result = nil
        saved = false
        Task {
            do {
                let r = try await LLMClient.shared.translate(text: text)
                await MainActor.run {
                    self.result = r
                    self.loading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMsg = error.localizedDescription
                    self.loading = false
                }
            }
        }
    }
}
