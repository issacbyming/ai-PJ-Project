import Foundation

extension NSRegularExpression {
    convenience init(_ pattern: String) {
        // 所有 pattern 都是寫死的常數，若寫錯屬於程式錯誤，直接 crash 方便在測試時發現。
        try! self.init(pattern: pattern, options: [])
    }

    func allMatches(in text: String, from location: Int = 0) -> [NSTextCheckingResult] {
        let length = (text as NSString).length
        guard location <= length else { return [] }
        return matches(in: text, options: [], range: NSRange(location: location, length: length - location))
    }

    func first(in text: String, from location: Int = 0) -> NSTextCheckingResult? {
        let length = (text as NSString).length
        guard location <= length else { return nil }
        return firstMatch(in: text, options: [], range: NSRange(location: location, length: length - location))
    }

    func replaceAll(in text: String, with template: String) -> String {
        let length = (text as NSString).length
        return stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: length), withTemplate: template)
    }
}

extension String {
    var nsLength: Int { (self as NSString).length }

    func substring(_ range: NSRange) -> String {
        (self as NSString).substring(with: range)
    }

    func nsPrefix(to location: Int) -> String {
        (self as NSString).substring(to: location)
    }

    func nsSuffix(from location: Int) -> String {
        (self as NSString).substring(from: location)
    }

    /// 去掉開頭的標點與空白。
    func trimmingLeadingPunctuation(_ extra: String = "") -> String {
        let set = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "，,、：:。；;" + extra))
        var s = Substring(self)
        while let f = s.first, f.unicodeScalars.allSatisfy({ set.contains($0) }) {
            s = s.dropFirst()
        }
        return String(s)
    }

    /// 去掉結尾的標點與空白。
    func trimmingTrailingPunctuation(_ extra: String = "") -> String {
        let set = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "，,、：:。；;" + extra))
        var s = Substring(self)
        while let l = s.last, l.unicodeScalars.allSatisfy({ set.contains($0) }) {
            s = s.dropLast()
        }
        return String(s)
    }
}

/// 中文數字（一、二、兩、十一…）與半形／全形阿拉伯數字 → Int。
public enum ChineseNumber {
    private static let digits: [Character: Int] = [
        "零": 0, "〇": 0, "一": 1, "二": 2, "兩": 2, "三": 3, "四": 4,
        "五": 5, "六": 6, "七": 7, "八": 8, "九": 9,
    ]

    public static func parse(_ raw: String) -> Int? {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        // 全形數字轉半形
        let halfWidth = String(text.map { ch -> Character in
            guard let scalar = ch.unicodeScalars.first, ch.unicodeScalars.count == 1 else { return ch }
            if (0xFF10...0xFF19).contains(scalar.value), let converted = UnicodeScalar(scalar.value - 0xFF10 + 0x30) {
                return Character(converted)
            }
            return ch
        })
        if let n = Int(halfWidth) { return n }

        var total = 0
        var current = 0
        for ch in text {
            if let d = digits[ch] {
                current = d
            } else if ch == "十" {
                total += (current == 0 ? 1 : current) * 10
                current = 0
            } else {
                return nil
            }
        }
        return total + current
    }
}
