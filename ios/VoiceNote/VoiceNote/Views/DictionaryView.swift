import SwiftUI
import VoiceNoteCore

struct DictionaryView: View {
    @EnvironmentObject private var dictionary: DictionaryStore
    @State private var editing: DictionaryEntry?
    @State private var creating = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("「正確寫法」會提示語音辨識優先認出這個詞；「常見錯字」會在整理時直接換成正確寫法。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    ForEach(dictionary.entries) { entry in
                        Button { editing = entry } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.term).font(.body).foregroundStyle(.primary)
                                if !entry.aliases.isEmpty {
                                    Text("常見錯字：" + entry.aliases.joined(separator: "、"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                if !entry.note.isEmpty {
                                    Text(entry.note).font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    .onDelete { dictionary.delete(at: $0) }
                } header: {
                    Text("\(dictionary.entries.count) 個詞")
                }
            }
            .navigationTitle("字典")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { creating = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editing) { entry in
                DictionaryEntryEditor(entry: entry) { dictionary.upsert($0) }
            }
            .sheet(isPresented: $creating) {
                DictionaryEntryEditor(entry: DictionaryEntry(term: "")) { dictionary.upsert($0) }
            }
        }
    }
}

struct DictionaryEntryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var term: String
    @State private var aliasesText: String
    @State private var note: String
    private let id: UUID
    private let onSave: (DictionaryEntry) -> Void

    init(entry: DictionaryEntry, onSave: @escaping (DictionaryEntry) -> Void) {
        id = entry.id
        _term = State(initialValue: entry.term)
        _aliasesText = State(initialValue: entry.aliases.joined(separator: "、"))
        _note = State(initialValue: entry.note)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("正確寫法") {
                    TextField("例：Typeless", text: $term)
                        .autocorrectionDisabled()
                }
                Section {
                    TextField("例：type less、泰普勒斯", text: $aliasesText, axis: .vertical)
                        .autocorrectionDisabled()
                } header: {
                    Text("常見錯字（用「、」或逗號分隔）")
                } footer: {
                    Text("先錄幾次看看辨識把它寫成什麼，再把那些寫法填進來。")
                }
                Section("備註") {
                    TextField("選填", text: $note)
                }
            }
            .navigationTitle(term.isEmpty ? "新增詞" : term)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        let aliases = aliasesText
                            .components(separatedBy: CharacterSet(charactersIn: "、，,\n"))
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        onSave(DictionaryEntry(id: id, term: term, aliases: aliases, note: note))
                        dismiss()
                    }
                    .disabled(term.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
