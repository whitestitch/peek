// lib/core/firestore_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:flutter/foundation.dart';
import 'package:peek/main.dart';

// DEBUG
// DEBUG
// DEBUG
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  // Pass the ref to the service so it can read other providers
  return FirestoreService(
      ref, FirebaseFirestore.instance, FirebaseAuth.instance);
});
// END DEBUG
// END DEBUG
// END DEBUG

// LIVE
// LIVE
// LIVE
// --- Riverpod Provider for the Service ---
// final firestoreServiceProvider = Provider<FirestoreService>((ref) {
//   return FirestoreService(FirebaseFirestore.instance, FirebaseAuth.instance);
// });

// END LIVE
// END LIVE
// END LIVE
// --- End Provider ---

class FirestoreService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  // DEBUG
  // DEBUG
  // DEBUG
  final Ref _ref;
  // END DEBUG
// END DEBUG
// END DEBUG

// DEBUG
  // DEBUG
  // DEBUG
  FirestoreService(this._ref, this._db, this._auth); // Update this line
  // END DEBUG
  // END DEBUG
  // END DEBUG

  // LIVE
// LIVE
// LIVE
  // FirestoreService(this._db, this._auth);
  // END LIVE
// END LIVE
// END LIVE

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

  // --- SPACE

  /// ✅ NEW: Creates a temporary document to trigger a real-time event on the sender's device.
  Future<void> triggerReactionEvent({
    required String targetUserId,
    required String reactionType, // "like", "dislike", etc.
    required String peekRequestId,
  }) async {
    // Server (onReactionCreated) writes the sender’s reaction event.
    debugPrint(
        "[FirestoreService] triggerReactionEvent: handled server-side; no-op.");
    return;
  }

  Future<void> incrementLikesReceived(String targetUserId) async {
    debugPrint(
        "[FirestoreService] incrementLikesReceived: handled server-side; no-op.");
    return;
  }
// --- SPACE

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

  /// Updates or saves the FCM token for the current user
  Future<void> updateFCMToken(String token) async {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint(
          "[FirestoreService] Cannot update FCM token: User not authenticated");
      throw Exception("User not authenticated.");
    }

    try {
      await updateUserPreference({'fcmToken': token});
      debugPrint(
          "[FirestoreService] FCM token updated successfully for user: $userId");
    } catch (e) {
      debugPrint("[FirestoreService] Error updating FCM token: $e");
      rethrow;
    }
  }

  /// Gets the current user's FCM token
  Future<String?> getFCMToken() async {
    final userDoc = await getCurrentUserDocument();
    if (userDoc?.exists == true) {
      final data = userDoc!.data();
      return data?['fcmToken'] as String?;
    }
    return null;
  }

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
  Future<String?> ensureDisplayNameExists({required String userId}) async {
    final userDocRef = _db.collection('users').doc(userId);

    try {
      String? ensuredName;

      // 1) Non-destructive write to avoid a read before the doc exists.
      //    If the doc exists and we have write permission, this just bumps updatedAt.
      //    If it doesn't exist, update() will throw 'not-found' which we handle below.
      try {
        await userDocRef.update({
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint(
            "[FirestoreService] User doc exists for $userId (updated timestamp).");
        // We intentionally skip reading displayName here to avoid read-permission issues on some rulesets.
      } on FirebaseException catch (fe) {
        if (fe.code == 'not-found' ||
            fe.code == 'failed-precondition' ||
            fe.code == 'permission-denied') {
          // 2) Create (or upsert) the doc without doing a prior get().
          ensuredName = _generateNickname();
          debugPrint(
              "[FirestoreService] Creating user doc for $userId (reason: ${fe.code}) with name: $ensuredName");
          await userDocRef.set(
              {
                'uid': userId,
                'displayName': ensuredName,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
                'isPremium': false,
                // Initial defaults
                'likesReceivedCount': 0,
                'dislikesReceivedCount': 0,
                'dailyPeekCount': 0,
                'peekCountLastReset': null,
                'lastPeekRequestTimestamp': null,
                'blockedSenderIds': [],
                'shareLocationPreference': false,
                'seeOthersLocationPreference': false,
              },
              SetOptions(
                  merge: true)); // merge so we never clobber an existing doc
          debugPrint("✅ User document created/merged for $userId");
        } else {
          rethrow; // Bubble up unknown write errors
        }
      }

      // We don't read back here to avoid rules that forbid reads pre-existence or without specific fields.
      return ensuredName; // null means doc already existed; non-null means we created one.
    } catch (e, stack) {
      debugPrint("❌ Error in ensureDisplayNameExists for user $userId: $e");
      debugPrint("Stack trace: $stack");
      return null;
    }
  }

  /// Increments the 'dislikesReceivedCount' for the specified user.
  /// [targetUserId] is the ID of the user whose peek received a dislike.
  Future<void> incrementDislikesReceived(String targetUserId) async {
    debugPrint(
        "[FirestoreService] incrementDislikesReceived: handled server-side; no-op.");
    return;
  }

  /// This is the trigger that the waiting sender will listen for.
  Future<void> addReactionToPeek(String requestId, String reactionType) async {
    if (requestId.isEmpty || reactionType.isEmpty) {
      debugPrint(
          "❌ [FirestoreService] addReactionToPeek: a parameter is empty.");
      return;
    }
    final reactorUid = _auth.currentUser?.uid;
    if (reactorUid == null) {
      debugPrint(
          "❌ [FirestoreService] addReactionToPeek: no authenticated user.");
      return;
    }
    final reactionRef = _db
        .collection('peek_requests')
        .doc(requestId)
        .collection('reactions')
        .doc(reactorUid);
    try {
      await reactionRef.set({
        'type': reactionType.toLowerCase(), // "like" | "dislike"
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint(
          "[FirestoreService] Reaction '$reactionType' created for $requestId by $reactorUid.");
    } catch (e) {
      debugPrint(
          "❌ [FirestoreService] Error creating reaction for $requestId: $e");
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
