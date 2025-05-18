// lib/core/firestore_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:flutter/foundation.dart';

// --- Riverpod Provider for the Service ---
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(FirebaseFirestore.instance, FirebaseAuth.instance);
});
// --- End Provider ---

class FirestoreService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  // Modified constructor to accept instances
  FirestoreService(this._db, this._auth);

  String? get _currentUserId => _auth.currentUser?.uid;

  // Example lists - expand these significantly for more variety!
  static const List<String> _adjectives = [
    "Agile",
    "Azure",
    "Brave",
    "Bright",
    "Zenith"
  ];
  static const List<String> _nouns = [
    "Albatross",
    "Antelope",
    "Apex",
    "Asteroid",
    "Aurora",
    "Zircon"
  ];

  // --- Existing Notes Methods (Exactly as you provided) ---
  Future<void> addNote(String text) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("[FirestoreService] Error adding note: User not logged in.");
      return;
    }

    await _db.collection('notes').add({
      'uid': user.uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> getUserNotes() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("[FirestoreService] Error getting notes: User not logged in.");
      return const Stream.empty();
    }

    return _db
        .collection('notes')
        .where('uid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
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

  /// Returns null if the user is not authenticated or the document doesn't exist.
  Future<DocumentSnapshot<Map<String, dynamic>>?>
      getCurrentUserDocument() async {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint(
          "[FirestoreService] Error: User not authenticated. Cannot fetch user document.");
      return null;
    }
    try {
      final docRef = _db.collection('users').doc(userId);
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        // Explicitly cast to the expected type for safety.
        return docSnap as DocumentSnapshot<Map<String, dynamic>>;
      } else {
        debugPrint(
            "[FirestoreService] Info: User document for $userId does not exist.");
        return null; // It's valid for a document to not exist (e.g., new user).
      }
    } catch (e) {
      debugPrint(
          "[FirestoreService] Error fetching user document for $userId: $e");
      return null;
    }
  }

  /// [data] is a Map of fields to update, e.g., {'fieldName': newValue}
  Future<void> updateUserPreference(Map<String, dynamic> data) async {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint(
          "[FirestoreService] Error: User not authenticated. Cannot update preference.");
      throw Exception("User not authenticated.");
    }
    try {
      final userDocRef = _db.collection('users').doc(userId);
      await userDocRef.set(data, SetOptions(merge: true));
      debugPrint(
          "[FirestoreService] User preference updated successfully for $userId: $data");
    } catch (e) {
      debugPrint(
          "[FirestoreService] Error updating user preference for $userId: $e");
      rethrow;
    }
  }

  /// Generates a random nickname.
  String _generateNickname() {
    final random = Random();
    final adjective = _adjectives[random.nextInt(_adjectives.length)];
    final noun = _nouns[random.nextInt(_nouns.length)];
    // Optional: Add random numbers for more uniqueness if needed
    // final number = random.nextInt(99); // e.g., 0-98
    // return "$adjective$noun$number";
    return "$adjective $noun"; // Added space for readability
  }

  /// Ensures the current user has a displayName in their Firestore document.
  /// If the document exists but displayName is missing/empty, it generates and saves one.
  /// If the document doesn't exist, it creates it with essential fields including a generated name.
  /// Returns the ensured display name (or null if user is not logged in).
  /// IMPORTANT: Call this method during your user creation/first login flow.
  Future<String?> ensureDisplayNameExists() async {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint(
          "[FirestoreService] ensureDisplayNameExists: User not logged in.");
      return null;
    }

    final userDocRef = _db.collection('users').doc(userId);
    String? finalDisplayName;

    try {
      // Use a transaction to handle potential race conditions if called multiple times quickly
      // and to ensure atomicity when creating/updating the document.
      await _db.runTransaction((transaction) async {
        final docSnap = await transaction.get(userDocRef);

        if (docSnap.exists) {
          // Document exists, check for displayName
          final data = docSnap.data() as Map<String, dynamic>?;
          final currentName = data?['displayName'] as String?;

          if (currentName == null || currentName.trim().isEmpty) {
            // DisplayName is missing or empty, generate and update
            finalDisplayName = _generateNickname();
            debugPrint(
                "[FirestoreService] ensureDisplayNameExists: User $userId exists but has no displayName. Generating: $finalDisplayName");
            // Use transaction.set with merge:true to update within the transaction
            transaction.set(userDocRef, {'displayName': finalDisplayName},
                SetOptions(merge: true));
          } else {
            // DisplayName already exists
            finalDisplayName = currentName;
            debugPrint(
                "[FirestoreService] ensureDisplayNameExists: User $userId already has displayName: $finalDisplayName");
          }
          // ====================================
          // CODE CHANGE START (Ensure reaction count fields exist for existing users if displayName was updated)
          // This part is optional but good for consistency if ensureDisplayNameExists is called for existing users often.
          // However, FieldValue.increment(1) will create the field if it's missing.
          // For true consistency upon ensuring display name, one might add:
          // Map<String, dynamic> updatesForExistingUser = {};
          // if (data?['likesReceivedCount'] == null) {
          //   updatesForExistingUser['likesReceivedCount'] = 0;
          // }
          // if (data?['dislikesReceivedCount'] == null) {
          //   updatesForExistingUser['dislikesReceivedCount'] = 0;
          // }
          // if (updatesForExistingUser.isNotEmpty) {
          //   transaction.set(userDocRef, updatesForExistingUser, SetOptions(merge: true));
          // }
          // For MVP, relying on FieldValue.increment creating the field is simpler.
          // The main addition is for *new* users below.
          // ====================================
          // CODE CHANGE END
          // ====================================
        } else {
          // Document does not exist, create it with generated name and defaults
          finalDisplayName = _generateNickname();
          debugPrint(
              "[FirestoreService] ensureDisplayNameExists: User document for $userId does not exist. Creating with generated name: $finalDisplayName");

          // Use transaction.set to create the document within the transaction
          transaction.set(userDocRef, {
            'uid': userId,
            'displayName': finalDisplayName,
            'createdAt': FieldValue.serverTimestamp(),
            'isPremium': false,
            'shareLocationPreference': false,
            'seeOthersLocationPreference': false,
            'likesReceivedCount': 0, // Initialize likes received
            'dislikesReceivedCount': 0, // Initialize dislikes received
            // Add any other essential default fields for a new user
          });
        }
      });

      // After transaction completes successfully, return the name
      // Note: finalDisplayName is assigned within the transaction scope,
      // but its value persists after the transaction completes.
      return finalDisplayName;
    } catch (e) {
      debugPrint(
          "❌ [FirestoreService] Error in ensureDisplayNameExists transaction for $userId: $e");
      return null; // Return null on error
    }
  }

  Future<void> incrementLikesReceived(String targetUserId) async {
    if (targetUserId.isEmpty) {
      debugPrint(
          "❌ [FirestoreService] incrementLikesReceived: targetUserId is empty.");
      return; // Or throw an error
    }
    final userDocRef = _db.collection('users').doc(targetUserId);
    try {
      await userDocRef.update({
        'likesReceivedCount': FieldValue.increment(1),
      });
      debugPrint(
          "[FirestoreService] Likes received incremented for user $targetUserId.");
    } catch (e) {
      debugPrint(
          "❌ [FirestoreService] Error incrementing likes received for user $targetUserId: $e");
      // Decide if rethrow is needed or just log
    }
  }

  /// Increments the 'dislikesReceivedCount' for the specified user.
  /// [targetUserId] is the ID of the user whose peek received a dislike.
  Future<void> incrementDislikesReceived(String targetUserId) async {
    if (targetUserId.isEmpty) {
      debugPrint(
          "❌ [FirestoreService] incrementDislikesReceived: targetUserId is empty.");
      return; // Or throw an error
    }
    final userDocRef = _db.collection('users').doc(targetUserId);
    try {
      await userDocRef.update({
        'dislikesReceivedCount': FieldValue.increment(1),
      });
      debugPrint(
          "[FirestoreService] Dislikes received incremented for user $targetUserId.");
    } catch (e) {
      debugPrint(
          "❌ [FirestoreService] Error incrementing dislikes received for user $targetUserId: $e");
      // Decide if rethrow is needed or just log
    }
  }

  /// Adds a report for objectionable content to the 'reports' collection.
  Future<void> addReport({
    required String peekRequestId,
    required String reportedImageUrl,
    required String reportedSenderId,
    required String reporterId,
    String reason = "objectionable_content",
  }) async {
    try {
      await _db.collection('reports').add({
        'peekRequestId': peekRequestId,
        'reportedImageUrl': reportedImageUrl,
        'reportedSenderId': reportedSenderId,
        'reporterId': reporterId,
        'reason': reason,
        'reportTimestamp': FieldValue.serverTimestamp(),
        'status': 'pending_review',
      });
      debugPrint(
          "[FirestoreService] Report added successfully for peek: $peekRequestId by $reporterId");
    } catch (e) {
      debugPrint("[FirestoreService] Error adding report: $e");
      throw Exception("Failed to submit report. Please try again.");
    }
  }
  // --- End NEW Method ---

  /// Blocks a user by adding their UID to the current user's 'blockedSenderIds' list.
  Future<void> blockUser({
    required String byUserId,
    required String userIdToBlock,
  }) async {
    if (byUserId == userIdToBlock) {
      debugPrint("[FirestoreService] User cannot block themselves.");
      return;
    }
    try {
      final userDocRef = _db.collection('users').doc(byUserId);
      await userDocRef.update({
        'blockedSenderIds': FieldValue.arrayUnion([userIdToBlock]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
          "[FirestoreService] User $userIdToBlock blocked by $byUserId successfully.");
    } catch (e) {
      debugPrint(
          "[FirestoreService] Error blocking user $userIdToBlock for $byUserId: $e");
      throw Exception("Failed to block sender. Please try again.");
    }
  }
}
