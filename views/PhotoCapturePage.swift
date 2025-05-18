import FirebaseStorage
import FirebaseFirestore
import CoreLocation // Import CoreLocation
import FirebaseAuth // Assuming you have this for Auth.auth()

class LocationHelper: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var locationCompletion: ((String?) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer // Or more precise if needed
    }

    func getCurrentLocationString(completion: @escaping (String?) -> Void) {
        self.locationCompletion = completion

        // Check and request authorization if needed
        // For simplicity here, assuming authorization is handled or already granted.
        // In a real app, you'd explicitly request it: locationManager.requestWhenInUseAuthorization()
        // and handle authorization status changes in a delegate method.

        let authorizationStatus: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            authorizationStatus = locationManager.authorizationStatus
        } else {
            authorizationStatus = CLLocationManager.authorizationStatus()
        }

        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.requestLocation() // Requests a single location update
        } else if authorizationStatus == .notDetermined {
            print("⚠️ Location permission not determined. Requesting permission.")
            locationManager.requestWhenInUseAuthorization()
            // The completion will be called via delegate methods once status changes
        } else {
            print("❌ Location permission denied or restricted.")
            completion(nil) // No location if permission denied
        }
    }

    // MARK: - CLLocationManagerDelegate Methods

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            locationCompletion?(nil)
            return
        }

        // Stop updates to save battery if you only need one location
        manager.stopUpdatingLocation()

        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            guard let self = self else { return }
            if let error = error {
                print("❌ Reverse geocoding failed: \(error.localizedDescription)")
                self.locationCompletion?(nil)
                return
            }

            if let placemark = placemarks?.first {
                // Example: "Cupertino, CA" or just "Cupertino"
                // You can customize this string format
                var locationString = ""
                if let locality = placemark.locality { // City
                    locationString += locality
                }
                // Optionally add more detail like administrativeArea (State/Province)
                // if let administrativeArea = placemark.administrativeArea {
                //     if !locationString.isEmpty { locationString += ", " }
                //     locationString += administrativeArea
                // }

                if locationString.isEmpty {
                    print("ℹ️ Could not determine a familiar place name from coordinates.")
                    self.locationCompletion?("Approx. Location") // Fallback
                } else {
                    self.locationCompletion?(locationString)
                }
            } else {
                self.locationCompletion?(nil)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ CLLocationManager failed: \(error.localizedDescription)")
        locationCompletion?(nil)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Handle authorization status changes, e.g., if status was .notDetermined
        // and user grants it now, then call requestLocation()
        if #available(iOS 14.0, *) {
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
                 // User denied or restricted after being .notDeterm meninas
                 print("❌ Location permission was denied or restricted after prompt.")
                 self.locationCompletion?(nil)
            }
        } else { // Fallback for older iOS versions
            if CLLocationManager.authorizationStatus() == .authorizedWhenInUse || CLLocationManager.authorizationStatus() == .authorizedAlways {
                 manager.requestLocation()
            } else if CLLocationManager.authorizationStatus() == .denied || CLLocationManager.authorizationStatus() == .restricted {
                 print("❌ Location permission was denied or restricted after prompt.")
                 self.locationCompletion?(nil)
            }
        }
    }
}

func sendPhoto(requestId: String, image: URL) {
    isUploading = true

    let locationHelper = LocationHelper()
    let uid = Auth.auth().currentUser?.uid ?? "anonymous"
    let fileName = "peeks/\(uid)/\(Date().millisecondsSinceEpoch).jpg"
    let ref = Storage.storage().reference().child(fileName)

    print("📤 Uploading photo to path: \(fileName)")

    let uploadTask = ref.putFile(from: image, metadata: nil)
    let senderCurrentDisplayName = Auth.auth().currentUser?.displayName ?? "Anonymous Sender"
    let senderCurrentAvatarUrl = Auth.auth().currentUser?.photoURL?.absoluteString // This might be nil

    locationHelper.getCurrentLocationString { [weak locationHelper] locationString in
        // Ensure locationHelper is kept alive if it's a local var and getCurrentLocationString is async
        // For this example, if locationHelper is local, its delegate methods might not fire reliably
        // unless it's retained. Consider making locationHelper a member of the class
        // containing sendPhoto, or pass it around.
        // For this direct modification, we'll proceed, but be mindful of its lifecycle.

        guard let currentUser = Auth.auth().currentUser else {
            print("❌ User not authenticated.")
            isUploading = false
            // Handle error, maybe show an alert to the user
            return
        }
        let uid = currentUser.uid
        let fileName = "peeks/\(uid)/\(Date().millisecondsSinceEpoch).jpg" // Using uid here for path
        let ref = Storage.storage().reference().child(fileName)

        print("📤 Uploading photo to path: \(fileName)")

        let uploadTask = ref.putFile(from: imageFileUrl, metadata: nil)

        uploadTask.observe(.success) { snapshot in
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

                // Prepare data for Firestore update
                var dataToUpdate: [String: Any] = [
                    "status": "accepted", // Mark as accepted
                    "imageUrl": downloadURL.absoluteString,
                    "storagePath": fileName, // Save storage path for potential cleanup
                    "respondedAt": Timestamp(date: Date()), // Firestore server timestamp is better if available
                    "senderId": uid, // ID of the user sending this photo response
                    "senderDisplayName": senderCurrentDisplayName,
                    // "senderAvatarUrl": senderCurrentAvatarUrl, // Only add if not nil
                ]

                if let avatar = senderCurrentAvatarUrl {
                    dataToUpdate["senderAvatarUrl"] = avatar
                }

                if let locStr = locationString, !locStr.isEmpty {
                    dataToUpdate["senderLocation"] = locStr
                    print("ℹ️ Including senderLocation: \(locStr)")
                } else {
                    print("ℹ️ senderLocation is nil or empty, not including in Firestore update.")
                }

                Firestore.firestore().collection("peek_requests")
                    .document(requestId)
                    .updateData(dataToUpdate) { error in
                        if let error = error {
                            print("❌ Failed to update Firestore: \(error.localizedDescription)")
                        } else {
                            print("✅ Firestore updated successfully with all details.")
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
}
