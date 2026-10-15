import SwiftUI

struct NoteListView: View {
    @EnvironmentObject private var notes: NoteStore

    var body: some View {
        NavigationStack {
            Group {
                if notes.notes.isEmpty {
                    ContentUnavailableView("還沒有筆記", systemImage: "note.text", description: Text("到「錄音」頁講幾句話，儲存後會出現在這裡。"))
                } else {
                    List {
                        ForEach(notes.notes) { note in
                            NavigationLink(value: note.id) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.title).font(.body)
                                    HStack(spacing: 8) {
                                        Text(note.createdAt, format: .dateTime.month().day().hour().minute())
                                        Text(note.mode.title)
                                            .padding(.horizontal, 6).padding(.vertical, 1)
                                            .background(Color(.tertiarySystemFill), in: Capsule())
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { notes.delete(at: $0) }
                    }
                }
            }
            .navigationTitle("筆記")
            .navigationDestination(for: UUID.self) { id in
                NoteDetailView(noteID: id)
            }
        }
    }
}
