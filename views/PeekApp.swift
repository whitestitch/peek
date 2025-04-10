import SwiftUI
import Firebase

@main
struct PeekApp: App {
    init() {
        FirebaseApp.configure()
        print("🔥 Firebase Initialized")
    }

    var body: some Scene {
        WindowGroup {
            // 🔑 Inject the dynamic document ID here
            ContentView(peekDocumentID: "UUctoDrMqMzjMrMvQbE8")
        }
    }
}
