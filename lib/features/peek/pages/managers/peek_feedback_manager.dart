// lib/features/peek/pages/managers/peek_feedback_manager.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class PeekFeedbackManager {
  final String requestId;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static const String _feedbackTimestampKey = 'feedbackLastPromptTimestamp';

  PeekFeedbackManager({required this.requestId});

  Future<void> submitFeedback(String feedbackValue) async {
    // Get reference to the specific peek request document
    final docRef =
        FirebaseFirestore.instance.collection('peek_requests').doc(requestId);

    // Update the document with the feedback field
    await docRef.update({'feedback': feedbackValue});

    debugPrint(
      "[PeekFeedbackManager] Feedback '$feedbackValue' submitted for request $requestId",
    );

    // Update SharedPreferences timestamp
    await _updateFeedbackTimestamp();

    // Log success analytics
    await _logSuccessAnalytics(feedbackValue);
  }

  Future<void> _updateFeedbackTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMillis = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_feedbackTimestampKey, nowMillis);
      debugPrint("[PeekFeedbackManager] Updated feedbackLastPromptTimestamp.");
    } catch (e) {
      debugPrint("Error updating feedback timestamp in SharedPreferences: $e");
    }
  }

  Future<void> _logSuccessAnalytics(String feedbackValue) async {
    try {
      await _analytics.logEvent(
        name: 'peek_feedback_submitted',
        parameters: {
          'request_id_partial': requestId.substring(0, 8),
          'feedback_value': feedbackValue,
        },
      );
      debugPrint("[PeekFeedbackManager] Logged peek_feedback_submitted event.");
    } catch (e) {
      debugPrint("Error logging peek_feedback_submitted event: $e");
    }
  }

  Future<void> logFailureAnalytics(String feedbackValue, String error) async {
    try {
      await _analytics.logEvent(
        name: 'peek_feedback_failed',
        parameters: {
          'request_id_partial': requestId.substring(0, 8),
          'feedback_value': feedbackValue,
          'error': error.substring(0, error.length > 99 ? 99 : error.length),
        },
      );
      debugPrint("[PeekFeedbackManager] Logged peek_feedback_failed event.");
    } catch (e) {
      debugPrint("Error logging peek_feedback_failed event: $e");
    }
  }
}
