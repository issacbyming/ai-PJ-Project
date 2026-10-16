import SwiftUI
import VoiceNoteCore

struct RecordView: View {
    @EnvironmentObject private var recognizer: SpeechRecognizer
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var dictionary: DictionaryStore
    @EnvironmentObject private var notes: NoteStore

    @State private var permissionGranted: Bool?
    @State private var showPreview = true
    @State private var aiText: String?
    @State private var isRunningAI = false
    @State private var errorMessage: String?
    @State private var savedBannerVisible = false
    @State private var isTranscribingCloud = false
    @State private var cloudApplied = false

    private var rawText: String { recognizer.liveText }

    private var localResult: ProcessedResult {
        TextPipeline.process(rawText, dictionary: dictionary.entries, options: settings.processingOptions)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                transcriptArea
                Divider()
                controls
                    .padding()
            }
            .navigationTitle("錄音")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle(isOn: $showPreview) { Text("預覽") }
                        .toggleStyle(.button)
                        .disabled(rawText.isEmpty)
                }
            }
            .task {
                if permissionGranted == nil {
                    permissionGranted = await recognizer.requestPermissions()
                }
            }
            .onChange(of: recognizer.state) { oldState, newState in
                // 錄音收尾完成 → 自動送雲端重辨識（中英夾雜）
                if oldState == .stopping, newState == .idle, settings.cloudTranscribeAfterStop, settings.hasOpenAIKey {
                    Task { await runCloudTranscription() }
                }
            }
            .alert("出錯了", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .overlay(alignment: .top) {
                if savedBannerVisible {
                    Text("已儲存到「筆記」")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Transcript

    private var transcriptArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if rawText.isEmpty {
                        emptyHint
                    } else {
                        section(title: cloudApplied ? "原文（雲端重辨識，中英）" : "原文（即時草稿）", badge: rawBadge) {
                            Text(attributedLive)
                        }
                        if isTranscribingCloud {
                            Label("雲端重辨識中（中英夾雜）…", systemImage: "icloud.and.arrow.up")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if showPreview {
                            section(title: aiText == nil ? "整理預覽（本機規則）" : "整理預覽（Claude）", badge: nil) {
                                Text(aiText ?? localResult.text)
                            }
                            if !localResult.changes.isEmpty && aiText == nil {
                                ChangesList(changes: localResult.changes)
                            }
                        }
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding()
            }
            .onChange(of: rawText) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    private var rawBadge: String {
        if cloudApplied { return "OpenAI" }
        return recognizer.isOnDevice ? "Apple 裝置端" : "Apple 雲端"
    }

    private var attributedLive: AttributedString {
        var committed = AttributedString(recognizer.committedText)
        committed.foregroundColor = .primary
        var partial = AttributedString(recognizer.partialText)
        partial.foregroundColor = .secondary
        if recognizer.committedText.isEmpty { return partial }
        if recognizer.partialText.isEmpty { return committed }
        let joiner = AttributedString(settings.localeID.hasPrefix("zh") || settings.localeID.hasPrefix("ja") ? "" : " ")
        return committed + joiner + partial
    }

    private var emptyHint: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("按下麥克風開始講話，文字會即時出現在這裡。")
                .font(.headline)
            Text("原文永遠會完整保留；整理只是另外產生一份。")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                Text("可以用的口說指令").font(.subheadline.weight(.semibold))
                hintRow("記下這三點 / 以下幾點", "之後的句子變成 1. 2. 3.")
                hintRow("第一、第二、第三", "明確指定每一點")
                hintRow("以上 / 就這樣", "結束清單")
                hintRow("換行 / 新段落", "換行或空一行")
                hintRow("下午 2 點…改 3 點", "自我更正，只留最後說的")
                hintRow("不對，是星期四", "同上")
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            if settings.hasOpenAIKey {
                Text("已設定 OpenAI key：停止錄音後會自動重新辨識，中英夾雜也沒問題。")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Text("中英夾雜講話會認錯？到「設定」填 OpenAI API key，停止後會用雲端重新辨識。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if permissionGranted == false {
                Label("沒有麥克風或語音辨識權限，請到 iOS「設定」開啟。", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }
    }

    private func hintRow(_ command: String, _ effect: String) -> some View {
        HStack(alignment: .top) {
            Text("「\(command)」").font(.callout.monospaced())
            Spacer()
            Text(effect).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func section<Content: View>(title: String, badge: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if let badge {
                    Text(badge).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
            }
            content()
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 14) {
            statusLine
            Button(action: toggleRecording) {
                Image(systemName: recognizer.isListening ? "stop.fill" : "mic.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(recognizer.isListening ? Color.red : Color.accentColor, in: Circle())
            }
            .disabled(permissionGranted == false || isRunningAI || isTranscribingCloud)

            HStack(spacing: 12) {
                Button(role: .destructive) { clear() } label: {
                    Label("清除", systemImage: "trash")
                }
                .disabled(rawText.isEmpty || recognizer.isListening || isTranscribingCloud)

                if settings.hasOpenAIKey, recognizer.lastRecordingURL != nil, !cloudApplied {
                    Button { Task { await runCloudTranscription() } } label: {
                        if isTranscribingCloud { ProgressView() } else { Label("中英重辨識", systemImage: "globe") }
                    }
                    .disabled(recognizer.isListening || isTranscribingCloud)
                }

                Spacer()

                if settings.hasAPIKey {
                    Button { Task { await runAI() } } label: {
                        if isRunningAI {
                            ProgressView()
                        } else {
                            Label("AI 整理", systemImage: "sparkles")
                        }
                    }
                    .disabled(rawText.isEmpty || recognizer.isListening || isRunningAI || isTranscribingCloud)
                }

                Button { save() } label: {
                    Label("儲存", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(rawText.isEmpty || recognizer.isListening || isRunningAI || isTranscribingCloud)
            }
            .buttonStyle(.bordered)
        }
    }

    private var statusLine: some View {
        Group {
            switch recognizer.state {
            case .idle:
                Text(rawText.isEmpty ? "準備好了" : "已停止，可以繼續錄或儲存")
            case .listening:
                Label("聆聽中…", systemImage: "waveform").foregroundStyle(.red)
            case .stopping:
                Text("收尾中…")
            case .error(let message):
                Text(message).foregroundStyle(.red)
            }
        }
        .font(.footnote)
    }

    // MARK: - Actions

    private func toggleRecording() {
        if recognizer.isListening {
            recognizer.stop()
            return
        }
        aiText = nil
        cloudApplied = false
        recognizer.configure(localeIdentifier: settings.localeID,
                             preferOnDevice: settings.preferOnDevice,
                             contextualStrings: dictionary.contextualTerms)
        do {
            try recognizer.start()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clear() {
        recognizer.reset()
        aiText = nil
        cloudApplied = false
    }

    /// 把剛才的錄音送 OpenAI 重新辨識，用結果換掉 Apple 的即時草稿。
    private func runCloudTranscription() async {
        guard let url = recognizer.lastRecordingURL, !isTranscribingCloud else { return }
        isTranscribingCloud = true
        defer { isTranscribingCloud = false }
        let transcriber = CloudTranscriber(apiKey: settings.openAIKey, model: settings.transcriptionModel)
        do {
            let text = try await transcriber.transcribe(fileURL: url,
                                                        vocabulary: dictionary.contextualTerms,
                                                        localeHint: settings.localeID)
            recognizer.replaceCurrentSessionText(with: text)
            aiText = nil
            cloudApplied = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runAI() async {
        isRunningAI = true
        defer { isRunningAI = false }
        let structurer = ClaudeStructurer(apiKey: settings.apiKey, model: settings.aiModel)
        do {
            aiText = try await structurer.structure(text: localResult.text,
                                                    dictionary: dictionary.entries,
                                                    removeFillers: settings.removeFillers)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        let raw = rawText
        guard !raw.isEmpty else { return }
        let local = localResult
        let note: Note
        if let aiText {
            note = Note(rawText: raw, processedText: aiText, mode: .ai, changes: local.changes)
        } else {
            switch settings.defaultMode {
            case .raw:
                note = Note(rawText: raw, processedText: raw, mode: .raw)
            case .light, .ai:
                note = Note(rawText: raw, processedText: local.text, mode: .light, changes: local.changes)
            }
        }
        notes.add(note)
        clear()
        withAnimation { savedBannerVisible = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation { savedBannerVisible = false }
        }
        if settings.defaultMode == .ai, settings.hasAPIKey, note.mode != .ai {
            Task { await upgradeToAI(noteID: note.id, text: note.processedText) }
        }
    }

    /// 預設模式是「AI 整理」時，存檔後背景再跑一次 Claude，完成後更新筆記。
    private func upgradeToAI(noteID: UUID, text: String) async {
        let structurer = ClaudeStructurer(apiKey: settings.apiKey, model: settings.aiModel)
        guard let result = try? await structurer.structure(text: text,
                                                            dictionary: dictionary.entries,
                                                            removeFillers: settings.removeFillers) else { return }
        guard let existing = notes.note(id: noteID) else { return }
        notes.updateProcessed(id: noteID, text: result, mode: .ai, changes: existing.changes)
    }
}

/// 列出整理時到底改了什麼。
struct ChangesList: View {
    let changes: [TextChange]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("這次改了什麼").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(changes) { change in
                HStack(alignment: .top, spacing: 8) {
                    Text(change.kind.title)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                    Text(changeDescription(change))
                        .font(.callout)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func changeDescription(_ change: TextChange) -> String {
        switch change.kind {
        case .dictionary, .correction:
            return "\(change.from) → \(change.to)" + (change.count > 1 ? "（\(change.count) 次）" : "")
        case .command:
            return "\(change.from) → \(change.to)" + (change.count > 1 ? "（\(change.count) 次）" : "")
        case .filler:
            return "刪掉 \(change.count) 個語助詞"
        }
    }
}
