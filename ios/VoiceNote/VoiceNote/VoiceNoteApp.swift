import SwiftUI

@main
struct VoiceNoteApp: App {
    @StateObject private var noteStore = NoteStore()
    @StateObject private var dictionaryStore = DictionaryStore()
    @StateObject private var settings = AppSettings()
    @StateObject private var recognizer = SpeechRecognizer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(noteStore)
                .environmentObject(dictionaryStore)
                .environmentObject(settings)
                .environmentObject(recognizer)
        }
    }
}
