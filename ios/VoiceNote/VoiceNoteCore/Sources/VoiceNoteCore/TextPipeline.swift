import Foundation

/// 本機文字整理流程。輸入永遠不會被修改，呼叫端要自己保留原文。
///
/// 順序：字典 → 口說標點 → 換行指令 → 自我更正 → 清單指令 → 語助詞 → 收尾。
public enum TextPipeline {
    public static func process(_ raw: String,
                               dictionary: [DictionaryEntry] = [],
                               options: ProcessingOptions = .default) -> ProcessedResult {
        var text = raw
        var changes: [TextChange] = []

        if options.applyDictionary {
            let r = DictionaryProcessor.apply(text, entries: dictionary)
            text = r.text
            changes += r.changes
        }
        if options.applyCommands {
            let p = PunctuationCommandProcessor.apply(text)
            text = p.text
            changes += p.changes
            let n = NewlineCommandProcessor.apply(text)
            text = n.text
            changes += n.changes
        }
        if options.applyCorrections {
            let r = CorrectionProcessor.apply(text)
            text = r.text
            changes += r.changes
        }
        if options.applyCommands {
            let r = ListCommandProcessor.apply(text)
            text = r.text
            changes += r.changes
        }
        if options.removeFillers {
            let r = FillerProcessor.apply(text)
            text = r.text
            changes += r.changes
        }
        text = TextCleanup.apply(text)
        return ProcessedResult(text: text, changes: changes)
    }
}
