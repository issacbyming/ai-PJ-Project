import Foundation
import Combine
import VoiceNoteCore

@MainActor
final class DictionaryStore: ObservableObject {
    @Published private(set) var entries: [DictionaryEntry] = []

    private let fileName = "dictionary.json"

    init() {
        if let saved = JSONFileStore.load([DictionaryEntry].self, from: fileName) {
            entries = saved
        } else {
            entries = Self.seed
            persist()
        }
    }

    /// 送給語音辨識的提示詞。
    var contextualTerms: [String] {
        DictionaryProcessor.contextualStrings(from: entries)
    }

    func upsert(_ entry: DictionaryEntry) {
        var cleaned = entry
        cleaned.term = entry.term.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned.aliases = entry.aliases
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleaned.term.isEmpty else { return }
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = cleaned
        } else {
            entries.append(cleaned)
        }
        persist()
    }

    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        JSONFileStore.save(entries, to: fileName)
    }

    private static let seed: [DictionaryEntry] = [
        DictionaryEntry(term: "Typeless", aliases: ["type less", "Type Less", "泰普勒斯"], note: "範例：英文產品名"),
        DictionaryEntry(term: "Claude", aliases: ["克勞德", "cloud", "Cloud"], note: "範例"),
        DictionaryEntry(term: "iOS", aliases: ["IOS", "i o s", "愛歐S"], note: "範例"),
    ]
}
