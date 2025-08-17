import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peek/features/peek/providers/peek_providers.dart';
import 'package:peek/services/notification_service.dart';
import 'package:peek/core/router.dart';

/// Manages app lifecycle events and state changes
class AppLifecycleManager with WidgetsBindingObserver {
  final WidgetRef ref;
  final GlobalKey<NavigatorState> navigatorKey;
  String? _pendingDialogRequestId;

  AppLifecycleManager({
    required this.ref,
    required this.navigatorKey,
  });

  /// Initialize lifecycle management
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    _initializeNotificationService();
    _setupAuthStateListener();
    _scheduleDelayedDialogCheck();
  }

  /// Clean up resources
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    final prefs = await SharedPreferences.getInstance();

    if (state == AppLifecycleState.resumed) {
      await prefs.setBool('isAppInForeground', true);
      await _handleAppResumed(prefs);
    } else {
      await prefs.setBool('isAppInForeground', false);
    }
  }

  /// Handle app resumed from background
  Future<void> _handleAppResumed(SharedPreferences prefs) async {
    final pendingRequestId = prefs.getString('pending_peek_request_id');
    if (pendingRequestId != null) {
      debugPrint(
          "[AppLifecycleManager] Processing pending request: $pendingRequestId");
      await prefs.remove('pending_peek_request_id');
      ref.invalidate(pendingPeekRequestsProvider);
    } else {
      ref.invalidate(pendingPeekRequestsProvider);
    }
  }

  /// Initialize notification service
  Future<void> _initializeNotificationService() async {
    try {
      final notificationService =
          NotificationService(navigatorKey: navigatorKey);
      await notificationService.initialize(ref.read(routerProvider));
      await notificationService.checkForInitialMessage();
    } catch (e) {
      debugPrint("❌ Error during NotificationService setup: $e");
    }
  }

  /// Setup authentication state listener
  void _setupAuthStateListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        // Handle sign-out: clear local state
        debugPrint("[AppLifecycleManager] User signed out - clearing state");
      }
    });
  }

  /// Schedule delayed dialog check for pending requests
  void _scheduleDelayedDialogCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 1), () {
        if (_pendingDialogRequestId != null) {
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          if (currentUserId != null) {
            ref.invalidate(pendingPeekRequestsProvider);
          }
        }
      });
    });
  }

  /// Set pending dialog request ID
  void setPendingDialogRequestId(String? requestId) {
    _pendingDialogRequestId = requestId;
  }
}
