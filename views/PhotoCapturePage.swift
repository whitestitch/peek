import FirebaseStorage
import FirebaseFirestore

func sendPhoto(requestId: String, image: URL) {
    isUploading = true

    let uid = Auth.auth().currentUser?.uid ?? "anonymous"
    let fileName = "peeks/\(uid)/\(Date().millisecondsSinceEpoch).jpg"
    let ref = Storage.storage().reference().child(fileName)

    print("📤 Uploading photo to path: \(fileName)")

    let uploadTask = ref.putFile(from: image, metadata: nil)

    uploadTask.observe(.success) { snapshot in
        // ✅ File uploaded successfully
        ref.downloadURL { url, error in
            if let error = error {
                print("❌ Failed to get downloadURL: \(error.localizedDescription)")
                isUploading = false
                return
            }

            guard let downloadURL = url else {
                print("❌ downloadURL is nil")
                isUploading = false
                return
            }

            print("✅ Got image URL: \(downloadURL.absoluteString)")

            // Save URL to Firestore
            Firestore.firestore().collection("peek_requests")
                .document(requestId)
                .updateData([
                    "imageUrl": downloadURL.absoluteString
                ]) { error in
                    if let error = error {
                        print("❌ Failed to update Firestore: \(error.localizedDescription)")
                    } else {
                        print("✅ Firestore updated with imageUrl.")
                    }

                    isUploading = false
                    goHome()
                }
        }
    }

    uploadTask.observe(.failure) { snapshot in
        if let error = snapshot.error {
            print("❌ Upload failed: \(error.localizedDescription)")
        }
        isUploading = false
    }
}
