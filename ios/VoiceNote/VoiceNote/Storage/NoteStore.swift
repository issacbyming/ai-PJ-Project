import Foundation
import Combine
import SwiftUI // remove(atOffsets:) 定義在 SwiftUI
import VoiceNoteCore

@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []

    private let fileName = "notes.json"

    init() {
        notes = JSONFileStore.load([Note].self, from: fileName) ?? []
    }

    func note(id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    func add(_ note: Note) {
        notes.insert(note, at: 0)
        persist()
    }

    /// 只允許更新整理後的內容；原文不動。
    func updateProcessed(id: UUID, text: String, mode: ProcessingMode, changes: [TextChange]) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].processedText = text
        notes[index].mode = mode
        notes[index].changes = changes
        notes[index].updatedAt = Date()
        persist()
    }

    func delete(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
        persist()
    }

    func delete(id: UUID) {
        notes.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        JSONFileStore.save(notes, to: fileName)
    }
}
