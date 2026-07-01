import SwiftUI

struct SummaryView: View {
    @ObservedObject var store = VocabularyStore.shared
    @State private var aiSummary: String = ""
    @State private var generating = false
    @State private var errorMsg: String?

    private var todayCount: Int {
        let cal = Calendar.current
        return store.items.filter { cal.isDateInToday($0.createdAt) }.count
    }
    private var weekCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return store.items.filter { $0.createdAt >= cutoff }.count
    }
    private var monthCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return store.items.filter { $0.createdAt >= cutoff }.count
    }
    private var familiarityBuckets: [(Int, Int)] {
        (0...5).map { lv in (lv, store.items.filter { $0.familiarity == lv }.count) }
    }
    private var topSourceApps: [(String, Int)] {
        var dict: [String: Int] = [:]
        for it in store.items { if let a = it.sourceApp { dict[a, default: 0] += 1 } }
        return dict.sorted { $0.value > $1.value }.prefix(6).map { ($0.key, $0.value) }
    }
    private var streakDays: Int {
        // 连续学习天数（包含今天）
        let cal = Calendar.current
        let days = Set(store.items.map { cal.startOfDay(for: $0.createdAt) })
        var count = 0
        var d = cal.startOfDay(for: Date())
        while days.contains(d) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: d) else { break }
            d = prev
        }
        return count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                statRow
                if !familiarityBuckets.allSatisfy({ $0.1 == 0 }) {
                    familiarityCard
                }
                if !topSourceApps.isEmpty {
                    sourceAppsCard
                }
                aiCard
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
                        Color(red: 0.95, green: 0.45, blue: 0.55),
                        Color(red: 1.0, green: 0.65, blue: 0.35)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("学习总结").font(.system(size: 22, weight: .black))
                Text("看看困困翻译陪你学了多少 ✨")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var statRow: some View {
        HStack(spacing: 12) {
            statCard("今日新增", "\(todayCount)", icon: "sparkles", gradient: [.purple, .pink])
            statCard("近 7 天", "\(weekCount)", icon: "calendar", gradient: [.blue, .teal])
            statCard("近 30 天", "\(monthCount)", icon: "calendar.badge.clock", gradient: [.orange, .yellow])
            statCard("生词总数", "\(store.items.count)", icon: "book.closed.fill", gradient: [.indigo, .purple])
            statCard("连续学习", "\(streakDays) 天", icon: "flame.fill", gradient: [.red, .orange])
        }
    }

    private var familiarityCard: some View {
        cardBox(title: "熟悉度分布", icon: "star.leadinghalf.filled") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(familiarityBuckets, id: \.0) { lv, n in
                    HStack {
                        HStack(spacing: 1) {
                            ForEach(0..<6) { i in
                                Image(systemName: i <= lv ? "star.fill" : "star")
                                    .font(.system(size: 9))
                                    .foregroundStyle(i <= lv ? Color.yellow : Color.secondary.opacity(0.3))
                            }
                        }
                        .frame(width: 84, alignment: .leading)
                        GeometryReader { geo in
                            let total = max(1, store.items.count)
                            let w = CGFloat(n) / CGFloat(total) * geo.size.width
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.1))
                                    .frame(height: 14)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(colors: [.blue, .purple],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(2, w), height: 14)
                            }
                        }
                        .frame(height: 14)
                        Text("\(n)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var sourceAppsCard: some View {
        cardBox(title: "来源 App TOP", icon: "app.dashed") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(topSourceApps, id: \.0) { name, n in
                    HStack {
                        Image(systemName: "app.fill").foregroundStyle(.blue.opacity(0.7))
                        Text(name)
                        Spacer()
                        Text("\(n)").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var aiCard: some View {
        cardBox(title: "AI 学习建议", icon: "wand.and.stars") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("基于你最近收录的生词，让大模型写一份复习建议 + 短文练习。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        Task { await generate() }
                    } label: {
                        Label(generating ? "生成中…" : "用 AI 总结", systemImage: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(generating || store.items.isEmpty)
                }
                if let e = errorMsg {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        Text(e).font(.system(size: 12)).foregroundStyle(.red)
                    }
                }
                if !aiSummary.isEmpty {
                    ScrollView {
                        Text(aiSummary)
                            .font(.system(size: 13))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 320)
                    .padding(12)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(Color.cardBackgroundSoft)
                            RoundedRectangle(cornerRadius: 10).fill(LinearGradient(colors: [
                                Color.purple.opacity(0.12),
                                Color.pink.opacity(0.12)
                            ], startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.purple.opacity(0.28), lineWidth: 1)
                    )
                }
            }
        }
    }

    private func statCard(_ title: String, _ value: String, icon: String, gradient: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing)
                    )
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 24, weight: .black))
                .monospacedDigit()
                .foregroundStyle(
                    LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }

    @ViewBuilder
    private func cardBox<C: View>(title: String, icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.purple, .pink],
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

    private func generate() async {
        generating = true; errorMsg = nil
        defer { generating = false }
        let words = store.items.prefix(60).map(\.word)
        do { aiSummary = try await LLMClient.shared.summarize(words: Array(words)) }
        catch { errorMsg = error.localizedDescription }
    }
}
