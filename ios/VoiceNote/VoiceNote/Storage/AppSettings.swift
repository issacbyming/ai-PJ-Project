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
    @Published var aiModel: String { didSet { defaults.set(aiModel, forKey: "aiModel") } }
    @Published var apiKey: String { didSet { KeychainHelper.save(apiKey.trimmingCharacters(in: .whitespacesAndNewlines)) } }

    init() {
        localeID = defaults.string(forKey: "localeID") ?? "zh-TW"
        preferOnDevice = defaults.object(forKey: "preferOnDevice") as? Bool ?? true
        removeFillers = defaults.bool(forKey: "removeFillers")
        defaultMode = ProcessingMode(rawValue: defaults.string(forKey: "defaultMode") ?? "") ?? .light
        aiModel = defaults.string(forKey: "aiModel") ?? Self.models[0].id
        apiKey = KeychainHelper.load() ?? ""
    }

    var processingOptions: ProcessingOptions {
        ProcessingOptions(removeFillers: removeFillers)
    }

    var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
}
