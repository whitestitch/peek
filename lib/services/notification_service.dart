import 'dart:async';
import 'dart:io'; // Required for Platform check if needed later

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:go_router/go_router.dart';

import '../firebase_options.dart'; // Ensure correct path

// Top-level function required by Firebase for background handler
@pragma('vm:entry-point') // Ensures tree shaking doesn't remove it
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase in this background isolate
  // Using a distinct app name avoids potential conflicts if main app is running
  // Although initializing default usually works if done carefully.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint(
    "📨 [NotificationService BG Handler] Message data: ${message.data}",
  );
  // IMPORTANT: You CANNOT update UI or navigate directly from here.
  // Background processing (e.g., updating a badge count locally) can happen here.
  // Navigation must happen when the user *taps* the notification (handled by onMessageOpenedApp or getInitialMessage).
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Store the router instance provided during initialization
  GoRouter? _router;

  // Singleton pattern for easy access (optional)
  // static final NotificationService instance = NotificationService._internal();
  // NotificationService._internal();

  /// Initialize listeners, request permissions, and handle initial message.
  /// MUST be called after GoRouter is initialized.
  Future<void> initialize(GoRouter router) async {
    _router = router; // Store the router

    // Request permissions (iOS and Web)
    await _requestPermissions();

    // Setup listeners for foreground, background tap, and initial message
    _setupListeners();

    // Handle initial message if app was opened from terminated state via notification
    await _handleInitialMessage();

    // Start APNs token fetching/retry logic (if applicable for iOS)
    if (!kIsWeb && Platform.isIOS) {
      _getAndSaveTokensWithRetry();
    } else if (!kIsWeb && Platform.isAndroid) {
      // For Android, usually getToken() works directly without needing APNs logic
      _getAndSaveTokens();
    }
  }

  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false, // Change to true for provisional auth if desired
      sound: true,
    );
    debugPrint(
      '[NotificationService] User granted permission: ${settings.authorizationStatus}',
    );
  }

  void _setupListeners() {
    // --- Handle messages received while the app is in the foreground ---
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📨 [NotificationService FG] Message data: ${message.data}');
      debugPrint(
        '📨 [NotificationService FG] Notification: ${message.notification?.title}/${message.notification?.body}',
      );

      // --- TODO: Display an in-app notification/alert ---
      // Avoid navigating automatically for foreground messages.
      // Use packages like `flutter_local_notifications` or a custom overlay.
      // Example: showDialog(...), ScaffoldMessenger.of(context).showSnackBar(...)
      // Needs access to a BuildContext, which might require passing it or using a global key/state management.
    });

    // --- Handle notification tap when app is in the background ---
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
        '📨 [NotificationService BG TAP] Message data: ${message.data}',
      );
      _handleNotificationTap(message.data);
    });
  }

  // --- Handle notification tap when app was terminated ---
  Future<void> _handleInitialMessage() async {
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        '📨 [NotificationService Terminated TAP] Message data: ${initialMessage.data}',
      );
      // Delay slightly to ensure router is fully ready
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationTap(initialMessage.data);
      });
    }
  }

  /// Common logic to handle navigation when a notification is tapped.
  void _handleNotificationTap(Map<String, dynamic> data) {
    if (_router == null) {
      debugPrint(
        "❌ [NotificationService] Router not initialized, cannot navigate.",
      );
      return;
    }

    // --- >>> IMPORTANT PAYLOAD CHANGE <<< ---
    // Expect 'requestId' and 'imageUrl' in the data payload from your Cloud Function
    final String? requestId = data['requestId'] as String?;
    final String? imageUrl = data['imageUrl'] as String?;

    // --- REMOVE/REPLACE OLD LOGIC ---
    // final route = data['route']; // Old logic based on 'route' field

    if (requestId != null && imageUrl != null) {
      debugPrint(
        "[NotificationService] Navigating to /splash with requestId: $requestId",
      );
      // Navigate to the SplashPage, which will then go to PeekImageView
      _router!.go(
        Uri(
          path: '/splash',
          queryParameters: {
            'requestId': requestId,
            'initialImageUrl': imageUrl, // Pass the pre-fetched URL directly
          },
        ).toString(),
      );
    } else {
      debugPrint(
        "⚠️ [NotificationService] Notification data missing 'requestId' or 'imageUrl'. Payload: $data",
      );
      // Fallback navigation? Navigate home? Log error?
      // _router!.go('/'); // Example: Navigate home if data is missing
    }
  }

  /// Gets APNs (iOS) and FCM tokens and saves the FCM token to Firestore.
  /// Includes retry logic specifically for APNs token which can take time.
  void _getAndSaveTokensWithRetry() {
    // Initial attempt for FCM token (might work immediately)
    _getAndSaveTokens();

    // Retry mechanism specifically for APNs token on iOS
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
        // Once APNs token is available, getting FCM token is more reliable
        await _getAndSaveTokens();
      }
      // Consider adding a max retry limit to the timer
    });
  }

  /// Gets the FCM token and saves it to Firestore.
  Future<void> _getAndSaveTokens() async {
    try {
      // Request FCM token from Firebase
      // Pass vapidKey for web push notifications if needed:
      // final fcmToken = await _firebaseMessaging.getToken(vapidKey: 'YOUR_WEB_VAPID_KEY');
      final fcmToken = await _firebaseMessaging.getToken();
      debugPrint('📲 [NotificationService] FCM Token: $fcmToken');

      // Save the token to Firestore associated with the user
      final uid = _auth.currentUser?.uid;
      if (uid != null && fcmToken != null) {
        await _firestore.collection('users').doc(uid).set(
          {'fcmToken': fcmToken},
          SetOptions(merge: true), // Merge to avoid overwriting other user data
        );
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
}
