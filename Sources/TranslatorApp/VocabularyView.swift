import SwiftUI

struct VocabularyView: View {
    @ObservedObject var store = VocabularyStore.shared
    @State private var query = ""
    @State private var selectedID: UUID?
    @State private var sortMode: SortMode = .newest

    enum SortMode: String, CaseIterable, Identifiable {
        case newest = "最新加入"
        case familiarityAsc = "最不熟"
        case familiarityDesc = "最熟悉"
        case mostReviewed = "查看最多"
        var id: String { rawValue }
    }

    private var filtered: [VocabularyItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var list = store.items
        if !q.isEmpty {
            list = list.filter {
                $0.word.lowercased().contains(q) || $0.translation.contains(q)
            }
        }
        switch sortMode {
        case .newest: list.sort { $0.createdAt > $1.createdAt }
        case .familiarityAsc: list.sort { $0.familiarity < $1.familiarity }
        case .familiarityDesc: list.sort { $0.familiarity > $1.familiarity }
        case .mostReviewed: list.sort { $0.reviewCount > $1.reviewCount }
        }
        return list
    }

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
            HSplitView {
                listColumn
                detailColumn
            }
        }
        .frame(minWidth: 640, minHeight: 480)
    }

    private var sectionHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [
                        Color(red: 0.30, green: 0.55, blue: 1.0),
                        Color(red: 0.50, green: 0.85, blue: 1.0)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("生词本").font(.system(size: 18, weight: .bold))
                Text("共 \(store.items.count) 个生词 · 点击单词查看详情").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
    }

    private var listColumn: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索单词或翻译", text: $query)
                    .textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless).foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 10).padding(.bottom, 6)

            HStack {
                Picker("排序", selection: $sortMode) {
                    ForEach(SortMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.bottom, 4)

            Divider()
            List(filtered, selection: $selectedID) { item in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.word).font(.system(size: 13, weight: .semibold))
                        Text(item.translation).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    famStars(item.familiarity)
                }
                .padding(.vertical, 2)
                .tag(item.id)
            }
            .listStyle(.inset)
            Divider()
            HStack {
                Text("共 \(filtered.count) 条").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive) {
                    if let id = selectedID { store.remove(id); selectedID = nil }
                } label: { Image(systemName: "trash") }
                    .disabled(selectedID == nil)
                    .help("删除选中")
            }
            .padding(8)
        }
        .frame(minWidth: 260, idealWidth: 300)
    }

    private func famStars(_ n: Int) -> some View {
        HStack(spacing: 1) {
            ForEach(0..<6) { i in
                Image(systemName: i <= n ? "star.fill" : "star")
                    .font(.system(size: 8))
                    .foregroundStyle(i <= n ? Color.yellow : Color.secondary.opacity(0.3))
            }
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let id = selectedID, let item = store.items.first(where: { $0.id == id }) {
            VocabularyDetail(item: item)
        } else {
            VStack(spacing: 12) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.15)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 88, height: 88)
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(
                            LinearGradient(colors: [.blue, .purple],
                                           startPoint: .top, endPoint: .bottom)
                        )
                }
                Text("选择左侧条目查看详情")
                    .foregroundStyle(.secondary).font(.system(size: 13))
                Text("或在任意 App 框选英文，从译卡里⭐加入生词本")
                    .foregroundStyle(.secondary).font(.system(size: 11))
                Spacer()
            }
            .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct VocabularyDetail: View {
    let item: VocabularyItem
    @ObservedObject var store = VocabularyStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // 标题区
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.word).font(.system(size: 28, weight: .black)).textSelection(.enabled)
                        if let p = item.pronunciation, !p.isEmpty {
                            Text(p).font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { Speaker.shared.speak(item.word) } label: {
                            Image(systemName: "speaker.wave.2.fill").font(.system(size: 16))
                        }.buttonStyle(.borderless).help("朗读")
                    }
                    Text(item.translation)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                        )
                        .textSelection(.enabled)
                    if let pos = item.partOfSpeech, !pos.isEmpty {
                        Text(pos).font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color.blue.opacity(0.18)))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.cardBackground)
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                )

                if !item.definitions.isEmpty {
                    sectionCard(title: "释义", icon: "text.alignleft") {
                        ForEach(item.definitions, id: \.self) { d in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•").foregroundStyle(.purple)
                                Text(d).textSelection(.enabled)
                            }
                        }
                    }
                }
                if !item.examples.isEmpty {
                    sectionCard(title: "例句", icon: "quote.bubble") {
                        ForEach(item.examples, id: \.self) { e in
                            Text(e).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                                .padding(.vertical, 2)
                        }
                    }
                }

                sectionCard(title: "学习", icon: "graduationcap.fill") {
                    HStack {
                        Text("熟悉度")
                        ForEach(0..<6) { lv in
                            Image(systemName: lv <= item.familiarity ? "star.fill" : "star")
                                .foregroundStyle(lv <= item.familiarity ? Color.yellow : Color.secondary.opacity(0.4))
                                .onTapGesture { store.updateFamiliarity(item.id, level: lv) }
                        }
                        Spacer()
                        Label("\(item.reviewCount) 次", systemImage: "eye")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                HStack {
                    if let app = item.sourceApp { Label("来自 \(app)", systemImage: "app.dashed").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func sectionCard<C: View>(title: String, icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.purple)
                Text(title).font(.system(size: 13, weight: .bold))
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }
}
