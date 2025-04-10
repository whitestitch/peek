import SwiftUI

struct SplashScreenView: View {
    @ObservedObject var viewModel: PeekViewModel
    @State private var countdown = 3
    @State private var showImage = false

    var body: some View {
        Group {
            if showImage {
                PeekImageView(viewModel: viewModel)
            } else {
                VStack(spacing: 20) {
                    Text("⏳ Opening peek in \(countdown)...")
                        .font(.largeTitle)
                        .bold()
                    ProgressView()
                }
                .onAppear {
                    print("🎬 Splash countdown started")
                    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                        countdown -= 1
                        if countdown == 0 {
                            timer.invalidate()
                            showImage = true
                        }
                    }
                }
            }
        }
    }
}
