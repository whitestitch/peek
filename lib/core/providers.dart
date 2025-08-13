// lib/core/providers.dart
import 'dart:async'; // Import async
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peek/core/firestore_service.dart';

// This provider streams the auth state and is the single source of truth for the user's UID.
final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

final userDocumentProvider =
    StreamProvider<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;

  if (user == null) {
    debugPrint("[userDocumentProvider] No user, returning null stream.");
    return Stream.value(null);
  }

  // Create a controller to manage the stream. This allows us to perform an async
  // action (ensureDisplayNameExists) before we start listening to Firestore.
  final controller =
      StreamController<DocumentSnapshot<Map<String, dynamic>>?>();

  // If you prefer to keep autoDispose, add:
  final link = ref.keepAlive();
  ref.onDispose(() {
    link.close();
    controller.close();
  });
// (With non-autoDispose, just close the controller:)
  // ref.onDispose(controller.close);

  Future<void> initializeAndListen() async {
    try {
      // Step 1: Ensure the document exists BEFORE listening. This is the key fix.
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.ensureDisplayNameExists(userId: user.uid);
      debugPrint(
          "[userDocumentProvider] Document creation/verification complete for ${user.uid}.");

      // Step 2: Now that we know the doc exists, listen for real-time changes.
      final stream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots();

      // Pipe the Firestore stream into our controller.
      controller.addStream(stream);
    } catch (e, stack) {
      debugPrint("❌ [userDocumentProvider] Error during initialization: $e");
      debugPrintStack(stackTrace: stack);
      controller.addError(e, stack);
    }
  }

  initializeAndListen();

  // Return the controller's stream. Riverpod will manage its lifecycle.
  return controller.stream;
});
