import SwiftUI
import VoiceNoteCore

struct NoteDetailView: View {
    @EnvironmentObject private var notes: NoteStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var dictionary: DictionaryStore
    @Environment(\.dismiss) private var dismiss

    let noteID: UUID

    @State private var showingRaw = false
    @State private var isRunningAI = false
    @State private var errorMessage: String?
    @State private var copied = false
    @State private var confirmDelete = false

    private var note: Note? { notes.note(id: noteID) }

    var body: some View {
        Group {
            if let note {
                content(note)
            } else {
                ContentUnavailableView("這則筆記已刪除", systemImage: "trash")
            }
        }
        .navigationTitle(note?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .alert("出錯了", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog("刪除這則筆記？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("刪除", role: .destructive) {
                notes.delete(id: noteID)
                dismiss()
            }
        }
    }

    private func content(_ note: Note) -> some View {
        let displayed = showingRaw ? note.rawText : note.processedText
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("顯示", selection: $showingRaw) {
                    Text("整理後（\(note.mode.title)）").tag(false)
                    Text("原文").tag(true)
                }
                .pickerStyle(.segmented)

                Text(displayed)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = displayed
                        withAnimation { copied = true }
                        Task {
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            withAnimation { copied = false }
                        }
                    } label: {
                        Label(copied ? "已複製" : "複製", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    ShareLink(item: displayed) {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                    Spacer()
                }
                .buttonStyle(.bordered)

                if !showingRaw, !note.changes.isEmpty {
                    ChangesList(changes: note.changes)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("重新整理（原文不會動）").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Button {
                            let result = TextPipeline.process(note.rawText, dictionary: dictionary.entries, options: settings.processingOptions)
                            notes.updateProcessed(id: noteID, text: result.text, mode: .light, changes: result.changes)
                            showingRaw = false
                        } label: {
                            Label("本機規則", systemImage: "arrow.clockwise")
                        }
                        if settings.hasAPIKey {
                            Button { Task { await runAI(note) } } label: {
                                if isRunningAI { ProgressView() } else { Label("Claude", systemImage: "sparkles") }
                            }
                            .disabled(isRunningAI)
                        }
                    }
                    .buttonStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("建立：\(note.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    if note.updatedAt.timeIntervalSince(note.createdAt) > 1 {
                        Text("整理更新：\(note.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("刪除筆記", systemImage: "trash")
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }

    private func runAI(_ note: Note) async {
        isRunningAI = true
        defer { isRunningAI = false }
        let local = TextPipeline.process(note.rawText, dictionary: dictionary.entries, options: settings.processingOptions)
        let structurer = ClaudeStructurer(apiKey: settings.apiKey, model: settings.aiModel)
        do {
            let text = try await structurer.structure(text: local.text, dictionary: dictionary.entries, removeFillers: settings.removeFillers)
            notes.updateProcessed(id: noteID, text: text, mode: .ai, changes: local.changes)
            showingRaw = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
