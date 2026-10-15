import Foundation
import VoiceNoteCore

enum ClaudeError: LocalizedError {
    case missingAPIKey
    case http(Int, String)
    case refused(String)
    case malformed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "還沒設定 Claude API key。"
        case .http(let code, let message): return "Claude API 錯誤（\(code)）：\(message)"
        case .refused(let reason): return "Claude 拒絕處理這段內容：\(reason)"
        case .malformed: return "Claude 回傳的格式看不懂。"
        }
    }
}

/// 呼叫 Claude 做「只分段、只套用更正、不潤飾」的整理。
///
/// 直接用 URLSession 打 Messages API（Swift 沒有官方 SDK）。
struct ClaudeStructurer {
    var apiKey: String
    var model: String

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    static func systemPrompt(dictionary: [DictionaryEntry], removeFillers: Bool) -> String {
        var lines: [String] = []
        lines.append("你是語音筆記的「排版員」，不是編輯，也不是寫手。使用者會給你一段語音辨識出來的文字，這段文字可能是日記，使用者希望日後讀到的是自己當下說的話。")
        lines.append("")
        lines.append("你只能做以下四件事：")
        lines.append("1. 套用說話者的自我更正：說話者改口時（例如「下午 2 點開會，改 3 點」「不對，是星期四」），只保留最後說的版本，並刪掉被更正掉的舊內容和更正提示詞。")
        lines.append("2. 依照說話者的明示指令分段：「記下這三點」「以下幾點」→ 用 1. 2. 3. 編號清單；「換行」「新段落」→ 換行或空一行；「以上」「就這樣」→ 結束清單。指令詞本身可以刪掉，但含有指令的那句話其餘的字要留著。")
        lines.append("3. 補上或修正標點符號與段落，讓文字好讀。")
        lines.append("4. 套用字典：下面列出的詞如果被辨識成相近的錯字，改成正確寫法。")
        lines.append("")
        lines.append("絕對禁止：")
        lines.append("- 改寫、潤飾、精簡、換句話說、調整語序、改變語氣。")
        lines.append("- 刪掉任何不是「指令詞」或「被更正掉的舊內容」的字。")
        lines.append(removeFillers
            ? "- （例外：可以刪掉「嗯」「呃」「那個」這類純語助詞。）"
            : "- 刪掉「嗯」「呃」「那個」等語助詞或口頭禪。這些要保留。")
        lines.append("- 補充使用者沒說的內容、加標題、加總結、加任何說明文字。")
        lines.append("- 把簡體／繁體或用字習慣改掉。")
        lines.append("")
        lines.append("輸出規則：只輸出整理後的文字本身，不要加任何前言、解釋、引號或 Markdown 程式碼區塊。如果這段文字不需要任何改動，就原樣輸出。")
        if !dictionary.isEmpty {
            lines.append("")
            lines.append("字典（正確寫法 ← 常見錯字）：")
            for entry in dictionary {
                let aliases = entry.aliases.isEmpty ? "" : " ← " + entry.aliases.joined(separator: "、")
                lines.append("- \(entry.term)\(aliases)")
            }
        }
        return lines.joined(separator: "\n")
    }

    func structure(text: String, dictionary: [DictionaryEntry], removeFillers: Bool) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw ClaudeError.missingAPIKey }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": Self.systemPrompt(dictionary: dictionary, removeFillers: removeFillers),
            "messages": [["role": "user", "content": text]],
            "output_config": ["effort": "low"],
            // 若安全分類器拒絕，伺服器端自動改用備援模型重跑同一個請求。
            "fallbacks": "default",
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        guard (200 ..< 300).contains(status) else {
            let message = ((json?["error"] as? [String: Any])?["message"] as? String)
                ?? String(data: data, encoding: .utf8)
                ?? "unknown"
            throw ClaudeError.http(status, message)
        }
        guard let json else { throw ClaudeError.malformed }

        if json["stop_reason"] as? String == "refusal" {
            let details = json["stop_details"] as? [String: Any]
            throw ClaudeError.refused(details?["explanation"] as? String ?? "未說明原因")
        }
        guard let content = json["content"] as? [[String: Any]] else { throw ClaudeError.malformed }
        let output = content
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty else { throw ClaudeError.malformed }
        return output
    }
}
