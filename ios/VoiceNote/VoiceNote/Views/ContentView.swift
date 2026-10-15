import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            RecordView()
                .tabItem { Label("錄音", systemImage: "mic.fill") }
            NoteListView()
                .tabItem { Label("筆記", systemImage: "note.text") }
            DictionaryView()
                .tabItem { Label("字典", systemImage: "character.book.closed") }
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
    }
}
