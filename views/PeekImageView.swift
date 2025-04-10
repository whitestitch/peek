import SwiftUI

struct PeekImageView: View {
    @ObservedObject var viewModel: PeekViewModel
    @State private var goHome = false

    var body: some View {
        NavigationStack {
            if goHome {
                HomeView()
            } else {
                VStack {
                    if let imageUrl = viewModel.imageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit()
                            case .failure:
                                Text("❌ Failed to load image")
                            default:
                                ProgressView()
                            }
                        }
                    } else {
                        Text("No image available.")
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(viewModel.displayDuration)) {
                        goHome = true
                    }
                }
            }
        }
    }
}
