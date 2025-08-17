import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:peek/theme/colors.dart';
import 'package:peek/features/peek/providers/peek_providers.dart';
import 'package:peek/core/router.dart';

/// Manages peek request dialog display and user interactions
class PeekDialogManager {
  final GlobalKey<NavigatorState> navigatorKey;
  final WidgetRef ref;

  PeekDialogManager({
    required this.navigatorKey,
    required this.ref,
  });

  /// Show peek request dialog
  void showPeekRequestDialog(
      QueryDocumentSnapshot<Map<String, dynamic>> requestDoc) {
    final requestId = requestDoc.id;

    // Set active dialog provider
    ref.read(activePeekRequestDialogProvider.notifier).state = requestId;

    showDialog<void>(
      context: navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text(
          'New Peek Request!',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: peekWhiteColor,
            letterSpacing: 0.5,
            fontSize: 26,
          ),
        ),
        content: Text(
          'Someone wants to share a peek with you. Accept?',
          style: TextStyle(
            color: peekWhiteColor.withOpacity(1),
            height: 1.55,
            fontSize: 17,
            fontWeight: FontWeight.w400,
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: peekOnBackgroundColor.withOpacity(0.7),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _declinePeekRequest(requestId);
            },
            child: const Text('Decline'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _acceptPeekRequest(requestId);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    ).then((_) {
      // Clear provider when dialog closes
      final activeDialogId = ref.read(activePeekRequestDialogProvider);
      if (activeDialogId == requestId) {
        ref.read(activePeekRequestDialogProvider.notifier).state = null;
      }
    });
  }

  /// Accept peek request
  Future<void> _acceptPeekRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(requestId)
          .update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      ref
          .read(routerProvider)
          .go('/capture?requestId=$requestId&mode=response');
    } catch (e) {
      debugPrint('❌ Error in _acceptPeekRequest: $e');
      _showErrorSnackBar('Failed to accept peek: ${e.toString()}');
    }
  }

  /// Decline peek request
  Future<void> _declinePeekRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(requestId)
          .update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error declining peek request: $e');
      _showErrorSnackBar('Failed to decline peek: ${e.toString()}');
    }
  }

  /// Show error snackbar
  void _showErrorSnackBar(String message) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: peekErrorColor,
        ),
      );
    }
  }

  /// Handle dialog visibility based on pending requests
  void handlePendingRequests(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> requests) {
    final requestIds = requests.map((req) => req.id).toSet();
    final activeDialogId = ref.read(activePeekRequestDialogProvider);

    // Close dialog if request is no longer pending
    if (activeDialogId != null && !requestIds.contains(activeDialogId)) {
      _handleRequestStatusChange(activeDialogId);
    }

    // Show dialog for new request if no dialog is active
    if (ref.read(activePeekRequestDialogProvider) == null &&
        requests.isNotEmpty) {
      showPeekRequestDialog(requests.first);
    }
  }

  /// Handle request status change (cancelled, expired, etc.)
  Future<void> _handleRequestStatusChange(String requestId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(requestId)
          .get();

      // Close active dialog
      if (navigatorKey.currentContext != null &&
          Navigator.of(navigatorKey.currentContext!).canPop()) {
        Navigator.of(navigatorKey.currentContext!).pop();
      }
      ref.read(activePeekRequestDialogProvider.notifier).state = null;

      // Navigate if request was cancelled
      if (doc.exists && doc.data()?['status'] == 'cancelled_by_sender') {
        navigatorKey.currentContext?.go('/?show=peekCancelled');
      }
    } catch (e) {
      debugPrint('❌ Error handling request status change: $e');
    }
  }
}
