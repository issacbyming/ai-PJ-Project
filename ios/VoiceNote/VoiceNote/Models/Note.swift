import Foundation
import VoiceNoteCore

struct Note: Codable, Identifiable, Hashable {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    /// 語音辨識出來的原文。建立之後永遠不會被修改。
    var rawText: String
    /// 整理後的文字。
    var processedText: String
    var mode: ProcessingMode
    var changes: [TextChange]

    init(id: UUID = UUID(),
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         rawText: String,
         processedText: String,
         mode: ProcessingMode,
         changes: [TextChange] = []) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.rawText = rawText
        self.processedText = processedText
        self.mode = mode
        self.changes = changes
    }

    var title: String {
        let source = processedText.isEmpty ? rawText : processedText
        let firstLine = source.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "（空白筆記）" }
        return trimmed.count > 24 ? String(trimmed.prefix(24)) + "…" : trimmed
    }
}
