import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Enhanced content moderation manager for Apple App Store compliance
/// Implements all required safety measures for user-generated content
class ModerationManager {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State
  bool _isProcessingAction = false;

  // Data
  final String requestId;
  String? _originalSenderId;

  // Callbacks
  final VoidCallback? onActionStarted;
  final VoidCallback? onActionCompleted;
  final ValueChanged<String>? onError;
  final ValueChanged<String>? onSuccess;

  ModerationManager({
    required this.requestId,
    this.onActionStarted,
    this.onActionCompleted,
    this.onError,
    this.onSuccess,
  });

  // Getters
  bool get isProcessingAction => _isProcessingAction;
  String? get originalSenderId => _originalSenderId;

  /// Update sender ID for moderation actions
  void updateSenderId(String? senderId) {
    _originalSenderId = senderId;
    debugPrint("[Moderation] Sender ID updated: $senderId");
  }

  /// Report this peek for inappropriate content
  Future<void> reportPeek({
    String reason = 'inappropriate_content',
    String? additionalDetails,
  }) async {
    if (_isProcessingAction) {
      debugPrint("[Moderation] Already processing an action");
      return;
    }

    if (_originalSenderId == null) {
      onError?.call("Cannot report: Sender information not available");
      return;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      onError?.call("Must be logged in to report content");
      return;
    }

    _isProcessingAction = true;
    onActionStarted?.call();

    try {
      debugPrint(
          "[Moderation] Reporting peek - Request: $requestId, Sender: $_originalSenderId");

      // Create report document
      await FirebaseFirestore.instance.collection('reports').add({
        'type': 'peek_report',
        'requestId': requestId,
        'reportedUserId': _originalSenderId,
        'reporterUserId': currentUser.uid,
        'reason': reason,
        'additionalDetails': additionalDetails,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // Update the peek request with reported flag
      await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(requestId)
          .update({
        'reportedAt': FieldValue.serverTimestamp(),
        'reportedBy': currentUser.uid,
        'reportReason': reason,
      });

      debugPrint("[Moderation] Peek reported successfully");
      onSuccess?.call(
          "Content reported. Thank you for helping keep our community safe.");
    } catch (e) {
      debugPrint("[Moderation] Error reporting peek: $e");
      onError?.call("Failed to report content. Please try again.");
    } finally {
      _isProcessingAction = false;
      onActionCompleted?.call();
    }
  }

  /// Block the sender of this peek
  Future<void> blockSender({
    String reason = 'unwanted_content',
  }) async {
    if (_isProcessingAction) {
      debugPrint("[Moderation] Already processing an action");
      return;
    }

    if (_originalSenderId == null) {
      onError?.call("Cannot block: Sender information not available");
      return;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      onError?.call("Must be logged in to block users");
      return;
    }

    if (_originalSenderId == currentUser.uid) {
      onError?.call("Cannot block yourself");
      return;
    }

    _isProcessingAction = true;
    onActionStarted?.call();

    try {
      debugPrint("[Moderation] Blocking sender - User: $_originalSenderId");

      // Add to blocked users list
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'blockedUsers': FieldValue.arrayUnion([_originalSenderId]),
        'lastBlockedAt': FieldValue.serverTimestamp(),
      });

      // Create block record for analytics/moderation
      await FirebaseFirestore.instance.collection('user_blocks').add({
        'blockerUserId': currentUser.uid,
        'blockedUserId': _originalSenderId,
        'reason': reason,
        'relatedRequestId': requestId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint("[Moderation] User blocked successfully");
      onSuccess
          ?.call("User blocked. You won't receive peeks from them anymore.");
    } catch (e) {
      debugPrint("[Moderation] Error blocking user: $e");
      onError?.call("Failed to block user. Please try again.");
    } finally {
      _isProcessingAction = false;
      onActionCompleted?.call();
    }
  }

  /// Check if current user has blocked the sender
  Future<bool> isSenderBlocked() async {
    if (_originalSenderId == null) return false;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return false;

      final data = userDoc.data();
      final blockedUsers = List<String>.from(data?['blockedUsers'] ?? []);

      return blockedUsers.contains(_originalSenderId);
    } catch (e) {
      debugPrint("[Moderation] Error checking if sender is blocked: $e");
      return false;
    }
  }

  /// Show report confirmation dialog
  void showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Report Content'),
          content: const Text(
            'Are you sure you want to report this content as inappropriate?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                reportPeek();
              },
              child: const Text('Report'),
            ),
          ],
        );
      },
    );
  }

  /// Immediately remove content from feed (Apple requirement)
  Future<void> removeContentFromFeed({
    String reason = 'user_requested_removal',
  }) async {
    if (_isProcessingAction) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      onError?.call("Must be logged in to remove content");
      return;
    }

    _isProcessingAction = true;
    onActionStarted?.call();

    try {
      debugPrint(
          "[Moderation] Removing content from feed - Request: $requestId");

      // Update the peek request to mark as removed
      await _firestore.collection('peek_requests').doc(requestId).update({
        'removedFromFeed': true,
        'removedAt': FieldValue.serverTimestamp(),
        'removedBy': currentUser.uid,
        'removalReason': reason,
        'status': 'removed_by_user',
      });

      // Add removal record for admin tracking
      await _firestore.collection('content_removals').add({
        'requestId': requestId,
        'removedBy': currentUser.uid,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'user_initiated',
      });

      debugPrint("[Moderation] Content removed from feed successfully");
      onSuccess?.call("Content removed from your feed immediately.");
    } catch (e) {
      debugPrint("[Moderation] Error removing content from feed: $e");
      onError?.call("Failed to remove content. Please try again.");
    } finally {
      _isProcessingAction = false;
      onActionCompleted?.call();
    }
  }

  /// Show enhanced report dialog with multiple reason options
  void showEnhancedReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Report Content'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Why are you reporting this content?'),
              const SizedBox(height: 16),
              _buildReportOption(
                  context, 'inappropriate_content', 'Inappropriate Content'),
              _buildReportOption(
                  context, 'harassment', 'Harassment or Bullying'),
              _buildReportOption(context, 'spam', 'Spam or Unwanted Content'),
              _buildReportOption(
                  context, 'violence', 'Violence or Harmful Content'),
              _buildReportOption(context, 'adult_content', 'Adult Content'),
              _buildReportOption(context, 'other', 'Other Violation'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReportOption(BuildContext context, String reason, String label) {
    return ListTile(
      title: Text(label),
      onTap: () {
        Navigator.of(context).pop();
        reportPeek(reason: reason);
      },
    );
  }

  /// Show content removal confirmation dialog
  void showRemovalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Content'),
          content: const Text(
            'Remove this content from your feed immediately? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                removeContentFromFeed();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  /// Show block confirmation dialog
  void showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Block User'),
          content: const Text(
            'Are you sure you want to block this user? You won\'t receive any more peeks from them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                blockSender();
              },
              child: const Text('Block'),
            ),
          ],
        );
      },
    );
  }

  /// Reset moderation state
  void reset() {
    _isProcessingAction = false;
    _originalSenderId = null;
    debugPrint("[Moderation] Moderation state reset");
  }

  /// Dispose resources
  void dispose() {
    // No resources to dispose for now
    debugPrint("[Moderation] ModerationManager disposed");
  }
}
