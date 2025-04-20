import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../data/peek_repository.dart';
import '../providers/peek_providers.dart';

final peekControllerProvider = AsyncNotifierProvider<PeekController, void>(
  PeekController.new,
);

class PeekController extends AsyncNotifier<void> {
  late final PeekRepository _repo;

  @override
  Future<void> build() async {
    _repo = ref.read(peekRepositoryProvider);
    // No initialization needed for now
  }

  /// Creates a new Peek request and returns the requestId
  Future<String?> createPeekRequest(String receiverUid) async {
    state = const AsyncLoading();

    try {
      final requestId = const Uuid().v4();
      final from = _repo.currentUserId;
      if (from == null) throw Exception("Current user is null");

      final now = Timestamp.now();
      final expiresAt = Timestamp.fromDate(
        now.toDate().add(const Duration(seconds: 30)),
      );

      await _repo.createRequest(
        requestId: requestId,
        from: from,
        to: receiverUid,
        createdAt: now,
        expiresAt: expiresAt,
      );

      state = const AsyncData(null);
      return requestId;
    } catch (e, st) {
      state = AsyncError(e, st);
      print('❌ Error creating Peek request: $e');
      return null;
    }
  }

  /// Expires an existing peek manually
  Future<void> expirePeek(String requestId) async {
    try {
      await _repo.expireRequest(requestId);
      print('[PeekController] Peek expired via controller.');
    } catch (e) {
      print('[PeekController] Failed to expire peek: $e');
    }
  }
}
