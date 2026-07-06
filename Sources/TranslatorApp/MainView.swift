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
    @State private var tab: MainTab

    init(initialTab: MainTab = .home) {
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        ZStack {
            AppShowcaseBackground()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 920, minHeight: 700)
        .preferredColorScheme(.light)
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
        VStack(spacing: 16) {
            compactNavigation
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                )
        }
        .padding(24)
    }

    private var compactNavigation: some View {
        HStack(spacing: 8) {
            ForEach(MainTab.allCases, id: \.self) { item in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { tab = item }
                } label: {
                    Label(item.title, systemImage: item.icon)
                        .font(.system(size: 13, weight: tab == item ? .semibold : .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(tab == item ? .white : Color.black.opacity(0.72))
                        .background(
                            Capsule(style: .continuous)
                                .fill(tab == item ? Color.black.opacity(0.82) : Color.white.opacity(0.52))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}
