import Foundation
import Combine

struct VocabularyItem: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var word: String
    var context: String?
    var translation: String
    var pronunciation: String?
    var partOfSpeech: String?
    var definitions: [String]
    var examples: [String]
    var sourceApp: String?
    var createdAt: Date = Date()
    var familiarity: Int = 0
    var reviewCount: Int = 0
}

final class VocabularyStore: ObservableObject {
    static let shared = VocabularyStore()

    @Published private(set) var items: [VocabularyItem] = []

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TranslatorApp", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("vocabulary.json")
    }

    private init() { load() }

    func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? decoder.decode([VocabularyItem].self, from: data) else { return }
        items = list
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(items) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func add(_ item: VocabularyItem) {
        let key = item.word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        if let idx = items.firstIndex(where: { $0.word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == key }) {
            items[idx].reviewCount += 1
            if items[idx].context == nil { items[idx].context = item.context }
        } else {
            items.insert(item, at: 0)
        }
        save()
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func updateFamiliarity(_ id: UUID, level: Int) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].familiarity = max(0, min(5, level))
        save()
    }

    func clearAll() {
        items = []
        save()
    }
}
