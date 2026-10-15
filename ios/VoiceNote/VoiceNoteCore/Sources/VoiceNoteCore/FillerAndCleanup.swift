import Foundation

/// 語助詞（預設關閉）。只刪「獨立出現」的那種，不會動到句子裡的字。
public enum FillerProcessor {
    private static let regex = NSRegularExpression(#"(?:^|(?<=[，,。！？；\s]))(?:嗯+|呃+|欸|那個|就是說|然後呢)(?=[，,。！？；\s]|$)[，,]?"#)

    public static func apply(_ text: String) -> (text: String, changes: [TextChange]) {
        let count = regex.allMatches(in: text).count
        guard count > 0 else { return (text, []) }
        let result = regex.replaceAll(in: text, with: "")
        return (result, [TextChange(kind: .filler, from: "語助詞", to: "", count: count)])
    }
}

/// 收尾：合併重複標點、去掉多餘空白。
public enum TextCleanup {
    private static let rules: [(NSRegularExpression, String)] = [
        (NSRegularExpression(#"[，,]+([。！？；：、])"#), "$1"),
        (NSRegularExpression(#"([。！？；：、])[，,]+"#), "$1"),
        (NSRegularExpression(#"[，,]{2,}"#), "，"),
        (NSRegularExpression(#"[ \t]*([。！？；：、，])[ \t]*"#), "$1"),
        (NSRegularExpression(#"(?m)^[，,、]+"#), ""),
        (NSRegularExpression(#"(?m)[ \t]+$"#), ""),
        (NSRegularExpression(#"(?m)^[ \t]+"#), ""),
        (NSRegularExpression(#"\n{3,}"#), "\n\n"),
    ]

    public static func apply(_ text: String) -> String {
        var result = text
        for (regex, template) in rules {
            result = regex.replaceAll(in: result, with: template)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
