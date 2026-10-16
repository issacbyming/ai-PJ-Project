import Foundation
import Combine
import VoiceNoteCore

@MainActor
final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var localeID: String { didSet { defaults.set(localeID, forKey: "localeID") } }
    @Published var preferOnDevice: Bool { didSet { defaults.set(preferOnDevice, forKey: "preferOnDevice") } }
    @Published var removeFillers: Bool { didSet { defaults.set(removeFillers, forKey: "removeFillers") } }
    @Published var defaultMode: ProcessingMode { didSet { defaults.set(defaultMode.rawValue, forKey: "defaultMode") } }

    // Claude：整理
    @Published var aiModel: String { didSet { defaults.set(aiModel, forKey: "aiModel") } }
    @Published var apiKey: String { didSet { KeychainHelper.save(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), account: .claude) } }

    // OpenAI：中英夾雜的雲端語音辨識
    @Published var openAIKey: String { didSet { KeychainHelper.save(openAIKey.trimmingCharacters(in: .whitespacesAndNewlines), account: .openAI) } }
    @Published var transcriptionModel: String { didSet { defaults.set(transcriptionModel, forKey: "transcriptionModel") } }
    @Published var cloudTranscribeAfterStop: Bool { didSet { defaults.set(cloudTranscribeAfterStop, forKey: "cloudTranscribeAfterStop") } }

    init() {
        localeID = defaults.string(forKey: "localeID") ?? "zh-TW"
        preferOnDevice = defaults.object(forKey: "preferOnDevice") as? Bool ?? true
        removeFillers = defaults.bool(forKey: "removeFillers")
        defaultMode = ProcessingMode(rawValue: defaults.string(forKey: "defaultMode") ?? "") ?? .light
        aiModel = defaults.string(forKey: "aiModel") ?? AppSettings.models[0].id
        apiKey = KeychainHelper.load(account: .claude) ?? ""
        openAIKey = KeychainHelper.load(account: .openAI) ?? ""
        transcriptionModel = defaults.string(forKey: "transcriptionModel") ?? AppSettings.transcriptionModels[0].id
        cloudTranscribeAfterStop = defaults.object(forKey: "cloudTranscribeAfterStop") as? Bool ?? true
    }

    var processingOptions: ProcessingOptions {
        ProcessingOptions(removeFillers: removeFillers)
    }

    var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasOpenAIKey: Bool {
        !openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static let locales: [(id: String, name: String)] = [
        ("zh-TW", "中文（台灣）"),
        ("zh-HK", "中文（香港）"),
        ("zh-CN", "中文（中國）"),
        ("en-US", "English (US)"),
        ("ja-JP", "日本語"),
    ]

    static let models: [(id: String, name: String)] = [
        ("claude-opus-5-5", "Claude Opus 5.5（預設）"),
        ("claude-sonnet-5-5", "Claude Sonnet 5.5（較快）"),
        ("claude-haiku-5-5", "Claude Haiku 5.5（最快、最便宜）"),
    ]

    static let transcriptionModels: [(id: String, name: String)] = [
        ("gpt-4o-transcribe", "GPT-4o Transcribe（建議）"),
        ("gpt-4o-mini-transcribe", "GPT-4o mini Transcribe（較便宜）"),
        ("whisper-1", "Whisper v1"),
    ]
}
