import SwiftUI

struct PeekWatcherView: View {
    @StateObject var session = PeekSessionModel()
    @State private var navigateToSplash = false
    let requestId: String

    var body: some View {
        NavigationStack {
            VStack {
                if navigateToSplash {
                    NavigationLink("", destination: PeekSplashView(session: session), isActive: $navigateToSplash)
                } else {
                    Text("Waiting for someone to Peek…")
                        .font(.title2)
                        .padding()
                        .onAppear {
                            session.startListening(requestId: requestId)
                        }
                        .onChange(of: session.status) { newStatus in
                            if newStatus == "accepted" {
                                navigateToSplash = true
                            }
                        }
                }
            }
        }
    }
}
