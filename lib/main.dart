import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import 'firebase_options.dart'; // Ensure this path is correct
import 'core/router.dart'; // Ensure this path is correct
import 'services/notification_service.dart'; // Ensure this path is correct

final rootNavigatorKey = GlobalKey<NavigatorState>();

// --- Background Handler ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("--- Background Handler Started ---");
  // --- ADDED Check inside background handler ---
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("✅ Firebase initialized for Background Handler.");
    } catch (e) {
      debugPrint("❌ Error initializing Firebase in Background Handler: $e");
      // Decide how to handle background init failure
    }
  } else {
    debugPrint(
      "ℹ️ Firebase already initialized in Background Handler isolate.",
    );
  }
  // --- End of Added Check ---
  debugPrint("📨 [BG Handler] Message received: ${message.messageId}");
  // Add any other background processing needed here
}
// ---------------------------------------------------------

Future<void> main() async {
  debugPrint("--- main() Started ---");
  // Must be called first.
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("WidgetsFlutterBinding initialized.");

  // --- MORE ROBUST FIREBASE INITIALIZATION in main() ---
  debugPrint("Checking Firebase initialization status...");
  debugPrint("Current Firebase apps count: ${Firebase.apps.length}");

  // Attempt initialization only if no apps are registered in this isolate.
  if (Firebase.apps.isEmpty) {
    debugPrint("Firebase.apps is empty. Attempting initialization...");
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("✅ Firebase initialized successfully in main.");
    } catch (e) {
      // Log the specific error if initialization fails
      debugPrint("❌ Error initializing Firebase in main: $e");
      // Handle initialization failure critically - maybe show an error screen?
      // runApp(ErrorApp(errorMessage: "Failed to initialize Firebase: $e"));
      // return;
    }
  } else {
    debugPrint(
      "ℹ️ Firebase already initialized in main isolate. Skipping initialization.",
    );
    // If needed, you can get the existing default app instance:
    // FirebaseApp defaultApp = Firebase.app();
    // debugPrint("Existing default app name: ${defaultApp.name}");
  }
  // --- END OF MODIFICATION ---

  // Attempt anonymous sign-in
  debugPrint("Attempting anonymous sign-in...");
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
      debugPrint(
        "✅ Signed in anonymously: ${FirebaseAuth.instance.currentUser?.uid}",
      );
    } else {
      debugPrint(
        "✅ Already signed in: ${FirebaseAuth.instance.currentUser?.uid}",
      );
    }
  } catch (e) {
    debugPrint("❌ Anonymous sign-in failed: $e");
  }

  // Register the background message handler
  debugPrint("Registering background message handler...");
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Create the router instance
  debugPrint("Creating GoRouter...");
  final router = createRouter(rootNavigatorKey);

  // Initialize the NotificationService
  debugPrint("Initializing NotificationService...");
  final notificationService = NotificationService();
  try {
    await notificationService.initialize(router);
    debugPrint("✅ NotificationService initialized.");
  } catch (e) {
    debugPrint("❌ Error initializing NotificationService: $e");
  }

  // Run the app
  debugPrint("Running app...");
  runApp(ProviderScope(child: PeekApp(router: router)));
  debugPrint("--- main() Finished ---");
}

// --- Root App Widget (Remains StatefulWidget for IAP lifecycle) ---
class PeekApp extends ConsumerStatefulWidget {
  final GoRouter router;
  const PeekApp({super.key, required this.router});
  @override
  ConsumerState<PeekApp> createState() => _PeekAppState();
}

// --- State for PeekApp (Remains the same) ---
class _PeekAppState extends ConsumerState<PeekApp> {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  @override
  void initState() {
    super.initState();
    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      (purchases) => _handlePurchaseUpdates(purchases, context),
      onDone: () {
        debugPrint('🛒 Purchase stream closed');
        _purchaseSubscription?.cancel();
      },
      onError: (err) {
        debugPrint('❌ Purchase stream error: $err');
      },
      cancelOnError: true,
    );
    debugPrint("🛒 IAP Listener initialized in PeekApp initState.");
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    debugPrint('🛒 Purchase stream subscription cancelled in PeekApp dispose.');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PEEK',
      debugShowCheckedModeBanner: false,
      routerConfig: widget.router,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
    );
  }

  // --- IAP Handling Logic (Remains the same) ---
  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
    BuildContext context,
  ) async {
    if (!mounted) {
      debugPrint(
        "⚠️ Purchase update received but _PeekAppState is not mounted.",
      );
      return;
    }
    debugPrint("🛒 Handling ${purchases.length} purchase updates.");
    for (final purchase in purchases) {
      debugPrint(
        "🛒 Processing purchase: ${purchase.productID}, Status: ${purchase.status}",
      );
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          debugPrint("⚠️ Cannot grant premium: User is null.");
          continue;
        }
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'isPremium': true,
            'premiumSince': FieldValue.serverTimestamp(),
            'lastPurchaseId': purchase.productID,
          }, SetOptions(merge: true));
          debugPrint("✅ Premium status updated in Firestore for user $uid");
          if (purchase.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchase);
            debugPrint("✅ Purchase completed: ${purchase.purchaseID}");
            _showPremiumSuccessDialog(context);
          } else if (purchase.status == PurchaseStatus.restored) {
            debugPrint("✅ Purchase restored: ${purchase.productID}");
            _showRestoreSuccessDialog(context);
          } else {
            debugPrint("✅ Purchase ${purchase.productID} already completed.");
          }
        } catch (e) {
          debugPrint(
            "❌ Failed to update Firestore or complete purchase for ${purchase.productID}: $e",
          );
          _showPurchaseErrorDialog(
            context,
            "Failed to apply purchase. Please contact support if issue persists.",
          );
        }
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint(
          '❌ Purchase error: ${purchase.error?.message} (Code: ${purchase.error?.code})',
        );
        _showPurchaseErrorDialog(context, purchase.error);
      } else if (purchase.status == PurchaseStatus.pending) {
        debugPrint('⏳ Purchase pending: ${purchase.productID}');
      } else if (purchase.status == PurchaseStatus.canceled) {
        debugPrint('🚫 Purchase cancelled by user: ${purchase.productID}');
      }
    }
  }

  // --- Dialog Helper Methods (Remain the same) ---
  void _showPremiumSuccessDialog(BuildContext context) {
    /* ... same ... */
  }
  void _showRestoreSuccessDialog(BuildContext context) {
    /* ... same ... */
  }
  void _showPurchaseErrorDialog(BuildContext context, Object? errorDetails) {
    /* ... same ... */
  }
} // End of _PeekAppState

// --- Duplicate Dialog definitions removed, they are inside _PeekAppState now ---
