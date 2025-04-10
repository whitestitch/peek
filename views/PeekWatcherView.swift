import SwiftUI

struct PeekWatcherView: View {
    @StateObject private var session = PeekSessionModel()
    @State private var showSplash = false
    let requestId: String

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 20) {
                    Text("Waiting for someone to Peek…")
                        .font(.title2)
                        .padding()
                    ProgressView()
                }

                // Navigation trigger
                NavigationLink(
                    destination: PeekSplashView(session: session),
                    isActive: $showSplash
                ) {
                    EmptyView()
                }
            }
            .onAppear {
                print("📲 Watching for requestId: \(requestId)")
                session.listen(to: requestId)
            }
            .onChange(of: session.status) { newStatus in
                print("👂 status changed to: \(newStatus)")
                if newStatus == "accepted" {
                    DispatchQueue.main.async {
                        showSplash = true
                    }
                }
            }
        }
    }
}
