import SwiftUI

struct ContentView: View {
    let peekDocumentID: String
    @StateObject private var viewModel: PeekViewModel

    // Custom init lets us pass peekDocumentID into the ViewModel
    init(peekDocumentID: String) {
        _viewModel = StateObject(wrappedValue: PeekViewModel(peekDocumentID: peekDocumentID))
        self.peekDocumentID = peekDocumentID
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("🔓 Waiting for peek to be accepted...")
                    .font(.headline)

                Button("YES - Accept Peek") {
                    viewModel.acceptPeek()
                }

                NavigationLink(
                    destination: SplashScreenView(viewModel: viewModel),
                    isActive: $viewModel.navigateToSplash
                ) {
                    EmptyView()
                }
            }
            .padding()
        }
    }
}
