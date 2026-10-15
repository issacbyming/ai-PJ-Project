import Foundation
import AVFoundation
import Speech
import Combine

/// 跨執行緒安全地持有目前的辨識請求與錄音檔（音訊 tap 在背景執行緒呼叫）。
private final class AudioSinkBox: @unchecked Sendable {
    private let lock = NSLock()
    private var currentRequest: SFSpeechAudioBufferRecognitionRequest?
    private var currentFile: AVAudioFile?

    var request: SFSpeechAudioBufferRecognitionRequest? {
        get { lock.lock(); defer { lock.unlock() }; return currentRequest }
        set { lock.lock(); defer { lock.unlock() }; currentRequest = newValue }
    }

    var file: AVAudioFile? {
        get { lock.lock(); defer { lock.unlock() }; return currentFile }
        set { lock.lock(); defer { lock.unlock() }; currentFile = newValue }
    }

    func consume(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let request = currentRequest
        let file = currentFile
        lock.unlock()
        request?.append(buffer)
        try? file?.write(from: buffer)
    }
}

enum RecognizerError: LocalizedError {
    case permissionDenied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "沒有麥克風或語音辨識權限，請到「設定」開啟。"
        case .unavailable: return "這個語言的語音辨識目前無法使用。"
        }
    }
}

/// Apple Speech 即時辨識，同時把這段錄音存成 m4a，停止後可以送雲端重新辨識（中英夾雜）。
/// 會自動在一段結束後重新開始，所以可以連續講很久。
@MainActor
final class SpeechRecognizer: ObservableObject {
    enum State: Equatable {
        case idle
        case listening
        case stopping
        case error(String)
    }

    @Published private(set) var state: State = .idle
    /// 已經確定的文字。
    @Published private(set) var committedText: String = ""
    /// 正在講、還會變動的那一段。
    @Published private(set) var partialText: String = ""
    @Published private(set) var isOnDevice = false
    /// 最近一次錄音的檔案（停止後才完整）。
    @Published private(set) var lastRecordingURL: URL?

    var liveText: String {
        if committedText.isEmpty { return partialText }
        if partialText.isEmpty { return committedText }
        return committedText + joiner + partialText
    }

    var isListening: Bool {
        if case .listening = state { return true }
        return false
    }

    private let audioEngine = AVAudioEngine()
    private let sink = AudioSinkBox()
    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?
    private var currentTaskID = UUID()
    private var consecutiveErrors = 0
    /// 這次按下錄音之前已經有的文字；雲端重辨識只會換掉這次錄的部分。
    private var sessionStartText = ""

    private var localeID = "zh-TW"
    private var preferOnDevice = true
    private var contextualStrings: [String] = []

    private var joiner: String {
        localeID.hasPrefix("zh") || localeID.hasPrefix("ja") ? "" : " "
    }

    func configure(localeIdentifier: String, preferOnDevice: Bool, contextualStrings: [String]) {
        localeID = localeIdentifier
        self.preferOnDevice = preferOnDevice
        self.contextualStrings = contextualStrings
        if recognizer?.locale.identifier != localeIdentifier {
            recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
        }
    }

    func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speech == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    func start() throws {
        if isListening { return }
        if case .stopping = state { return }

        if recognizer == nil {
            recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID))
        }
        guard let recognizer, recognizer.isAvailable else {
            state = .error(RecognizerError.unavailable.localizedDescription)
            throw RecognizerError.unavailable
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // 這段錄音存成 m4a，給雲端重辨識用。
        discardRecording()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("voicenote-\(UUID().uuidString).m4a")
        let fileSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        sink.file = try? AVAudioFile(forWriting: url, settings: fileSettings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        lastRecordingURL = sink.file == nil ? nil : url

        inputNode.removeTap(onBus: 0)
        let sink = self.sink
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            sink.consume(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()

        sessionStartText = committedText
        consecutiveErrors = 0
        state = .listening
        startRecognitionTask()
    }

    func stop() {
        guard isListening else { return }
        state = .stopping
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        sink.file = nil // 關檔，m4a 才會寫完整
        sink.request?.endAudio()

        // 最後一段的最終結果通常很快就會到；萬一沒到就用目前的內容收尾。
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self, case .stopping = self.state else { return }
            self.finishStop()
        }
    }

    /// 用雲端辨識的結果換掉「這次錄音」辨識出來的文字；之前已經有的文字不動。
    func replaceCurrentSessionText(with text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        committedText = sessionStartText.isEmpty ? cleaned : sessionStartText + joiner + cleaned
        partialText = ""
    }

    /// 清掉已辨識的文字（儲存筆記之後呼叫）。
    func reset() {
        if isListening { stop() }
        committedText = ""
        partialText = ""
        sessionStartText = ""
        discardRecording()
        if case .error = state { state = .idle }
    }

    // MARK: - Private

    private func discardRecording() {
        if let url = lastRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        lastRecordingURL = nil
    }

    private func startRecognitionTask() {
        guard let recognizer else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.addsPunctuation = true
        request.contextualStrings = contextualStrings
        let onDevice = preferOnDevice && recognizer.supportsOnDeviceRecognition
        request.requiresOnDeviceRecognition = onDevice
        isOnDevice = onDevice
        sink.request = request

        let taskID = UUID()
        currentTaskID = taskID
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let errorDescription = error?.localizedDescription
            Task { @MainActor [weak self] in
                self?.handle(taskID: taskID, text: text, isFinal: isFinal, errorDescription: errorDescription)
            }
        }
    }

    private func handle(taskID: UUID, text: String?, isFinal: Bool, errorDescription: String?) {
        guard taskID == currentTaskID else { return }

        if let text, !text.isEmpty {
            partialText = text
            consecutiveErrors = 0
        }

        if isFinal {
            commitPartial()
            switch state {
            case .listening: startRecognitionTask()
            case .stopping: finishStop()
            default: break
            }
            return
        }

        guard errorDescription != nil else { return }
        switch state {
        case .listening:
            // 伺服器辨識大約一分鐘會結束一段、或是太久沒講話；直接重新開一段。
            commitPartial()
            consecutiveErrors += 1
            if consecutiveErrors > 3 {
                audioEngine.stop()
                audioEngine.inputNode.removeTap(onBus: 0)
                sink.file = nil
                sink.request = nil
                task = nil
                state = .error("語音辨識一直失敗，請確認網路或稍後再試。")
            } else {
                startRecognitionTask()
            }
        case .stopping:
            commitPartial()
            finishStop()
        default:
            break
        }
    }

    private func commitPartial() {
        guard !partialText.isEmpty else { return }
        committedText = committedText.isEmpty ? partialText : committedText + joiner + partialText
        partialText = ""
    }

    private func finishStop() {
        commitPartial()
        task?.cancel()
        task = nil
        sink.request = nil
        state = .idle
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
