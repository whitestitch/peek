import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

class PeekSessionModel: ObservableObject {
    @Published var status: String = "pending"
    @Published var imageUrl: String? = nil
    @Published var displayDuration: Int = 5

    private var listener: ListenerRegistration?

    func listen(to requestId: String) {
        let db = Firestore.firestore()
        listener = db.collection("peek_requests").document(requestId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let data = snapshot?.data() else { return }

                let newStatus = data["status"] as? String ?? "pending"
                if newStatus != self.status {
                    print("🔥 Firestore status changed: \(newStatus)")
                    self.status = newStatus
                }

                self.imageUrl = data["imageUrl"] as? String
                self.displayDuration = data["displayDuration"] as? Int ?? 5
            }
    }

    func stopListening() {
        listener?.remove()
    }
}
