import Foundation

/// 把字典裡「常被誤辨識的寫法」換成正確寫法。純字串替換，不碰其他內容。
public enum DictionaryProcessor {
    public static func apply(_ text: String, entries: [DictionaryEntry]) -> (text: String, changes: [TextChange]) {
        var result = text
        var changes: [TextChange] = []

        // 長的 alias 先換，避免短的先吃掉一部分。
        let pairs: [(alias: String, term: String)] = entries
            .flatMap { entry in entry.aliases.map { (alias: $0.trimmingCharacters(in: .whitespaces), term: entry.term) } }
            .filter { !$0.alias.isEmpty && !$0.term.isEmpty && $0.alias != $0.term }
            .sorted { $0.alias.count > $1.alias.count }

        for pair in pairs {
            let hasLatin = pair.alias.unicodeScalars.contains { $0.isASCII && CharacterSet.letters.contains($0) }
            let options: String.CompareOptions = hasLatin ? [.caseInsensitive] : []
            let replaced = result.replacingOccurrences(of: pair.alias, with: pair.term, options: options)
            guard replaced != result else { continue }
            let count = max(1, result.components(separatedBy: pair.alias).count - 1)
            result = replaced
            changes.append(TextChange(kind: .dictionary, from: pair.alias, to: pair.term, count: count))
        }
        return (result, changes)
    }

    /// 給語音辨識用的提示詞：所有正確寫法。
    public static func contextualStrings(from entries: [DictionaryEntry]) -> [String] {
        Array(Set(entries.map { $0.term.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }))
    }
}
