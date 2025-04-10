import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

class PeekViewModel: ObservableObject {
    @Published var status: String = "pending"
    @Published var imageUrl: String? = nil
    @Published var displayDuration: Int = 5
    @Published var navigateToSplash = false

    private let peekDocumentID: String
    private var listener: ListenerRegistration?

    init(peekDocumentID: String) {
        self.peekDocumentID = peekDocumentID
        startListening()
    }

    func startListening() {
        let db = Firestore.firestore()
        print("🟢 Listening to document ID: \(peekDocumentID)")

        listener = db.collection("peek_requests").document(peekDocumentID)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let data = snapshot?.data() else {
                    print("❌ Firestore error or missing data: \(error?.localizedDescription ?? "Unknown")")
                    return
                }

                self.status = data["status"] as? String ?? "pending"
                self.imageUrl = data["imageUrl"] as? String
                self.displayDuration = data["displayDuration"] as? Int ?? 5

                print("📡 Status updated to: \(self.status)")

                if self.status == "accepted" {
                    DispatchQueue.main.async {
                        self.navigateToSplash = true
                    }
                }
            }
    }

    func acceptPeek() {
        let db = Firestore.firestore()
        db.collection("peek_requests").document(peekDocumentID).updateData([
            "status": "accepted",
            "respondedAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("❌ Failed to accept peek: \(error.localizedDescription)")
            } else {
                print("✅ Peek accepted.")
            }
        }
    }

    deinit {
        listener?.remove()
    }
}
