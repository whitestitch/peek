// services/notification_service.dart
import 'dart:async';
import 'dart:io'; // Required for Platform check

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
  // --- Keep your existing background handler code ---
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    "📨 [NotificationService BG Handler] Message data: ${message.data}",
  );
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Store the router instance provided during initialization
  GoRouter? _router;

  /// Initialize listeners, request permissions.
  /// MUST be called after GoRouter is initialized.
  Future<void> initialize(GoRouter router) async {
    // --- Keep your existing initialize method code ---
    _router = router;
    await _requestPermissions();
    _setupListeners();
    if (!kIsWeb && Platform.isIOS) {
      _getAndSaveTokensWithRetry();
    } else if (!kIsWeb) {
      _getAndSaveTokens();
    }
    debugPrint(
      "[NotificationService] Initialization complete (excluding initial message check).",
    );
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
      // TODO: Implement foreground notification display
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
    final String? requestId =
        data['request_id']
            as String?; // Use 'request_id' as per previous examples

    // --- Validate base requirement: requestId ---
    if (requestId == null || requestId.isEmpty) {
      debugPrint(
        "⚠️ [NotificationService] Notification tap data missing 'request_id'. Cannot navigate.",
      );
      _router!.go('/'); // Fallback to home if critical data is missing
      return;
    }

    Uri? targetUri; // Variable to hold the navigation target

    // --- Determine navigation based on notification 'type' ---
    switch (type) {
      case 'peek_request_received': // User needs to respond
        debugPrint(
          "[NotificationService] Type: 'peek_request_received'. Navigating to /capture",
        );
        targetUri = Uri(
          path: '/capture',
          queryParameters: {'requestId': requestId},
        );
        break;

      case 'peek_image_ready': // User's request accepted, image ready to view
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

  // --- Token Handling Methods (Keep As Is) ---
  void _getAndSaveTokensWithRetry() {
    // Keep your existing token retry logic
    _getAndSaveTokens();
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!Platform.isIOS) {
        timer.cancel();
        return;
      }
      final apnsToken = await _firebaseMessaging.getAPNSToken();
      debugPrint('🔁 [NotificationService] Retrying APNs token: $apnsToken');
      if (apnsToken != null) {
        timer.cancel();
        debugPrint('✅ [NotificationService] Got APNs token: $apnsToken');
        await _getAndSaveTokens();
      }
    });
  }

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
