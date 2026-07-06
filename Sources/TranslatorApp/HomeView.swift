import SwiftUI
import AppKit

// MARK: - StarlineInspiredHome

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
    private var isDark: Bool { settings.themeMode == .dark }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            showcase
            brandRow
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
        .frame(minWidth: 760, minHeight: 620)
    }

    private var showcase: some View {
        ZStack {
            stageBackdrop
            oversizedStageText
            decorativeFloatingMetricCard(alignment: .topLeading, title: "today", value: "\(todayCount)", icon: "sparkles")
                .offset(x: -328, y: -172)
            decorativeFloatingMetricCard(alignment: .bottomTrailing, title: "saved", value: "\(vocab.items.count)", icon: "book.closed.fill")
                .offset(x: 328, y: 174)
            translationWorkbench
                .frame(maxWidth: 620)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 470)
    }

    private var stageBackdrop: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .fill(isDark ? Color.black.opacity(0.20) : Color.white.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 42, style: .continuous)
                        .stroke(isDark ? Color.white.opacity(0.07) : Color.white.opacity(0.48), lineWidth: 1)
                )

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    meshBlob(Color(red: 0.62, green: 0.58, blue: 1.00).opacity(isDark ? 0.28 : 0.22), x: w * 0.45, y: h * 0.12, r: max(w, h) * 0.34)
                    meshBlob(Color(red: 1.00, green: 0.66, blue: 0.60).opacity(isDark ? 0.20 : 0.30), x: w * 0.70, y: h * 0.80, r: max(w, h) * 0.28)
                    meshBlob(Color(red: 0.72, green: 0.82, blue: 1.00).opacity(isDark ? 0.10 : 0.28), x: w * 0.16, y: h * 0.72, r: max(w, h) * 0.30)
                }
                .blur(radius: 46)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 42, style: .continuous))
    }

    private func meshBlob(_ color: Color, x: CGFloat, y: CGFloat, r: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color, color.opacity(0)], center: .center, startRadius: 0, endRadius: r))
            .frame(width: r * 2, height: r * 2)
            .position(x: x, y: y)
    }

    private var oversizedStageText: some View {
        VStack(spacing: 182) {
            Text("TRANSLATE")
                .font(.system(size: 100, weight: .black, design: .rounded))
                .foregroundStyle(isDark ? Color(red: 0.62, green: 0.60, blue: 1.00).opacity(0.23) : Color.black.opacity(0.045))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text("bilingual")
                .font(.system(size: 78, weight: .black, design: .rounded))
                .foregroundStyle(isDark ? Color.white.opacity(0.018) : Color.black.opacity(0.030))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .allowsHitTesting(false)
    }

    private func decorativeFloatingMetricCard(alignment: Alignment, title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 30, height: 30)
                .foregroundStyle(isDark ? Color.black.opacity(0.86) : .white)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(isDark ? Color(red: 0.77, green: 0.74, blue: 1.00) : Color.black.opacity(0.82)))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(isDark ? Color.white.opacity(0.48) : Color.black.opacity(0.48))
                Text(value)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isDark ? Color.white.opacity(0.88) : Color.black.opacity(0.86))
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isDark ? Color.white.opacity(0.055) : Color.white.opacity(0.68))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isDark ? Color.white.opacity(0.10) : Color.white.opacity(0.78), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isDark ? 0.28 : 0.10), radius: 18, x: 0, y: 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .allowsHitTesting(false)
    }

    private var translationWorkbench: some View {
        themeAwareWorkbench
    }

    private var themeAwareWorkbench: some View {
        VStack(spacing: 0) {
            workbenchPanes
            workbenchFooter
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(isDark ? Color(red: 0.055, green: 0.055, blue: 0.070).opacity(0.86) : Color.white.opacity(0.74))
        )
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(isDark ? Color.white.opacity(0.16) : Color.white.opacity(0.82), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(isDark ? 0.42 : 0.16), radius: 30, x: 0, y: 22)
    }

    private var workbenchPanes: some View {
        HStack(spacing: 0) {
            LanguagePane(
                title: "Source Auto",
                text: $input,
                placeholder: "输入中文或英文...",
                editable: true
            )

            Rectangle()
                .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.07))
                .frame(width: 1)

            LanguagePane(
                title: "Auto bilingual",
                text: .constant(outputText),
                placeholder: "翻译结果会显示在这里",
                editable: false
            )
        }
            .frame(height: 306)
        .background(isDark ? Color.white.opacity(0.035) : Color.white.opacity(0.40))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.06), lineWidth: 1)
        )
        .overlay(alignment: .bottom) {
            HStack {
                languageBadge("Auto")
                Spacer()
                languageBadge("中 ⇄ EN")
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 18)
        }
    }

    private var outputText: String {
        if loading { return "Translating..." }
        if let errorMsg { return errorMsg }
        if let result { return result.translation }
        return "选中英文默认译中文，选中中文默认译英文。"
    }

    private func languageBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(isDark ? .white : Color.black.opacity(0.84))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(isDark ? Color.black.opacity(0.88) : Color.white.opacity(0.82)))
    }

    private var workbenchFooter: some View {
        HStack(spacing: 16) {
            MiniAppIcon()
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("困困 translation")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(isDark ? Color.white.opacity(0.92) : Color.black.opacity(0.86))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isDark ? Color.white.opacity(0.55) : Color.black.opacity(0.42))
                }
                Text("Auto bilingual menu bar translation")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(isDark ? Color.white.opacity(0.42) : Color.black.opacity(0.48))
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
                .foregroundStyle(isDark ? Color.white.opacity(0.58) : Color.black.opacity(0.58))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule(style: .continuous).fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)))
        .help(isReady ? "API 已配置" : "去设置里配置 API Key")
        .onTapGesture { if !isReady { currentTab = .settings } }
    }

    private func footerIcon(_ systemName: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isDark ? Color.white.opacity(0.66) : Color.black.opacity(0.60))
                .frame(width: 30, height: 30)
                .background(Circle().fill(isDark ? Color.white.opacity(0.001) : Color.black.opacity(0.001)))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var brandRow: some View {
        HStack(alignment: .center, spacing: 22) {
            MiniAppIcon()
                .frame(width: 70, height: 70)
                .shadow(color: Color.black.opacity(isDark ? 0.36 : 0.16), radius: 14, x: 0, y: 10)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("困困 translate")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .italic()
                        .foregroundStyle(isDark ? Color.white.opacity(0.92) : Color.black.opacity(0.92))
                    Text("1.0.1")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .italic()
                        .foregroundStyle(isDark ? Color.white.opacity(0.72) : Color.black.opacity(0.78))
                }
                HStack(spacing: 10) {
                    brandPill(icon: "sparkles", text: "Auto bilingual")
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
        .foregroundStyle(isDark ? Color.white.opacity(0.90) : Color.black.opacity(0.78))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isDark ? darkBrandPillFill : Color.white.opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(isDark ? darkBrandPillStroke : Color.white.opacity(0.58), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isDark ? 0.18 : 0.04), radius: 8, x: 0, y: 4)
    }

    private var darkBrandPillFill: Color {
        Color(red: 0.115, green: 0.115, blue: 0.145).opacity(0.94)
    }

    private var darkBrandPillStroke: Color {
        Color.white.opacity(0.14)
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
    @ObservedObject private var settings = SettingsStore.shared
    let title: String
    @Binding var text: String
    let placeholder: String
    let editable: Bool
    private var isDark: Bool { settings.themeMode == .dark }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(isDark ? Color.white.opacity(0.38) : Color.black.opacity(0.42))
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .allowsHitTesting(false)

            if editable {
                TextEditor(text: $text)
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .foregroundStyle(isDark ? Color.white.opacity(0.90) : Color.black.opacity(0.86))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 22)
                    .padding(.top, 36)
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
                        .padding(.top, 42)
                        .padding(.bottom, 68)
                }
            }

            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .foregroundStyle(isDark ? Color.white.opacity(0.32) : Color.black.opacity(0.30))
                    .padding(.horizontal, 26)
                    .padding(.top, 42)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [
                isDark ? Color.white.opacity(editable ? 0.065 : 0.035) : Color.white.opacity(editable ? 0.48 : 0.28),
                isDark ? Color(red: 0.04, green: 0.08, blue: 0.10).opacity(0.20) : Color(red: 0.88, green: 0.90, blue: 0.96).opacity(0.28)
            ], startPoint: .top, endPoint: .bottom)
        )
    }

    private var textColor: Color {
        if text == "Translating..." { return isDark ? .white.opacity(0.50) : Color.black.opacity(0.46) }
        if text == "选中英文默认译中文，选中中文默认译英文。" { return isDark ? .white.opacity(0.82) : Color.black.opacity(0.64) }
        return isDark ? .white.opacity(0.90) : Color.black.opacity(0.86)
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
