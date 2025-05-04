// lib/core/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod

// --- Riverpod Provider for the Service ---
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});
// --- End Provider ---

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance; // Kept instance variable

  // --- Existing Notes Methods (Exactly as you provided) ---
  Future<void> addNote(String text) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('notes').add({
      'uid': user.uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> getUserNotes() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _db
        .collection('notes')
        .where('uid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => {'id': doc.id, ...doc.data()})
                  .toList(),
        );
  }
  // --- End Existing Notes Methods ---

  // --- ✨ NEW: Method to update user location preference ---
  /// Updates the location sharing preference for the current user in the /users/{uid} document.
  Future<void> updateUserLocationPreference(bool isEnabled) async {
    final user = _auth.currentUser; // Use instance variable
    if (user == null) {
      print(
        "❌ [FirestoreService] Cannot update preference: User not logged in.",
      );
      throw Exception("User not authenticated to update preference.");
    }

    final userDocRef = _db.collection('users').doc(user.uid);

    try {
      print(
        "[FirestoreService] Updating user ${user.uid} location preference to: $isEnabled",
      );
      await userDocRef.set({
        'shareLocationPreference': isEnabled,
      }, SetOptions(merge: true));
      print(
        "[FirestoreService] User location preference updated successfully.",
      );
    } catch (e) {
      print("❌ [FirestoreService] Error updating user location preference: $e");
      rethrow;
    }
  }

  // --- End NEW Method ---
}
