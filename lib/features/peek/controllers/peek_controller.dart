// lib/features/peek/controllers/peek_controller.dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:peek/features/home/home_page.dart'; // Import needed for userDataProvider invalidation

import '../data/peek_repository.dart';
import '../providers/peek_providers.dart';

final peekControllerProvider = AsyncNotifierProvider<PeekController, void>(
  PeekController.new,
);

class PeekController extends AsyncNotifier<void> {
  late final PeekRepository _repo;
  // *** ADDED Analytics instance ***
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  Future<void> build() async {
    _repo = ref.read(peekRepositoryProvider);
    // Initialization logic for the AsyncNotifier state remains the same
  }

  /// Creates a peek request in Firestore and updates user stats.
  /// Logs analytics events for success or failure.
  Future<String?> createPeekRequestAndUpdateStats({
    required String receiverUid,
    required bool needsDailyReset,
  }) async {
    state = const AsyncLoading(); // Indicate loading state
    final fromUserId = _repo.currentUserId;

    // Check if user is logged in
    if (fromUserId == null) {
      print('❌ [PeekController] Error: User not logged in.');
      state = AsyncError(
        'User not logged in',
        StackTrace.current,
      ); // Set error state
      // *** ADDED: Log peek creation error event (Auth) ***
      // Using await here, although could be fire-and-forget if preferred
      await _analytics.logEvent(
        name: 'peek_request_failed',
        parameters: {'reason': 'user_not_logged_in'},
      );
      // ****************************************
      return null; // Cannot create request
    }

    // Generate request details
    final requestId = const Uuid().v4();
    final now = Timestamp.now();
    final expiresAt = Timestamp.fromDate(
      now.toDate().add(const Duration(seconds: 30)), // 30-second expiry
    );

    try {
      // Call repository methods
      await _repo.createRequest(
        requestId: requestId,
        from: fromUserId,
        to: receiverUid,
        createdAt: now,
        expiresAt: expiresAt,
      );
      await _repo.updateUserPeekStats(
        fromUserId,
        needsDailyReset: needsDailyReset,
      );

      // *** ADDED: Log successful peek creation event ***
      await _analytics.logEvent(
        name: 'peek_request_created',
        parameters: {
          'request_id_partial': requestId.substring(0, 8), // Log partial ID
          // Optional: Include more context if available and useful
          // 'needs_daily_reset': needsDailyReset.toString(),
        },
      );
      // ***********************************

      state = const AsyncData(null); // Set success state
      print('✅ Peek request $requestId created and user stats updated.');
      return requestId; // Return the new request ID
    } catch (e, st) {
      print('❌ Error during peek creation/stat update: $e');
      state = AsyncError(e, st); // Set error state with stack trace

      // *** ADDED: Log general peek creation error event ***
      await _analytics.logEvent(
        name: 'peek_request_failed',
        parameters: {
          'reason': 'creation_exception',
          'requester_id_partial': fromUserId.substring(0, 8), // Partial ID
          'receiver_id_partial': receiverUid.substring(0, 8), // Partial ID
          'error': e.toString().substring(
            0,
            99 < e.toString().length ? 99 : e.toString().length,
          ), // Truncated error
        },
      );
      // ****************************************
      return null; // Indicate failure
    }
  }

  // --- expirePeek (Keep as before, analytics logging could be added here if needed) ---
  Future<void> expirePeek(String requestId) async {
    try {
      await _repo.expireRequest(requestId);
      print('[PeekController] Peek expired via controller: $requestId');
      // Optional Analytics: Log peek expiration
      // await _analytics.logEvent(name: 'peek_request_expired', parameters: {'request_id_partial': requestId.substring(0, 8)});
    } catch (e) {
      print('[PeekController] Failed to expire peek $requestId: $e');
      // Optional Analytics: Log expiration failure
      // await _analytics.logEvent(name: 'peek_request_expire_failed', parameters: {'request_id_partial': requestId.substring(0, 8), 'error': e.toString()...});
    }
  }

  // --- debugResetUserLimits (Keep as before) ---
  Future<void> debugResetUserLimits() async {
    final userId = _repo.currentUserId;
    if (userId == null) {
      print('[PeekController] DEBUG: Cannot reset limits, user is null.');
      return;
    }
    try {
      await _repo.resetUserPeekLimits(userId);
      ref.invalidate(userDataProvider); // Invalidate to refresh UI
      print('[PeekController] DEBUG: User limits reset successfully.');
    } catch (e) {
      print('[PeekController] DEBUG: Error resetting user limits: $e');
    }
  }
}
