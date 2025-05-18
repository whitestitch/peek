// 📁 lib/features/peek/providers/peek_providers.dart

import 'package:flutter/material.dart'; // Added for GlobalKey
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/peek_repository.dart';

// Import your ACTUAL OverlayAnimationService.
// Ensure the path is correct based on your file structure.
// This should point to the file created with ID: overlay_animation_service_dart_marked_changes
import '../../../core/overlay_animation_service.dart';

/// ✅ Provider for PeekRepository, injecting Firestore and FirebaseAuth
final peekRepositoryProvider = Provider<PeekRepository>((ref) {
  return PeekRepository(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );
});

final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
  throw UnimplementedError(
      "navigatorKeyProvider must be overridden in ProviderScope with the actual GlobalKey<NavigatorState> instance from your MaterialApp.");
});

// 2. Provider for the current authenticated user's document stream (real-time updates)
final userProfileStreamProvider =
    StreamProvider.autoDispose<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) {
    debugPrint(
        "[UserProfileStreamProvider] No authenticated user. Returning null stream.");
    return Stream.value(null);
  }
  debugPrint(
      "[UserProfileStreamProvider] Listening to user document: users/$userId");
  return FirebaseFirestore.instance.collection('users').doc(userId).snapshots();
});

// 3. Provider to store the last known reaction counts for the current user
final lastReactionCountsProvider =
    StateProvider<({int likes, int dislikes})>((ref) {
  return (likes: -1, dislikes: -1);
});

// 4. Provider for the OverlayAnimationService
// This now uses the imported OverlayAnimationService.
final overlayAnimationServiceProvider =
    Provider<OverlayAnimationService>((ref) {
  // The actual OverlayAnimationService constructor takes Ref
  return OverlayAnimationService(ref);
});
