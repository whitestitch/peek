import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Manages analytics and tracking for image viewing
class AnalyticsManager {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Tracking state
  bool _viewStartedLogged = false;
  DateTime? _viewStartTime;

  // Data
  final String requestId;
  final String imageUrl;
  String? senderLocation;

  // Callbacks
  final ValueChanged<String>? onError;

  AnalyticsManager({
    required this.requestId,
    required this.imageUrl,
    this.senderLocation,
    this.onError,
  });

  /// Log image view started event
  Future<void> logViewStarted({
    bool isPremium = false,
    String? senderDisplayName,
  }) async {
    if (_viewStartedLogged) return;

    _viewStartedLogged = true;
    _viewStartTime = DateTime.now();

    try {
      await _analytics.logEvent(
        name: 'peek_image_view_started',
        parameters: {
          'request_id': requestId,
          'is_premium': isPremium,
          'sender_name': senderDisplayName ?? 'anonymous',
          'has_location': senderLocation != null,
          'timestamp': _viewStartTime!.millisecondsSinceEpoch,
        },
      );

      debugPrint(
          "[Analytics] Image view started logged for request: $requestId");
    } catch (e) {
      debugPrint("[Analytics] Error logging view started: $e");
      onError?.call("Analytics error: $e");
    }
  }

  /// Log image view completed event
  Future<void> logViewCompleted({
    String reason = 'user_closed',
    int? viewDurationSeconds,
  }) async {
    if (!_viewStartedLogged) return;

    final duration = _viewStartTime != null
        ? DateTime.now().difference(_viewStartTime!).inSeconds
        : viewDurationSeconds ?? 0;

    try {
      await _analytics.logEvent(
        name: 'peek_image_view_completed',
        parameters: {
          'request_id': requestId,
          'completion_reason': reason,
          'view_duration_seconds': duration,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );

      debugPrint(
          "[Analytics] Image view completed logged - Duration: ${duration}s, Reason: $reason");
    } catch (e) {
      debugPrint("[Analytics] Error logging view completed: $e");
      onError?.call("Analytics error: $e");
    }
  }

  /// Log image load success
  Future<void> logImageLoaded({
    int? loadTimeMs,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'peek_image_loaded',
        parameters: {
          'request_id': requestId,
          'image_url': imageUrl,
          'load_time_ms': loadTimeMs ?? 0,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );

      debugPrint("[Analytics] Image load success logged");
    } catch (e) {
      debugPrint("[Analytics] Error logging image loaded: $e");
      onError?.call("Analytics error: $e");
    }
  }

  /// Log image load failure
  Future<void> logImageLoadFailed({
    required String error,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'peek_image_load_failed',
        parameters: {
          'request_id': requestId,
          'image_url': imageUrl,
          'error_message': error,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );

      debugPrint("[Analytics] Image load failure logged: $error");
    } catch (e) {
      debugPrint("[Analytics] Error logging image load failed: $e");
      onError?.call("Analytics error: $e");
    }
  }

  /// Log user action (report, block, etc.)
  Future<void> logUserAction({
    required String action,
    String? targetUserId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final parameters = <String, dynamic>{
        'request_id': requestId,
        'action': action,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      if (targetUserId != null) {
        parameters['target_user_id'] = targetUserId;
      }

      if (additionalData != null) {
        parameters.addAll(additionalData.cast<String, Object>());
      }

      await _analytics.logEvent(
        name: 'peek_user_action',
        parameters: parameters.cast<String, Object>(),
      );

      debugPrint("[Analytics] User action logged: $action");
    } catch (e) {
      debugPrint("[Analytics] Error logging user action: $e");
      onError?.call("Analytics error: $e");
    }
  }

  /// Log timer events
  Future<void> logTimerEvent({
    required String event, // 'started', 'completed', 'cancelled'
    int? durationSeconds,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'peek_timer_event',
        parameters: {
          'request_id': requestId,
          'event': event,
          'duration_seconds': durationSeconds ?? 0,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );

      debugPrint("[Analytics] Timer event logged: $event");
    } catch (e) {
      debugPrint("[Analytics] Error logging timer event: $e");
      onError?.call("Analytics error: $e");
    }
  }

  /// Get view duration in seconds
  int getViewDuration() {
    if (_viewStartTime == null) return 0;
    return DateTime.now().difference(_viewStartTime!).inSeconds;
  }

  /// Check if view has been logged
  bool get hasLoggedView => _viewStartedLogged;

  /// Reset analytics state
  void reset() {
    _viewStartedLogged = false;
    _viewStartTime = null;
    debugPrint("[Analytics] Analytics state reset");
  }

  /// Dispose resources
  void dispose() {
    // Log final completion if not already done
    if (_viewStartedLogged) {
      logViewCompleted(reason: 'disposed');
    }
    debugPrint("[Analytics] AnalyticsManager disposed");
  }
}
