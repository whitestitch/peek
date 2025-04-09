import SwiftUI

struct PeekImageView: View {
    @ObservedObject var session: PeekSessionModel
    @State private var navigateHome = false

    var body: some View {
        NavigationStack {
            if navigateHome {
                HomeView()
            } else {
                VStack {
                    if let urlString = session.imageURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                        } placeholder: {
                            ProgressView()
                        }
                    } else {
                        Text("No image found.")
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(session.displayDuration)) {
                        navigateHome = true
                    }
                }
            }
        }
    }
}
