import Foundation

/// 自我更正：「下午 2 點開會，改 3 點」→「下午 3 點開會」。
///
/// 做法：
/// 1. 找到更正提示詞（不對、改成、改 3 點、不是…是…）與它後面的「新內容」。
/// 2. 往前（同一段落內）找最像的「舊內容」：
///    - 新內容以數字開頭：找前面最後一個「數字 + 相同單位」（2點 → 3點、三個 → 五個）。
///    - 否則比對字形相似度（星期三 → 星期四）。
/// 3. 找得到才替換並刪掉提示詞；找不到就原文保留，不亂刪。
public enum CorrectionProcessor {
    private static let numeral = #"[0-9０-９一二三四五六七八九十兩百千零〇]+"#

    private static let cues: [NSRegularExpression] = [
        // 「，不對，三點」「，錯了，是三點」「，更正，三點」「，我是說三點」
        NSRegularExpression(#"[，,。]\s*(?:不對|錯了|更正|我是說|改一下)[，,、\s]*(?:是)?([^，,。！？；\n]{1,20})"#),
        // 「改成三點」「改為三點」「改到三點」（前面有沒有逗號都可以）
        NSRegularExpression(#"[，,。]?\s*(?:改成|改為|改到)[，,\s]*([^，,。！？；\n]{1,20})"#),
        // 「，不是，三點」「，不是，是三點」
        NSRegularExpression(#"[，,。]\s*不是[，,]\s*(?:是)?([^，,。！？；\n]{1,20})"#),
        // 「改三點」「改 3 點」：只有「改」直接接數字才算
        NSRegularExpression(#"[，,。]?\s*改("# + numeral + #"[^，,。！？；\n]{0,6})"#),
    ]

    private static let numeralLead = NSRegularExpression(#"^("# + numeral + #")(.*)$"#)
    private static let punctuationChars = "，,。！？；：\n "

    struct Target {
        let range: NSRange
        let text: String
    }

    public static func apply(_ text: String) -> (text: String, changes: [TextChange]) {
        var text = text
        var changes: [TextChange] = []

        for cue in cues {
            var cursor = 0
            var iterations = 0
            while iterations < 50 {
                iterations += 1
                guard cursor < text.nsLength, let m = cue.first(in: text, from: cursor) else { break }

                let replacement = text.substring(m.range(at: 1)).trimmingCharacters(in: .whitespaces)
                let priorAll = text.nsPrefix(to: m.range.location)
                let paragraphStart: Int = {
                    let r = (priorAll as NSString).range(of: "\n", options: .backwards)
                    return r.location == NSNotFound ? 0 : r.location + 1
                }()
                let paragraphPrefix = priorAll.nsPrefix(to: paragraphStart)
                let prior = priorAll.nsSuffix(from: paragraphStart)

                guard !replacement.isEmpty, let target = findTarget(in: prior, replacement: replacement) else {
                    cursor = m.range.location + m.range.length
                    continue
                }

                let newPrior = (prior as NSString).replacingCharacters(in: target.range, with: replacement)
                let after = text.nsSuffix(from: m.range.location + m.range.length)
                let cueFirst = text.substring(NSRange(location: m.range.location, length: 1))
                let cueStartsWithPunct = "，,。".contains(cueFirst)
                let afterStartsWithPunct = after.first.map { "，,。！？；：\n".contains($0) } ?? true
                let joiner = (cueStartsWithPunct && !afterStartsWithPunct) ? cueFirst : ""

                text = paragraphPrefix + newPrior + joiner + after
                cursor = paragraphPrefix.nsLength + newPrior.nsLength
                changes.append(TextChange(kind: .correction, from: target.text, to: replacement))
            }
        }
        return (text, changes)
    }

    static func findTarget(in prior: String, replacement: String) -> Target? {
        let priorNS = prior as NSString

        // 1. 數字 + 單位
        if let nm = numeralLead.first(in: replacement) {
            let unit = replacement.substring(nm.range(at: 2))
            let patterns: [String] = unit.isEmpty
                ? [numeral]
                : [numeral + NSRegularExpression.escapedPattern(for: unit),
                   numeral + NSRegularExpression.escapedPattern(for: String(unit.prefix(1)))]
            for (index, pattern) in patterns.enumerated() {
                guard let re = try? NSRegularExpression(pattern: pattern, options: []),
                      let last = re.allMatches(in: prior).last else { continue }
                var range = last.range
                if index == 1 {
                    // 只對到單位的第一個字（三個蘋果 → 五個香蕉）：把舊內容延伸到跟新內容一樣長
                    let desired = replacement.nsLength
                    let available = priorNS.length - range.location
                    range = NSRange(location: range.location, length: min(desired, available))
                    let candidate = priorNS.substring(with: range)
                    if candidate.contains(where: { punctuationChars.contains($0) }) { continue }
                }
                let old = priorNS.substring(with: range)
                if old == replacement { return nil }
                return Target(range: range, text: old)
            }
            if unit.isEmpty { return nil }
        }

        // 2. 字形相似度（同長度或差一字）
        let rc = Array(replacement)
        let pc = Array(prior)
        let windowStartMin = max(0, pc.count - 40)
        var best: (start: Int, len: Int, score: Int)?

        for len in [rc.count, rc.count + 1, rc.count - 1] {
            guard len >= 1, len <= pc.count else { continue }
            var start = windowStartMin
            while start + len <= pc.count {
                let window = pc[start ..< start + len]
                if window.contains(where: { punctuationChars.contains($0) }) {
                    start += 1
                    continue
                }
                let score = zip(window, rc).filter { $0 == $1 }.count
                // 至少要有兩個字相同，避免「明天，應該是晴天」這種誤判；數字類的改法走上面的規則。
                let threshold = max(2, (min(len, rc.count) + 1) / 2)
                if score >= threshold, String(window) != replacement {
                    // 相同字數越多越好；字數一樣時偏好長度相同、位置較後面的。
                    let priority = score * 10 - abs(len - rc.count)
                    if let b = best {
                        let bPriority = b.score * 10 - abs(b.len - rc.count)
                        if priority > bPriority || (priority == bPriority && start >= b.start) {
                            best = (start, len, score)
                        }
                    } else {
                        best = (start, len, score)
                    }
                }
                start += 1
            }
        }

        guard let b = best else { return nil }
        let startIndex = prior.index(prior.startIndex, offsetBy: b.start)
        let endIndex = prior.index(startIndex, offsetBy: b.len)
        let range = NSRange(startIndex ..< endIndex, in: prior)
        return Target(range: range, text: String(prior[startIndex ..< endIndex]))
    }
}
