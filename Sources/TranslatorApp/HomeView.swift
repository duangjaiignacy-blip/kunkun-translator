import SwiftUI
import AppKit

// MARK: - PinsgoInspiredHome

struct HomeView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var vocab = VocabularyStore.shared
    @Binding var currentTab: MainTab

    @State private var input: String = "Kunkun Translator is a lightweight translation tool powered by AI and always residing in the menu bar."
    @State private var loading = false
    @State private var result: TranslationResult?
    @State private var errorMsg: String?
    @State private var saved = false
    @State private var lastSubmitted: String = ""

    private var todayCount: Int {
        vocab.items.filter { Calendar.current.isDateInToday($0.createdAt) }.count
    }

    private var isReady: Bool { !settings.apiKey.isEmpty }
    private var axOK: Bool { Permissions.isAccessibilityTrusted() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                showcase
                brandRow
            }
            .padding(.horizontal, 42)
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
        .frame(minWidth: 760, minHeight: 660)
    }

    private var showcase: some View {
        ZStack {
            meshBackdrop
            translationWorkbench
                .padding(.horizontal, 78)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 500)
        .clipShape(RoundedRectangle(cornerRadius: 54, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 54, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: Color(red: 0.20, green: 0.10, blue: 0.36).opacity(0.24), radius: 34, x: 0, y: 24)
    }

    private var meshBackdrop: some View {
        ZStack {
            LinearGradient(colors: [
                Color(red: 0.70, green: 0.78, blue: 0.90),
                Color(red: 0.92, green: 0.78, blue: 0.86)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    meshBlob(Color(red: 0.05, green: 0.14, blue: 0.78), x: w * 0.12, y: h * 0.47, r: max(w, h) * 0.42)
                    meshBlob(Color(red: 1.00, green: 0.25, blue: 0.16), x: w * 0.45, y: h * 0.17, r: max(w, h) * 0.40)
                    meshBlob(Color(red: 0.86, green: 0.10, blue: 0.70), x: w * 0.82, y: h * 0.34, r: max(w, h) * 0.36)
                    meshBlob(Color(red: 0.14, green: 0.24, blue: 0.98), x: w * 0.78, y: h * 0.88, r: max(w, h) * 0.42)
                    meshBlob(Color(red: 0.93, green: 0.14, blue: 0.22), x: w * 0.28, y: h * 0.93, r: max(w, h) * 0.32)
                    meshBlob(Color(red: 0.43, green: 0.87, blue: 0.88), x: w * 0.10, y: h * 0.70, r: max(w, h) * 0.20)
                }
                .blur(radius: 54)
                .saturation(1.2)
            }
        }
    }

    private func meshBlob(_ color: Color, x: CGFloat, y: CGFloat, r: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color, color.opacity(0)], center: .center, startRadius: 0, endRadius: r))
            .frame(width: r * 2, height: r * 2)
            .position(x: x, y: y)
    }

    private var translationWorkbench: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                LanguagePane(
                    title: "Auto",
                    text: $input,
                    placeholder: "Paste English text...",
                    editable: true
                )

                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 1)

                LanguagePane(
                    title: "To \(settings.targetLanguage)",
                    text: .constant(outputText),
                    placeholder: "Translation appears here",
                    editable: false
                )
            }
            .frame(height: 318)
            .background(Color.white.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.13), lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                HStack {
                    languageBadge("Auto")
                    Spacer()
                    languageBadge("To \(settings.targetLanguage)")
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 18)
            }

            workbenchFooter
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(red: 0.045, green: 0.047, blue: 0.060).opacity(0.88))
        )
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.32), radius: 28, x: 0, y: 20)
    }

    private var outputText: String {
        if loading { return "Translating..." }
        if let errorMsg { return errorMsg }
        if let result { return result.translation }
        return "困困翻译是一款由 AI 驱动、常驻菜单栏的轻量翻译工具。"
    }

    private func languageBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(Color.black.opacity(0.88)))
    }

    private var workbenchFooter: some View {
        HStack(spacing: 16) {
            MiniAppIcon()
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("困困 translation")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Text("Mac-style menu bar translation")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
            }

            Spacer()

            footerStatus
            footerIcon("books.vertical.fill", "生词本") { currentTab = .vocabulary }
            footerIcon("chart.line.uptrend.xyaxis", "学习总结") { currentTab = .summary }
            footerIcon("gearshape.fill", "设置") { currentTab = .settings }
            footerIcon(settings.enabled ? "pause.fill" : "play.fill", settings.enabled ? "暂停全局翻译" : "启用全局翻译") {
                settings.enabled.toggle()
            }
            footerIcon("wand.and.stars", "翻译") { submit() }
                .disabled(loading || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var footerStatus: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isReady && axOK ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(isReady && axOK ? "Ready" : "Setup")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.08)))
        .help(isReady ? "API 已配置" : "去设置里配置 API Key")
        .onTapGesture { if !isReady { currentTab = .settings } }
    }

    private func footerIcon(_ systemName: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.66))
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.white.opacity(0.001)))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var brandRow: some View {
        HStack(alignment: .center, spacing: 22) {
            MiniAppIcon()
                .frame(width: 96, height: 96)
                .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 10)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("困困 translate")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .italic()
                        .foregroundStyle(Color.black.opacity(0.92))
                    Text("1.0.1")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .italic()
                        .foregroundStyle(Color.black.opacity(0.84))
                }
                HStack(spacing: 10) {
                    brandPill(icon: "sparkles", text: "AI translation")
                    brandPill(icon: "command", text: "⌥⇧T")
                    brandPill(icon: "menubar.rectangle", text: "Menu bar")
                    brandPill(icon: "book.closed.fill", text: "\(vocab.items.count) words")
                    brandPill(icon: "calendar", text: "\(todayCount) today")
                }
            }
            Spacer()
        }
        .padding(.horizontal, 8)
    }

    private func brandPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Color.black.opacity(0.78))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.62))
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
                let translated = try await LLMClient.shared.translate(text: text)
                await MainActor.run {
                    result = translated
                    loading = false
                }
            } catch {
                await MainActor.run {
                    errorMsg = error.localizedDescription
                    loading = false
                }
            }
        }
    }
}

struct LanguagePane: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let editable: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if editable {
                TextEditor(text: $text)
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.90))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 60)
                    .background(Color.clear)
            } else {
                ScrollView {
                    Text(text)
                        .font(.system(size: 20, weight: .regular, design: .rounded))
                        .lineSpacing(7)
                        .foregroundStyle(textColor)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22)
                        .padding(.top, 23)
                        .padding(.bottom, 68)
                }
            }

            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.32))
                    .padding(.horizontal, 26)
                    .padding(.top, 24)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [
                Color.white.opacity(editable ? 0.065 : 0.035),
                Color(red: 0.04, green: 0.08, blue: 0.10).opacity(0.20)
            ], startPoint: .top, endPoint: .bottom)
        )
    }

    private var textColor: Color {
        if text == "Translating..." { return .white.opacity(0.50) }
        if text == "困困翻译是一款由 AI 驱动、常驻菜单栏的轻量翻译工具。" { return .white.opacity(0.82) }
        return .white.opacity(0.90)
    }
}

struct MiniAppIcon: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.19, style: .continuous)
                    .fill(Color.white)
                RoundedRectangle(cornerRadius: s * 0.16, style: .continuous)
                    .fill(LinearGradient(colors: [
                        Color(red: 0.04, green: 0.05, blue: 0.08),
                        Color(red: 0.08, green: 0.09, blue: 0.14)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .padding(s * 0.06)

                ZStack {
                    speechBubble(colorA: Color(red: 0.22, green: 0.34, blue: 0.95), colorB: Color(red: 0.38, green: 0.54, blue: 0.98), size: s)
                        .frame(width: s * 0.48, height: s * 0.34)
                        .offset(x: -s * 0.12, y: s * 0.07)
                    Text("A")
                        .font(.system(size: s * 0.20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .offset(x: -s * 0.17, y: s * 0.01)
                    speechBubble(colorA: Color(red: 0.24, green: 0.60, blue: 0.95), colorB: Color(red: 0.36, green: 0.72, blue: 0.98), size: s)
                        .frame(width: s * 0.49, height: s * 0.35)
                        .offset(x: s * 0.12, y: -s * 0.06)
                    Image(systemName: "sparkles")
                        .font(.system(size: s * 0.17, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: s * 0.09, y: -s * 0.08)
                }
            }
        }
    }

    private func speechBubble(colorA: Color, colorB: Color, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
            .fill(LinearGradient(colors: [colorA, colorB], startPoint: .bottomLeading, endPoint: .topTrailing))
            .overlay(alignment: .bottom) {
                Triangle()
                    .fill(colorA)
                    .frame(width: size * 0.11, height: size * 0.11)
                    .offset(x: -size * 0.07, y: size * 0.06)
            }
    }
}

struct AppShowcaseBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.84, green: 0.89, blue: 0.98).ignoresSafeArea()
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    Circle().fill(Color(red: 0.98, green: 0.56, blue: 0.54).opacity(0.30)).frame(width: w * 0.70).position(x: w * 0.10, y: h * 0.98)
                    Circle().fill(Color(red: 0.42, green: 0.50, blue: 1.00).opacity(0.28)).frame(width: w * 0.58).position(x: w * 0.94, y: h * 0.82)
                    Circle().fill(Color.white.opacity(0.24)).frame(width: w * 0.45).position(x: w * 0.52, y: h * 0.06)
                }
                .blur(radius: 62)
            }
            .ignoresSafeArea()
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
