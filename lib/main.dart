import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAuth.instance.signInAnonymously();

  // 🔁 Listen to in-app purchase updates
  InAppPurchase.instance.purchaseStream.listen(
    (purchaseDetailsList) {
      _handlePurchaseUpdates(purchaseDetailsList);
    },
    onDone: () => print('🛒 Purchase stream closed'),
    onError: (error) => print('❌ Purchase stream error: $error'),
  );

  runApp(ProviderScope(child: PeekApp(navigatorKey: rootNavigatorKey)));
}

class PeekApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const PeekApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupPushNotifications();
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 Push received: ${message.notification?.title}');
    });

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: createRouter(navigatorKey), // ✅ This is enough
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
    );
  }
}

/// 🔔 Firebase Messaging Setup
Future<void> _setupPushNotifications() async {
  final messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission();
  print('🔔 Push permission: ${settings.authorizationStatus}');

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    try {
      String? apnsToken = await messaging.getAPNSToken();
      print('📡 APNs Token: $apnsToken');
    } catch (e) {
      print('⚠️ Could not get APNs token: $e');
    }

    final fcmToken = await messaging.getToken();
    print('📲 FCM Token: $fcmToken');
  }
}

/// 🛒 Handle Purchase Updates Globally
void _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
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
        print('✅ User upgraded to Premium.');

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
      print("❌ Purchase error: ${purchase.error}");
    }
  }
}
