import SwiftUI
import VoiceNoteCore

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var recognizer: SpeechRecognizer

    var body: some View {
        NavigationStack {
            Form {
                Section("語音辨識") {
                    Picker("語言", selection: $settings.localeID) {
                        ForEach(AppSettings.locales, id: \.id) { locale in
                            Text(locale.name).tag(locale.id)
                        }
                    }
                    Toggle("優先用裝置端辨識", isOn: $settings.preferOnDevice)
                    Text("裝置端辨識不用網路、沒有時間限制，但準確度可能略低。這個語言若不支援會自動改用雲端。")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("整理方式") {
                    Picker("儲存時預設", selection: $settings.defaultMode) {
                        ForEach(ProcessingMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    Text(settings.defaultMode.detail)
                        .font(.footnote).foregroundStyle(.secondary)
                    Toggle("刪除語助詞（嗯、呃、那個）", isOn: $settings.removeFillers)
                    Text("寫日記建議關閉，保留說話當下的樣子。")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section {
                    SecureField("sk-…", text: $settings.openAIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Picker("模型", selection: $settings.transcriptionModel) {
                        ForEach(AppSettings.transcriptionModels, id: \.id) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                    Toggle("停止錄音後自動雲端重辨識", isOn: $settings.cloudTranscribeAfterStop)
                        .disabled(!settings.hasOpenAIKey)
                } header: {
                    Text("OpenAI 語音辨識（中英夾雜）")
                } footer: {
                    Text("Apple 的即時辨識一次只能認一種語言，中英夾雜會出錯。填了 OpenAI API key 之後，停止錄音時會把整段錄音送到 OpenAI 重新辨識（自動偵測語言，中文英文可以混講），再換掉即時辨識的草稿。字典裡的正確寫法會當成提示詞一起送。key 存在 Keychain，只送到 api.openai.com。")
                }

                Section {
                    SecureField("sk-ant-…", text: $settings.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Picker("模型", selection: $settings.aiModel) {
                        ForEach(AppSettings.models, id: \.id) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                } header: {
                    Text("Claude 整理（選用）")
                } footer: {
                    Text("填了 key 才會出現「AI 整理」按鈕。key 存在這支手機的 Keychain，只會送到 api.anthropic.com。AI 整理的提示詞明確禁止改寫句子，只做分段、自我更正與標點。")
                }

                Section("關於") {
                    LabeledContent("原則", value: "原文永遠保留")
                    Text("每則筆記都同時存「原文」和「整理後」。整理永遠是另外產生的一份，隨時可以回頭看原本講了什麼。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
        }
    }
}
