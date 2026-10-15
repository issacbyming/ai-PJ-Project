import Foundation

/// 字典條目：`term` 是正確寫法，`aliases` 是語音辨識常誤認成的寫法。
/// `term` 也會送給 Apple 語音辨識當作提示詞（contextual strings），讓它更容易辨識出來。
public struct DictionaryEntry: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var term: String
    public var aliases: [String]
    public var note: String

    public init(id: UUID = UUID(), term: String, aliases: [String] = [], note: String = "") {
        self.id = id
        self.term = term
        self.aliases = aliases
        self.note = note
    }
}

/// 整理方式。
public enum ProcessingMode: String, Codable, CaseIterable, Sendable {
    /// 完全不處理，存下辨識出來的原文。
    case raw
    /// 本機規則：字典、換行／列點指令、自我更正。不會改寫任何句子。
    case light
    /// 本機規則之後，再交給 Claude 做「只分段、只套用更正」的結構整理（禁止潤飾）。
    case ai

    public var title: String {
        switch self {
        case .raw: return "原文"
        case .light: return "輕整理"
        case .ai: return "AI 整理"
        }
    }

    public var detail: String {
        switch self {
        case .raw: return "只存辨識原文，什麼都不改。"
        case .light: return "套用字典、「記下這三點」「換行」等指令、以及「改 3 點」這類自我更正。全部在手機上完成，不改寫句子。"
        case .ai: return "輕整理之後再交給 Claude 補強分段與更正。提示詞明確禁止潤飾或換句話說。"
        }
    }
}

public struct ProcessingOptions: Codable, Hashable, Sendable {
    public var applyDictionary: Bool
    public var applyCommands: Bool
    public var applyCorrections: Bool
    /// 是否刪除「嗯、呃、那個」等語助詞。預設關閉（寫日記時通常希望保留）。
    public var removeFillers: Bool

    public init(applyDictionary: Bool = true,
                applyCommands: Bool = true,
                applyCorrections: Bool = true,
                removeFillers: Bool = false) {
        self.applyDictionary = applyDictionary
        self.applyCommands = applyCommands
        self.applyCorrections = applyCorrections
        self.removeFillers = removeFillers
    }

    public static let `default` = ProcessingOptions()
}

/// 一筆「整理時做了什麼」的記錄，讓使用者看得到被改掉的是什麼。
public struct TextChange: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case dictionary
        case correction
        case command
        case filler

        public var title: String {
            switch self {
            case .dictionary: return "字典"
            case .correction: return "自我更正"
            case .command: return "指令"
            case .filler: return "語助詞"
            }
        }
    }

    public var id: UUID
    public var kind: Kind
    public var from: String
    public var to: String
    public var count: Int

    public init(id: UUID = UUID(), kind: Kind, from: String, to: String, count: Int = 1) {
        self.id = id
        self.kind = kind
        self.from = from
        self.to = to
        self.count = count
    }
}

public struct ProcessedResult: Hashable, Sendable {
    public var text: String
    public var changes: [TextChange]

    public init(text: String, changes: [TextChange]) {
        self.text = text
        self.changes = changes
    }
}
