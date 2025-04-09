import SwiftUI

struct PeekSplashView: View {
    @ObservedObject var session: PeekSessionModel
    @State private var countdown = 3
    @State private var showImage = false

    var body: some View {
        Group {
            if showImage {
                PeekImageView(session: session)
            } else {
                VStack {
                    Text("Opening Peek in \(countdown)…")
                        .font(.largeTitle)
                        .bold()
                    ProgressView()
                        .padding()
                }
                .onAppear {
                    startCountdown()
                }
            }
        }
    }

    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            countdown -= 1
            if countdown <= 0 {
                timer.invalidate()
                showImage = true
            }
        }
    }
}
