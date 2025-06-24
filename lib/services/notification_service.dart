// services/notification_service.dart
import 'dart:async';
import 'dart:io'; // Required for Platform check
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb and debugPrint
import 'package:go_router/go_router.dart';

import '../firebase_options.dart'; // Ensure correct path

// Top-level function required by Firebase for background handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // only initialize if this isolate hasn’t yet:
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("✅ Firebase initialized in BG Handler (was empty).");
  } else {
    debugPrint("ℹ️ Firebase already initialized in BG Handler.");
  }
  debugPrint(
    "📨 [NotificationService BG Handler] Message data: ${message.data}",
  );
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final GlobalKey<NavigatorState> navigatorKey;
  // Update constructor to require navigatorKey
  NotificationService({required this.navigatorKey});

  // Store the router instance provided during initialization
  GoRouter? _router;

  /// Initialize listeners, request permissions.
  /// MUST be called after GoRouter is initialized.
  Future<void> initialize(GoRouter router) async {
    _router = router;
    await _requestPermissions();
    _setupListeners();

    if (!kIsWeb && Platform.isIOS) {
      // 1️⃣ grab whatever APNs token we have right now
      final apns = await _firebaseMessaging.getAPNSToken();
      debugPrint("[NotificationService] initial APNs token: $apns");

      if (apns != null) {
        // we already have an APNs token → go straight to FCM
        await _getAndSaveTokens();
      } else {
        // schedule retries until APNs arrives, then fetch FCM
        _getAndSaveTokensWithRetry();
      }
    } else if (!kIsWeb) {
      // Android & others get FCM immediately
      await _getAndSaveTokens();
    }

    debugPrint(
      "[NotificationService] Initialization complete (excluding initial message check).",
    );
  }

  void _getAndSaveTokensWithRetry() {
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!Platform.isIOS) {
        timer.cancel();
        return;
      }
      final apnsToken = await _firebaseMessaging.getAPNSToken();
      debugPrint('🔁 [NotificationService] retrying APNs token: $apnsToken');
      if (apnsToken != null) {
        timer.cancel();
        debugPrint(
            '✅ [NotificationService] got APNs token on retry: $apnsToken');
        await _getAndSaveTokens();
      }
    });
  }

  /// Checks for an initial message if the app was opened from terminated state.
  /// Should be called once after initialize() in main.dart.
  Future<void> checkForInitialMessage() async {
    // --- Keep your existing checkForInitialMessage method code ---
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        '📨 [NotificationService Terminated TAP] Initial message data: ${initialMessage.data}',
      );
      Future.delayed(const Duration(milliseconds: 700), () {
        // Keep delay
        _handleNotificationTap(initialMessage.data);
      });
    } else {
      debugPrint("[NotificationService] No initial message found.");
    }
  }

  Future<void> _requestPermissions() async {
    // --- Keep your existing _requestPermissions method code ---
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint(
      '[NotificationService] User granted permission: ${settings.authorizationStatus}',
    );
  }

  void _setupListeners() {
    // --- Keep your existing _setupListeners method code ---
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📨 [NotificationService FG] Message data: ${message.data}');
      debugPrint(
        '📨 [NotificationService FG] Notification: ${message.notification?.title}/${message.notification?.body}',
      );

      // Handle foreground peek requests immediately
      final String? type =
          message.data['type'] as String?; // Ensure you get type
      if (type == 'peek_request_received') {
        // final requestId = message.data['requestId']; // requestId is available if needed for other logic

        // REMOVE OR COMMENT OUT THE DIRECT DIALOG CALL FROM HERE:
        // _handleIncomingPeekRequest(requestId);

        // Instead, just log and let the Riverpod provider drive the UI update via main.dart
        debugPrint(
            '🔍 [NotificationService FG] Peek request received (type: $type). Providers in main.dart should handle UI based on Firestore update.');
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
        '📨 [NotificationService BG TAP] Notification tapped, Data: ${message.data}',
      );
      _handleNotificationTap(message.data);
    });
    debugPrint(
      "[NotificationService] Foreground and Background Tap listeners set up.",
    );
  }

  // --- MODIFIED: _handleNotificationTap (Handles both notification types) ---
  void _handleNotificationTap(Map<String, dynamic> data) {
    if (_router == null) {
      debugPrint(
        "❌ [NotificationService] Router not initialized, cannot navigate on tap.",
      );
      return;
    }

    debugPrint(
      "[NotificationService] Handling notification tap navigation. Data: $data",
    );

    // --- Extract required data fields ---
    final String? type =
        data['type'] as String?; // Crucial field to determine action
    String? requestId = data['requestId'];

    // --- Validate base requirement: requestId ---
    if (requestId != null) {
      debugPrint("[NotificationService] Navigating with requestId: $requestId");
    } else {
      debugPrint(
          "⚠️ [NotificationService] Notification tap data missing 'requestId' (camelCase). Cannot navigate.");
    }

    Uri? targetUri; // Variable to hold the navigation target

    // --- Determine navigation based on notification 'type' ---
    switch (type) {
      case 'peek_request_received': // User needs to respond
        debugPrint(
          "[NotificationService] Type: 'peek_request_received'. Navigating to home where provider will show dialog",
        );
        // Navigate to home page where the pendingPeekRequestsProvider
        // will automatically detect the new request and show the dialog
        targetUri = Uri(path: '/');
        // Force a small delay to ensure the navigation completes before dialog shows
        Future.delayed(const Duration(milliseconds: 500), () {
          // The dialog will be triggered by the listener in main.dart
          debugPrint("[NotificationService] Navigation delay complete");
        });
        break;

      // User's request accepted, image ready to view
      case 'peek_image_ready':
        final String? imageUrl =
            data['image_url'] as String?; // Get image URL for this type
        if (imageUrl == null || imageUrl.isEmpty) {
          debugPrint(
            "⚠️ [NotificationService] Notification type 'peek_image_ready' missing required 'image_url'. Cannot navigate.",
          );
          _router!.go('/'); // Fallback home if URL missing for this type
          return;
        }
        debugPrint(
          "[NotificationService] Type: 'peek_image_ready'. Navigating to /splash",
        );
        targetUri = Uri(
          path: '/splash',
          queryParameters: {
            'requestId': requestId,
            'initialImageUrl': imageUrl, // Pass the specific image URL
          },
        );
        break;

      // --- Add other notification types here if needed ---
      // case 'some_other_type':
      //   debugPrint("[NotificationService] Type: 'some_other_type'. Navigating...");
      //   // Extract other needed params...
      //   targetUri = Uri(path: '/some_other_screen', queryParameters: {...});
      //   break;
      // ----------------------------------------------------

      default:
        debugPrint(
          "⚠️ [NotificationService] Unknown or missing notification type: '$type'. Navigating home.",
        );
        _router!.go('/'); // Fallback to home for unrecognized types
        return; // Stop processing
    }

    // --- Perform navigation ---
    if (targetUri != null) {
      try {
        debugPrint(
          "[NotificationService] Triggering navigation to: ${targetUri.toString()}",
        );
        _router!.go(targetUri.toString());
      } catch (e) {
        debugPrint(
          "❌ [NotificationService] Error during router.go navigation: $e",
        );
        _router!.go('/'); // Fallback to home on navigation error
      }
    }
    // No else needed, default case in switch handles fallback or returns
  }
  // --- END OF MODIFIED _handleNotificationTap ---

  void _handleIncomingPeekRequest(String requestId) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint(
          "❌ [NotificationService] No context available to show dialog.");
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Incoming Peek Request'),
        content: const Text('Would you like to accept the peek?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Handle decline logic
            },
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Handle accept logic
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  // --- Token Handling Methods (Keep As Is) ---

  Future<void> _getAndSaveTokens() async {
    // Keep your existing token saving logic
    try {
      final fcmToken = await _firebaseMessaging.getToken();
      debugPrint('📲 [NotificationService] FCM Token: $fcmToken');
      final uid = _auth.currentUser?.uid;
      if (uid != null && fcmToken != null) {
        await _firestore.collection('users').doc(uid).set({
          'fcmToken': fcmToken,
          'fcmTokenTimestamp':
              FieldValue.serverTimestamp(), // Good to track when it was updated
        }, SetOptions(merge: true));
        debugPrint('✅ [NotificationService] FCM Token saved to Firestore');
      } else {
        debugPrint(
          '⚠️ [NotificationService] User ID or FCM token is null, cannot save.',
        );
      }
    } catch (e) {
      debugPrint('❌ [NotificationService] Failed to get/save FCM token: $e');
    }
  }
} // End of NotificationService class
