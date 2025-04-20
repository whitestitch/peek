// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import 'firebase_options.dart';
import 'core/router.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Helper to initialize Firebase and return the default app.
/// If the default app already exists, this returns it.
Future<FirebaseApp> initializeFirebaseApp() async {
  try {
    return await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (e.toString().contains('already exists')) {
      // If the Firebase app already exists, return the default app.
      return Firebase.app();
    } else {
      rethrow;
    }
  }
}

/// Background FCM handler.
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in this isolate.
  await initializeFirebaseApp();
  print('📨 [BG] Message: ${message.messageId}');
}

Future<void> main() async {
  // Ensure Flutter engine is initialized.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (or get the existing instance if already initialized).
  await initializeFirebaseApp();

  // Disable Firestore cache.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );

  // Sign in anonymously.
  await FirebaseAuth.instance.signInAnonymously();

  // Setup background FCM handler.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Listen for in-app purchase updates.
  InAppPurchase.instance.purchaseStream.listen(
    _handlePurchaseUpdates,
    onDone: () => print('🛒 Purchase stream closed'),
    onError: (err) => print('❌ Purchase stream error: $err'),
  );

  // Run the app wrapped in ProviderScope (for Riverpod).
  runApp(const ProviderScope(child: PeekApp()));
}

class PeekApp extends StatelessWidget {
  const PeekApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Setup push notifications once the first frame is rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupPushNotifications();
    });

    FirebaseMessaging.onMessage.listen((message) {
      print('📨 [FG] Notification: ${message.notification?.title}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final route = message.data['route'];
      if (route != null && rootNavigatorKey.currentContext != null) {
        GoRouter.of(rootNavigatorKey.currentContext!).go(route);
      }
    });

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: createRouter(rootNavigatorKey),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
    );
  }
}

Future<void> _setupPushNotifications() async {
  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('🔔 Permission: ${settings.authorizationStatus}');

  Timer.periodic(const Duration(seconds: 3), (timer) async {
    final apnsToken = await messaging.getAPNSToken();
    print('🔁 Retrying APNs token: $apnsToken');
    if (apnsToken != null) {
      timer.cancel();
      print('✅ Got APNs token: $apnsToken');
      try {
        final fcmToken = await messaging.getToken();
        print('📲 FCM Token: $fcmToken');
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null && fcmToken != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'fcmToken': fcmToken,
          }, SetOptions(merge: true));
          print('✅ Token saved to Firestore');
        }
      } catch (e) {
        print('⚠️ Failed to get FCM token: $e');
      }
    }
  });
}

Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
  for (final purchase in purchases) {
    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'isPremium': true,
          'premiumSince': FieldValue.serverTimestamp(),
          'lastPurchaseId': purchase.productID,
        }, SetOptions(merge: true));
        final context = rootNavigatorKey.currentContext;
        if (context != null && context.mounted) {
          showDialog(
            context: context,
            builder:
                (_) => AlertDialog(
                  title: const Text('🎉 Success'),
                  content: const Text('Premium access unlocked!'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
        }
      }
    } else if (purchase.status == PurchaseStatus.error) {
      print('❌ Purchase error: ${purchase.error}');
    }
  }
}
