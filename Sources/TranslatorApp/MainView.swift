import SwiftUI

enum MainTab: Hashable, CaseIterable {
    case home, vocabulary, summary, settings

    var title: String {
        switch self {
        case .home: return "首页"
        case .vocabulary: return "生词本"
        case .summary: return "学习总结"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .home: return "sparkles"
        case .vocabulary: return "books.vertical.fill"
        case .summary: return "chart.line.uptrend.xyaxis"
        case .settings: return "gearshape"
        }
    }
}

struct MainView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @State private var tab: MainTab

    init(initialTab: MainTab = .home) {
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        ZStack {
            AppStageBackground()
                .allowsHitTesting(false)
            VStack(spacing: 18) {
                topBar
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
            .padding(.top, 36)
            .zIndex(1)
        }
        .frame(minWidth: 920, minHeight: 700)
        .preferredColorScheme(settings.themeMode.colorScheme)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .home:
            HomeView(currentTab: $tab)
        case .vocabulary:
            secondaryShell { VocabularyView() }
        case .summary:
            secondaryShell { SummaryView() }
        case .settings:
            secondaryShell { SettingsView() }
        }
    }

    private func secondaryShell<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(settings.themeMode == .dark ? Color.white.opacity(0.045) : Color.white.opacity(0.64))
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(settings.themeMode == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.74), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(settings.themeMode == .dark ? 0.34 : 0.10), radius: 26, x: 0, y: 18)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            compactNavigation
            Spacer()
            themeToggle
        }
        .zIndex(10)
    }

    private var compactNavigation: some View {
        HStack(spacing: 6) {
            ForEach(MainTab.allCases, id: \.self) { item in
                navButton(item)
            }
        }
    }

    private func navButton(_ item: MainTab) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { tab = item }
        } label: {
            Label(item.title, systemImage: item.icon)
                .font(.system(size: 13, weight: tab == item ? .bold : .semibold, design: .rounded))
                .foregroundStyle(tab == item ? activeNavText : inactiveNavText)
                .frame(width: navButtonHitArea(for: item), height: 42)
                .background(
                    Capsule(style: .continuous)
                        .fill(tab == item ? activeNavFill : inactiveNavFill)
                )
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .zIndex(10)
    }

    private func navButtonHitArea(for item: MainTab) -> CGFloat {
        switch item {
        case .home, .settings: return 92
        case .vocabulary: return 112
        case .summary: return 128
        }
    }

    private var themeToggle: some View {
        Picker("", selection: $settings.themeMode) {
            ForEach(AppThemeMode.allCases) { mode in
                Label(mode.rawValue, systemImage: mode == .dark ? "moon.fill" : "sun.max.fill").tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(width: 142)
        .help("切换浅色 / 深色模式")
    }

    private var activeNavText: Color {
        settings.themeMode == .dark ? Color.black.opacity(0.88) : .white
    }

    private var inactiveNavText: Color {
        settings.themeMode == .dark ? Color.white.opacity(0.70) : Color.black.opacity(0.68)
    }

    private var activeNavFill: Color {
        settings.themeMode == .dark ? Color(red: 0.76, green: 0.74, blue: 1.00) : Color.black.opacity(0.84)
    }

    private var inactiveNavFill: Color {
        settings.themeMode == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.58)
    }
}

struct AppStageBackground: View {
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        ZStack {
            base
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                Text("TRANSLATE")
                    .font(.system(size: max(118, w * 0.18), weight: .black, design: .rounded))
                    .foregroundStyle(settings.themeMode == .dark ? Color(red: 0.60, green: 0.58, blue: 0.98).opacity(0.30) : Color.black.opacity(0.045))
                    .position(x: w * 0.50, y: h * 0.08)
                    .allowsHitTesting(false)
                Text("bilingual")
                    .font(.system(size: max(90, w * 0.14), weight: .black, design: .rounded))
                    .foregroundStyle(settings.themeMode == .dark ? Color.white.opacity(0.055) : Color.black.opacity(0.035))
                    .position(x: w * 0.52, y: h * 0.93)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var base: some View {
        if settings.themeMode == .dark {
            ZStack {
                Color(red: 0.015, green: 0.016, blue: 0.020)
                RadialGradient(colors: [
                    Color(red: 0.58, green: 0.55, blue: 1.00).opacity(0.24),
                    Color.clear
                ], center: .top, startRadius: 40, endRadius: 520)
                RadialGradient(colors: [
                    Color(red: 0.95, green: 0.48, blue: 0.44).opacity(0.18),
                    Color.clear
                ], center: .bottomTrailing, startRadius: 30, endRadius: 580)
            }
        } else {
            ZStack {
                LinearGradient(colors: [
                    Color(red: 0.96, green: 0.96, blue: 0.98),
                    Color(red: 0.88, green: 0.90, blue: 0.96)
                ], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [
                    Color(red: 0.72, green: 0.70, blue: 1.00).opacity(0.28),
                    Color.clear
                ], center: .topLeading, startRadius: 20, endRadius: 520)
                RadialGradient(colors: [
                    Color(red: 1.00, green: 0.72, blue: 0.67).opacity(0.32),
                    Color.clear
                ], center: .bottomTrailing, startRadius: 30, endRadius: 560)
            }
        }
    }
}
