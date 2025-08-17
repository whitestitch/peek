// services/notification_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

// Define the high-priority channel.
//The ID MUST match the one in your Cloud Function.
const AndroidNotificationChannel peekRequestChannel =
    AndroidNotificationChannel(
  // id
  'peek_requests_channel',
  // title
  'Peek Requests',
  description: 'Channel for new Peek request notifications.',
  // This is what enables heads-up display
  importance: Importance.max,
  playSound: true,
);

// Top-level function required by Firebase for background handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background processing.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // The OS now handles displaying the notification, so no further action is needed here.

  // 1. Check if the app is already in the foreground.
  final prefs = await SharedPreferences.getInstance();
  // No need to reload, the main app isolate is responsible for setting it.
  if (prefs.getBool('isAppInForeground') ?? false) {
    return;
  }

  // If the remote push already includes a 'notification' block,
  // iOS will show the system alert. Avoid creating a duplicate local notif.
  if (message.notification != null) {
    return;
  }

  // 2. For iOS: If the message has a notification block, let the OS handle it
  // iOS will automatically display the notification from the APNs payload
  if (Platform.isIOS && message.notification != null) {
    return;
  }

  // 3. For Android or data-only messages: Create local notification if needed
  if (Platform.isAndroid || message.notification == null) {
    final title =
        message.data['title'] as String? ?? message.notification?.title;
    final body = message.data['body'] as String? ?? message.notification?.body;

    if (title != null && body != null) {
      await _showLocalNotification(title, body, message.hashCode);
    }
  }
}

// Helper function for background handler (must be top-level)
Future<void> _showLocalNotification(String title, String body, int id) async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Define platform-specific details
  const androidDetails = AndroidNotificationDetails(
    'peek_requests_channel',
    'Peek Requests',
    channelDescription: 'Channel for new Peek request notifications.',
    importance: Importance.max,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  const notificationDetails = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  // Initialize the plugin (safe to call multiple times)
  await flutterLocalNotificationsPlugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings()));

  // Show the notification
  await flutterLocalNotificationsPlugin.show(
    id,
    title,
    body,
    notificationDetails,
  );
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
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

    // NEW: Initialize the local notifications plugin and create the channel
    if (!kIsWeb && Platform.isAndroid) {
      // Create the channel
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(peekRequestChannel);

      // Initialize the plugin
      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings(
              '@mipmap/ic_launcher'), // Use your app icon
          iOS: DarwinInitializationSettings(),
        ),
        // This handles taps when the app is in foreground/background but not terminated
        onDidReceiveNotificationResponse: (details) {
          debugPrint(
              "[LocalNotifications] onDidReceiveNotificationResponse payload: ${details.payload}");
          // Here you could add navigation logic if needed, but FCM onMessageOpenedApp already handles it.
        },
      );
    }

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
    // Check for initial message implementation
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
    // Request notification permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true, // Enable critical alerts for better delivery
      provisional: false,
      sound: true,
    );
    debugPrint(
      '[NotificationService] User granted permission: ${settings.authorizationStatus}',
    );

    // Apply suppression ONLY to foreground notifications
    // Background notifications will be handled by the system
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: false, // Suppress alerts in foreground only
      badge: true,
      sound: true,
    );
  }

  void _setupListeners() {
    // SPACE

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
          '📨 [NotificationService FG] Message received: ${message.data}');

      final String? type = message.data['type'] as String?;

      // If it's a new peek request, show an in-app dialog directly.
      if (type == 'peek_request_received') {
        final String? requestId = message.data['requestId'];
        if (requestId != null) {
          // This existing method shows your custom dialog
          _handleIncomingPeekRequest(requestId);
        }
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

  // Handle notification tap and navigate appropriately
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

    // Extract notification data
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
      // Force delete old token and get a fresh one
      await _firebaseMessaging.deleteToken();
      debugPrint('🗑️ [NotificationService] Old FCM token deleted');

      final fcmToken = await _firebaseMessaging.getToken();
      debugPrint('📲 [NotificationService] FCM Token: $fcmToken');
      final uid = _auth.currentUser?.uid;
      if (uid != null && fcmToken != null) {
        // Add detailed error handling for Firestore write
        try {
          await _firestore.collection('users').doc(uid).set({
            'fcmToken': fcmToken,
            'fcmTokenTimestamp': FieldValue
                .serverTimestamp(), // Good to track when it was updated
          }, SetOptions(merge: true));

          // Verify the write succeeded by reading it back
          final doc = await _firestore.collection('users').doc(uid).get();
          final savedToken = doc.data()?['fcmToken'] as String?;

          if (savedToken == fcmToken) {
            debugPrint(
                '✅ [NotificationService] FCM Token saved to Firestore and verified');
          } else {
            debugPrint(
                '❌ [NotificationService] FCM Token save verification FAILED. Expected: $fcmToken, Got: $savedToken');
          }
        } catch (firestoreError) {
          debugPrint(
              '❌ [NotificationService] Firestore write failed: $firestoreError');
          rethrow; // Re-throw to be caught by outer catch
        }
      } else {
        debugPrint(
          '⚠️ [NotificationService] User ID or FCM token is null, cannot save. UID: $uid, Token: $fcmToken',
        );
      }
    } catch (e) {
      debugPrint('❌ [NotificationService] Failed to get/save FCM token: $e');
    }
  }
} // End of NotificationService class
