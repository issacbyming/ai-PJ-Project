import Foundation

/// 「句號」「逗號」等口說標點。
public enum PunctuationCommandProcessor {
    private static let regex = NSRegularExpression(#"(?:^|(?<=[，,。！？；：\s]))(句號|逗號|問號|驚嘆號|冒號|頓號|分號)(?=[，,。！？；：\s]|$)"#)
    private static let map: [String: String] = [
        "句號": "。", "逗號": "，", "問號": "？", "驚嘆號": "！", "冒號": "：", "頓號": "、", "分號": "；",
    ]

    public static func apply(_ text: String) -> (text: String, changes: [TextChange]) {
        var changes: [TextChange] = []
        var result = text
        let matches = regex.allMatches(in: text).reversed()
        for m in matches {
            let word = text.substring(m.range)
            guard let mark = map[word] else { continue }
            result = (result as NSString).replacingCharacters(in: m.range, with: mark)
            changes.append(TextChange(kind: .command, from: word, to: mark))
        }
        return (result, changes)
    }
}

/// 「換行」「新段落」等口說指令。
public enum NewlineCommandProcessor {
    private static let newline = NSRegularExpression(#"[，,]?\s*(?:換行|換一行|另起一行)[，,。]?\s*"#)
    private static let paragraph = NSRegularExpression(#"[，,]?\s*(?:新段落|下一段|另起一段|分段|空一行)[，,。]?\s*"#)

    public static func apply(_ text: String) -> (text: String, changes: [TextChange]) {
        var changes: [TextChange] = []
        var result = text
        let paragraphCount = paragraph.allMatches(in: result).count
        if paragraphCount > 0 {
            result = paragraph.replaceAll(in: result, with: "\n\n")
            changes.append(TextChange(kind: .command, from: "新段落", to: "分段", count: paragraphCount))
        }
        let newlineCount = newline.allMatches(in: result).count
        if newlineCount > 0 {
            result = newline.replaceAll(in: result, with: "\n")
            changes.append(TextChange(kind: .command, from: "換行", to: "換行", count: newlineCount))
        }
        return (result, changes)
    }
}

/// 「記下這三點」「以下幾點」→ 編號清單。
///
/// 規則：
/// 1. 含有指令的那一句保留下來當標題（例：「今天開會記下這三點：」），不丟掉任何字。
/// 2. 之後的內容切成項目。優先用「第一、第二」這種明確標記；沒有的話依序試
///    句號分句、「然後／再來」連接詞、逗號，挑出數量剛好等於說出的數字的那一種。
/// 3. 遇到「以上」「就這樣」或空一行就結束清單。
public enum ListCommandProcessor {
    private static let numeralClass = #"[一二三四五六七八九十兩\d０-９]+"#

    private static let cue = NSRegularExpression(
        #"(?:記下|記住|記錄|記一下|筆記|寫下|列出|列一下|整理|分成|分為|以下|下面|總結|重點|提醒)(?:這|以下|下面|的|成|為|有|是)?(幾|"# + numeralClass + #")(?:點|件事|件|項|個重點|個部分|個步驟|個要點|個事項|個東西|個)(?=[，,。：:；\s]|$|第一)"#
    )
    private static let endMarker = NSRegularExpression(
        #"(?:^|(?<=[，,。！？；\s]))(?:以上|就這樣|就這些|大概就這樣|差不多這樣|大概這樣|就是這樣)[，,。！？]?"#
    )
    private static let ordinal = NSRegularExpression(
        #"(?:^|(?<=[，,。！？；：:\s]))(?:第("# + numeralClass + #")(?:點|個|項|件|條|步)?(?:就是|是)?|([一二三四五六七八九十])[、．.])[，,、：:\s]*"#
    )
    private static let connector = NSRegularExpression(
        #"[，,。；;]\s*(?:然後|再來|接著|接下來|還有|另外|最後|其次|再者)[，,]?"#
    )
    private static let leadingConnector = NSRegularExpression(
        #"^(?:然後|再來|接著|接下來|還有|另外|最後|其次|再者)[，,]?"#
    )
    private static let sentenceTerminators = "。！？；!?;\n"

    struct Split {
        var leading: String = ""
        var items: [String] = []
        var trailing: String = ""
    }

    public static func apply(_ text: String) -> (text: String, changes: [TextChange]) {
        var output = ""
        var rest = text
        var changes: [TextChange] = []
        var guardCounter = 0

        while guardCounter < 20, let m = cue.first(in: rest) {
            guardCounter += 1
            let before = rest.nsPrefix(to: m.range.location)
            let cueText = rest.substring(m.range)
            let afterCue = rest.nsSuffix(from: m.range.location + m.range.length)
            let numeralText = rest.substring(m.range(at: 1))
            let expected: Int? = numeralText == "幾" ? nil : ChineseNumber.parse(numeralText)

            let (prefix, introStart) = splitAtLastSentenceBoundary(before)
            var intro = introStart + cueText

            // 清單範圍：到結束詞或空一行為止
            var regionEnd = afterCue.nsLength
            var tail = ""
            if let e = endMarker.first(in: afterCue) {
                regionEnd = e.range.location
                tail = afterCue.nsSuffix(from: e.range.location + e.range.length)
            }
            let paragraphBreak = (afterCue as NSString).range(of: "\n\n")
            if paragraphBreak.location != NSNotFound, paragraphBreak.location < regionEnd {
                regionEnd = paragraphBreak.location
                tail = afterCue.nsSuffix(from: paragraphBreak.location)
            }
            let region = afterCue.nsPrefix(to: regionEnd)
            let split = splitItems(region, expected: expected)

            guard split.items.count >= 2 else {
                // 切不出清單就原樣保留，繼續往後找。
                output += before + cueText
                rest = afterCue
                continue
            }

            if !split.leading.isEmpty {
                intro += "，" + split.leading
            }
            intro = intro.trimmingTrailingPunctuation() + "："
            var block = intro + "\n" + split.items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            let trailing = split.trailing.trimmingLeadingPunctuation().trimmingCharacters(in: .whitespacesAndNewlines)
            if !trailing.isEmpty {
                block += "\n\n" + trailing
            }
            output += prefix + block + "\n"
            rest = tail.trimmingLeadingPunctuation()
            changes.append(TextChange(kind: .command, from: cueText, to: "清單（\(split.items.count) 項）"))
        }
        output += rest
        return (output, changes)
    }

    /// 回傳 (前面已完成的句子, 含指令的那句開頭)。
    private static func splitAtLastSentenceBoundary(_ text: String) -> (String, String) {
        let ns = text as NSString
        let boundary = ns.rangeOfCharacter(from: CharacterSet(charactersIn: "。！？\n"), options: .backwards)
        guard boundary.location != NSNotFound else { return ("", text) }
        let cut = boundary.location + boundary.length
        return (ns.substring(to: cut), ns.substring(from: cut))
    }

    static func splitItems(_ regionRaw: String, expected: Int?) -> Split {
        let region = regionRaw.trimmingLeadingPunctuation().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !region.isEmpty else { return Split() }

        // 1. 明確的「第一、第二」
        let ordinals = ordinal.allMatches(in: region)
        if !ordinals.isEmpty {
            let leadingText = cleanItem(region.nsPrefix(to: ordinals[0].range.location))
            var items: [String] = []
            for (i, m) in ordinals.enumerated() {
                let start = m.range.location + m.range.length
                let end = i + 1 < ordinals.count ? ordinals[i + 1].range.location : region.nsLength
                guard end >= start else { continue }
                let item = cleanItem(region.substring(NSRange(location: start, length: end - start)))
                if !item.isEmpty { items.append(item) }
            }
            // 講者沒說「第一」、直接從「第二」開始：把前面那段當第一項。
            let firstNumber = ordinalNumber(of: ordinals[0], in: region)
            var leading = leadingText
            if !leadingText.isEmpty, firstNumber == 2 || (expected != nil && items.count + 1 == expected) {
                items.insert(leadingText, at: 0)
                leading = ""
            }
            if items.count >= 2 {
                return Split(leading: leading, items: items)
            }
        }

        // 2. 句子 / 連接詞 / 逗號
        let rawSentences = splitSentences(region)
        let bySentence = rawSentences.map(cleanItem).filter { !$0.isEmpty }
        let byConnector = validCandidate(splitConnectors(region).map(cleanItem).filter { !$0.isEmpty })
        let byComma = validCandidate(region.components(separatedBy: CharacterSet(charactersIn: "，,")).map(cleanItem).filter { !$0.isEmpty })

        if let n = expected, n >= 2 {
            for candidate in [bySentence, byConnector, byComma] where candidate.count == n {
                return Split(items: candidate)
            }
            if bySentence.count > n {
                let items = Array(rawSentences.prefix(n)).map(cleanItem).filter { !$0.isEmpty }
                let trailing = rawSentences.dropFirst(n).joined()
                return Split(items: items, trailing: trailing)
            }
            if byComma.count > n {
                let head = Array(byComma.prefix(n - 1))
                let last = byComma.dropFirst(n - 1).joined(separator: "，")
                return Split(items: head + [last])
            }
            if bySentence.count >= 2 { return Split(items: bySentence) }
            if byComma.count >= 2 { return Split(items: byComma) }
            return Split()
        }

        if bySentence.count >= 2 { return Split(items: bySentence) }
        if byConnector.count >= 2 { return Split(items: byConnector) }
        if byComma.count >= 2 { return Split(items: byComma) }
        return Split()
    }

    /// 連接詞／逗號切出來的項目中間不該夾著句號，否則不採用。
    private static func validCandidate(_ items: [String]) -> [String] {
        let bad = items.contains { item in item.contains { sentenceTerminators.contains($0) } }
        return bad ? [] : items
    }

    private static func ordinalNumber(of match: NSTextCheckingResult, in text: String) -> Int? {
        for group in 1...2 {
            let r = match.range(at: group)
            if r.location != NSNotFound, let n = ChineseNumber.parse(text.substring(r)) {
                return n
            }
        }
        return nil
    }

    static func splitSentences(_ text: String) -> [String] {
        var chunks: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if sentenceTerminators.contains(ch) {
                chunks.append(current)
                current = ""
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    static func splitConnectors(_ text: String) -> [String] {
        let matches = connector.allMatches(in: text)
        guard !matches.isEmpty else { return [text] }
        var chunks: [String] = []
        var cursor = 0
        for m in matches {
            if m.range.location > cursor {
                chunks.append(text.substring(NSRange(location: cursor, length: m.range.location - cursor)))
            }
            cursor = m.range.location + m.range.length
        }
        if cursor < text.nsLength { chunks.append(text.nsSuffix(from: cursor)) }
        return chunks
    }

    static func cleanItem(_ raw: String) -> String {
        var item = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        item = leadingConnector.replaceAll(in: item, with: "")
        item = item.trimmingLeadingPunctuation().trimmingTrailingPunctuation()
        return item
    }
}
