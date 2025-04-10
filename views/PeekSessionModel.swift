import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

class PeekSessionModel: ObservableObject {
    @Published var status: String = "pending"
    @Published var imageUrl: String? = nil
    @Published var displayDuration: Int = 5

    private var listener: ListenerRegistration?

    func listen(to requestId: String) {
        print("🟢 Listening to Firestore document: \(requestId)")
        let db = Firestore.firestore()
        listener = db.collection("peek_requests").document(requestId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let data = snapshot?.data() else {
                    print("❌ No data or error: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }

                self.status = data["status"] as? String ?? "pending"
                self.imageUrl = data["imageUrl"] as? String
                self.displayDuration = data["displayDuration"] as? Int ?? 5

                print("📡 Firestore updated → status: \(self.status)")
            }
    }

    func stopListening() {
        listener?.remove()
    }
}
