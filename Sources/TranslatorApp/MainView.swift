import SwiftUI

enum MainTab: Hashable, CaseIterable {
    case home, vocabulary, summary, settings

    var title: String {
        switch self {
        case .home: return "仪表板"
        case .vocabulary: return "生词本"
        case .summary: return "学习总结"
        case .settings: return "设置"
        }
    }
    var icon: String {
        switch self {
        case .home: return "square.grid.2x2"
        case .vocabulary: return "books.vertical.fill"
        case .summary: return "chart.line.uptrend.xyaxis"
        case .settings: return "gearshape"
        }
    }
}

struct MainView: View {
    @State private var tab: MainTab
    @ObservedObject private var settings = SettingsStore.shared

    init(initialTab: MainTab = .home) {
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        ZStack {
            AuroraBackground()
            HStack(spacing: 0) {
                sidebar
                Divider().opacity(0.15)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 900, minHeight: 640)
        .preferredColorScheme(.light)   // 全 App 锁定浅色，不跟随系统深色
    }

    // MARK: 左侧导航

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 品牌区
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [
                        Color(red: 0.99, green: 0.42, blue: 0.78),
                        Color(red: 0.55, green: 0.30, blue: 0.98)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                    .overlay(Image(systemName: "character.bubble.fill")
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 1) {
                    Text("困困翻译").font(.system(size: 16, weight: .bold))
                    Text("Translator").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14).padding(.top, 20).padding(.bottom, 18)

            // 导航项
            ForEach(MainTab.allCases, id: \.self) { item in
                navItem(item)
            }

            Spacer()

            // 底部：服务开关
            Toggle(isOn: $settings.enabled) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.horizontal.fill").font(.system(size: 12))
                    Text("全局翻译").font(.system(size: 13, weight: .medium))
                }
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .glassCard(cornerRadius: 12)
            .padding(.horizontal, 10).padding(.bottom, 16)
        }
        .frame(width: 210)
        .background(Color.white.opacity(0.45))
        .background(.ultraThinMaterial)
    }

    private func navItem(_ item: MainTab) -> some View {
        let selected = tab == item
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { tab = item }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                Text(item.title).font(.system(size: 13.5, weight: selected ? .semibold : .regular))
                Spacer()
            }
            .foregroundStyle(selected ? Color.accentColor : Color.primary.opacity(0.75))
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.14) : .clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
    }

    // MARK: 右侧内容

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .home:       HomeView(currentTab: $tab)
        case .vocabulary: VocabularyView()
        case .summary:    SummaryView()
        case .settings:   SettingsView()
        }
    }
}
