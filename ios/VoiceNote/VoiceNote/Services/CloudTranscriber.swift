import Foundation

enum TranscriberError: LocalizedError {
    case missingAPIKey
    case fileTooLarge
    case http(Int, String)
    case malformed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "還沒設定 OpenAI API key。"
        case .fileTooLarge: return "這段錄音超過 25 MB，雲端辨識上傳不了；請分段錄。"
        case .http(let code, let message): return "雲端辨識錯誤（\(code)）：\(message)"
        case .malformed: return "雲端辨識回傳的格式看不懂。"
        }
    }
}

/// 把錄音檔送到 OpenAI 的語音轉文字 API。
/// 不指定語言，讓模型自己偵測，所以中文、英文夾雜講也能正確分辨。
struct CloudTranscriber {
    var apiKey: String
    var model: String

    private static let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    private static let maxBytes = 25 * 1024 * 1024

    /// `vocabulary`：字典裡的正確寫法，會當成提示詞讓模型優先用這些拼法。
    func transcribe(fileURL: URL, vocabulary: [String], localeHint: String) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw TranscriberError.missingAPIKey }
        let audio = try Data(contentsOf: fileURL)
        guard audio.count <= Self.maxBytes else { throw TranscriberError.fileTooLarge }

        let boundary = "VoiceNote-\(UUID().uuidString)"
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append(value.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        field("model", model)
        field("response_format", "json")
        field("prompt", Self.prompt(vocabulary: vocabulary, localeHint: localeHint))
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audio)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 180

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard (200 ..< 300).contains(status) else {
            let message = ((json?["error"] as? [String: Any])?["message"] as? String)
                ?? String(data: data, encoding: .utf8)
                ?? "unknown"
            throw TranscriberError.http(status, message)
        }
        guard let text = json?["text"] as? String else { throw TranscriberError.malformed }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 提示詞：告訴模型這是哪種中文、可能中英夾雜，以及專有名詞的正確拼法。
    static func prompt(vocabulary: [String], localeHint: String) -> String {
        var parts: [String] = []
        if localeHint.hasPrefix("zh-TW") || localeHint.hasPrefix("zh-HK") {
            parts.append("這是一段繁體中文的語音筆記，中間會夾雜英文單字或句子，英文請照原文用英文寫出來，不要翻譯。")
        } else if localeHint.hasPrefix("zh") {
            parts.append("这是一段中文的语音笔记，中间会夹杂英文单词或句子，英文请照原文用英文写出来，不要翻译。")
        } else {
            parts.append("This is a voice note that may mix English with Chinese. Keep each language as spoken; do not translate.")
        }
        if !vocabulary.isEmpty {
            parts.append("專有名詞：" + vocabulary.joined(separator: "、") + "。")
        }
        return parts.joined(separator: " ")
    }
}
