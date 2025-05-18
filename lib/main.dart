// main.dart
import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, defaultTargetPlatform, TargetPlatform;

import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peek/features/onboarding/providers/onboarding_provider.dart';
import 'package:peek/theme/colors.dart';
import 'firebase_options.dart'; // Make sure this file is up-to-date
import 'core/router.dart';
import 'services/notification_service.dart';

// Assuming initializeCameras is defined in photo_capture_page.dart or a utility file
import 'features/peek/photo_capture_page.dart';
import 'package:peek/core/firestore_service.dart';
import 'package:peek/features/peek/providers/peek_providers.dart'; // For navigatorKeyProvider
import 'core/root_realtime_listener.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("--- Background Handler Started ---");
  // Crucial: Ensure Firebase is initialized in this background isolate
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("✅ Firebase initialized for Background Handler.");
    } catch (e) {
      debugPrint("❌ Error initializing Firebase in Background Handler: $e");
    }
  } else {
    debugPrint("ℹ️ Firebase already initialized for Background Handler.");
  }
  debugPrint("📨 [BG Handler] Message received: ${message.messageId}");
  if (message.data.isNotEmpty) {
    debugPrint("   Data: ${message.data}");
  }
}

Future<void> main() async {
  // 1. Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("--- main() Started: WidgetsFlutterBinding initialized.");

  // 2. Initialize Firebase (ONLY ONCE)
  debugPrint("Attempting Firebase.initializeApp()...");
  bool firebaseInitializedSuccessfully = false;
  try {
    // Check if Firebase has already been initialized.
    // This is the primary guard against the "duplicate-app" error.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint(
          "✅ Firebase.initializeApp() successful in main (Firebase.apps was empty).");
      firebaseInitializedSuccessfully = true;
    } else {
      debugPrint(
          "ℹ️ Firebase.initializeApp() skipped, Firebase.apps was not empty. Default app: ${Firebase.app().name}");
      firebaseInitializedSuccessfully = true;
    }
  } catch (e) {
    if (e is FirebaseException && e.code == 'duplicate-app') {
      debugPrint(
          "❌ Firebase.initializeApp() threw 'duplicate-app' error even after checking Firebase.apps.isEmpty. This is unusual for a clean build.");
      firebaseInitializedSuccessfully =
          true; // Still assume an app instance is available
    } else {
      debugPrint(
          "❌ CRITICAL: Error during Firebase.initializeApp() in main: $e");
    }
  }

  debugPrint("Current Firebase apps count: ${Firebase.apps.length}");
  if (Firebase.apps.isNotEmpty) {
    debugPrint("Default Firebase app name: ${Firebase.app().name}");
  }

  // Handle User Authentication
  debugPrint("Checking user authentication state (post-Firebase init)...");
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      debugPrint("No current user, attempting anonymous sign-in...");
      await FirebaseAuth.instance.signInAnonymously();
      debugPrint(
        "✅ Signed in anonymously: ${FirebaseAuth.instance.currentUser?.uid}",
      );
    } else {
      debugPrint(
        "✅ User already signed in: ${FirebaseAuth.instance.currentUser?.uid}",
      );
    }
  } catch (e) {
    debugPrint("❌ Anonymous sign-in failed: $e");
  }

  // Log current Firebase app status for diagnostics
  debugPrint("Current Firebase apps count: ${Firebase.apps.length}");
  if (Firebase.apps.isNotEmpty) {
    debugPrint("Default Firebase app name: ${Firebase.app().name}");
    // You can add more details if needed:
    // debugPrint("Default Firebase app options: ${Firebase.app().options.asMap}");
  }

  // Log current Firebase app status
  debugPrint("Current Firebase apps count: ${Firebase.apps.length}");
  if (Firebase.apps.isNotEmpty) {
    debugPrint("Default Firebase app name: ${Firebase.app().name}");
  }

  if (kDebugMode && firebaseInitializedSuccessfully) {
    try {
      // Use 10.0.2.2 for Android emulator to connect to localhost of the host machine.
      // For iOS simulator, 'localhost' or '127.0.0.1' usually works.
      // For physical devices, you'd need to use your computer's local network IP.
      final String host = defaultTargetPlatform == TargetPlatform.android
          ? '10.0.2.2'
          : 'localhost';

      debugPrint("🔧 Configuring Firebase Emulators to use host: $host");

      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      debugPrint("   Firestore Emulator -> $host:8080");

      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      debugPrint("   Auth Emulator      -> $host:9099");

      // Configure the default instance and the regional instance if you use it
      FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
      FirebaseFunctions.instanceFor(region: "us-central1")
          .useFunctionsEmulator(host, 5001);
      debugPrint(
          "   Functions Emulator -> $host:5001 (for default and us-central1)");

      // If using Firebase Storage Emulator:
      // await FirebaseStorage.instance.useStorageEmulator(host, 9199);
      // debugPrint("   Storage Emulator   -> $host:9199");

      debugPrint("✅ Firebase Emulators configured.");
    } catch (e) {
      debugPrint("❌ Error configuring Firebase Emulators: $e");
      // This is a critical setup error for development if emulators are intended.
    }
  }

  // Only proceed with Firebase-dependent services if initialization was successful
  if (firebaseInitializedSuccessfully) {
    debugPrint("Initializing cameras (post-Firebase init)...");

    debugPrint("Initializing cameras...");
    await initializeCameras();
    debugPrint("✅ Camera list initialized.");

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    debugPrint("Firebase background message handler registered.");
  } else {
    debugPrint(
        "⚠️ Firebase did not initialize successfully. App functionality may be severely limited.");
    // Consider showing an error UI to the user here.
  }

  String determinedInitialRoute = '/';
  try {
    final prefs = await SharedPreferences.getInstance();
    final bool onboardingComplete =
        prefs.getBool(onboardingCompleteKey) ?? false;
    if (!onboardingComplete) {
      determinedInitialRoute = '/onboarding';
    }
    debugPrint(
        "[main] Onboarding complete: $onboardingComplete, Initial route: $determinedInitialRoute");
  } catch (e) {
    debugPrint(
        "❌ Error checking onboarding status: $e. Defaulting to '$determinedInitialRoute'");
  }

  final GoRouter router =
      createRouter(rootNavigatorKey, initialLocation: determinedInitialRoute);
  debugPrint("GoRouter created with initial route: $determinedInitialRoute");

  runApp(
    ProviderScope(
      overrides: [
        navigatorKeyProvider.overrideWithValue(rootNavigatorKey),
      ],
      child: PeekApp(router: router),
    ),
  );
  debugPrint("--- main() Finished: runApp called ---");
}

class PeekApp extends ConsumerStatefulWidget {
  final GoRouter router;
  const PeekApp({super.key, required this.router});

  @override
  ConsumerState<PeekApp> createState() => _PeekAppState();
}

class _PeekAppState extends ConsumerState<PeekApp> {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  void initState() {
    super.initState();
    debugPrint("[PeekApp] initState called.");
    _initializeIAPListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ensureUserSetupAndNotifications();
      }
    });
  }

  Future<void> _ensureUserSetupAndNotifications() async {
    if (!mounted) return;
    debugPrint("[PeekApp] _ensureUserSetupAndNotifications called.");

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      debugPrint(
          "[PeekApp] Ensuring display name for user: ${currentUser.uid}");
      try {
        final firestoreService = ref.read(firestoreServiceProvider);
        await firestoreService.ensureDisplayNameExists();
        debugPrint(
            "[PeekApp] ensureDisplayNameExists completed for ${currentUser.uid}.");
      } catch (e) {
        debugPrint(
            "❌ Error in _ensureUserSetupAndNotifications (ensureDisplayNameExists): $e");
      }
    } else {
      debugPrint(
          "[PeekApp] User not authenticated in _ensureUserSetupAndNotifications.");
    }

    if (mounted) {
      await _initializeNotificationService();
    }
  }

  Future<void> _initializeNotificationService() async {
    if (!mounted) return;
    debugPrint("[PeekApp] Initializing NotificationService...");
    final notificationService = NotificationService();
    try {
      await notificationService.initialize(widget.router);
      debugPrint("[PeekApp] ✅ NotificationService initialized.");
      await notificationService.checkForInitialMessage();
      debugPrint("[PeekApp] ✅ Initial notification message check complete.");
    } catch (e) {
      debugPrint("❌ Error during NotificationService setup in PeekApp: $e");
    }
  }

  /// Sets up the listener for In-App Purchase updates.
  Future<void> _initializeIAPListener() async {
    final bool available = await InAppPurchase.instance.isAvailable();
    if (!mounted) return;
    if (!available) {
      debugPrint("⚠️ IAP is not available on this device/platform.");
      return; // Don't set up listener if IAP is unavailable
    }

    // Listen to the purchase stream
    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      (purchaseDetailsList) {
        // Pass the context directly here as _PeekAppState has access to it
        if (mounted) {
          // Check mounted before using context
          _handlePurchaseUpdates(purchaseDetailsList, context);
        }
      },
      onDone: () {
        debugPrint('🛒 Purchase stream closed');
        _purchaseSubscription?.cancel(); // Clean up listener
      },
      onError: (error) {
        debugPrint('❌ Purchase stream error: $error');
        // Handle stream errors (e.g., show error message)
      },
      cancelOnError: false, // Keep listening even if one error occurs
    );
    debugPrint("✅ IAP Purchase stream listener attached.");
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel(); // Cancel subscription on dispose
    debugPrint('🛒 Purchase stream subscription cancelled in PeekApp dispose.');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Provide the router configuration to MaterialApp.router
    // Inside main.dart or your App widget's build method

    return RootRealtimeListener(
      child: MaterialApp.router(
        title: 'PEEK',
        debugShowCheckedModeBanner: false,
        routerConfig: widget.router, // Use the router passed from main()

        theme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'Poppins',
          useMaterial3: true,
          iconTheme: const IconThemeData(
            weight: 500,
            fill: 0,
            grade: 0,
            opticalSize: 48,
            size: 24,
            color: peekAccentColor,
          ),
          colorScheme: const ColorScheme(
            brightness: Brightness.dark,
            primary: peekPrimaryColor,
            onPrimary: peekSurfaceColor,
            secondary: peekSecondaryColor,
            onSecondary: peekOnSecondaryColor,
            error: peekErrorColor,
            onError: peekOnErrorColor,
            background: peekBackgroundColor,
            onBackground: peekOnBackgroundColor,
            surface: peekSurfaceColor,
            onSurface: peekOnSurfaceColor,
            tertiary: peekAccentColor,
            onTertiary: Colors.black,
          ),
          scaffoldBackgroundColor: peekBackgroundColor,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            foregroundColor: peekOnBackgroundColor,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: peekOnBackgroundColor,
            ),
            iconTheme: IconThemeData(color: peekOnBackgroundColor),
            actionsIconTheme: IconThemeData(color: peekOnBackgroundColor),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: peekPrimaryColor,
              foregroundColor: peekSurfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              textStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              elevation: 2,
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: peekPrimaryColor,
              side: const BorderSide(color: peekPrimaryColor, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              textStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: peekSecondaryColor,
              textStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: peekSurfaceColor.withOpacity(0.8),
            labelStyle: TextStyle(
              color: peekOnSurfaceColor.withOpacity(0.9),
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            iconTheme: IconThemeData(
              color: peekOnSurfaceColor.withOpacity(0.9),
              size: 16,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            side: BorderSide.none,
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: peekSurfaceColor,
            contentTextStyle: const TextStyle(
              color: peekOnSurfaceColor,
              fontFamily: 'Poppins',
            ),
            actionTextColor: peekSecondaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
          dialogTheme: DialogTheme(
            backgroundColor: peekSurfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            titleTextStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: peekOnSurfaceColor,
            ),
            contentTextStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: peekOnSurfaceColor,
            ),
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: peekSurfaceColor,
            selectedItemColor: peekPrimaryColor,
            unselectedItemColor: Colors.grey.shade600,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
            ),
            type: BottomNavigationBarType.fixed,
            showUnselectedLabels: false,
            showSelectedLabels: true,
            elevation: 4,
          ),
          textTheme: const TextTheme(
            displayLarge: TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            headlineMedium: TextStyle(fontWeight: FontWeight.w600),
            titleMedium: TextStyle(fontWeight: FontWeight.w500),
            bodyMedium: TextStyle(fontWeight: FontWeight.w400, height: 1.4),
            labelLarge: TextStyle(fontWeight: FontWeight.w600),
            labelMedium: TextStyle(fontWeight: FontWeight.w500),
          ).apply(
            bodyColor: peekOnBackgroundColor,
            displayColor: peekOnBackgroundColor.withOpacity(0.9),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: peekSurfaceColor.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: peekPrimaryColor, width: 1.5),
            ),
            labelStyle: TextStyle(
              color: peekOnSurfaceColor.withOpacity(0.7),
              fontFamily: 'Poppins',
            ),
            hintStyle: TextStyle(
              color: Colors.grey.shade600,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ),
    );
  }

  // --- IAP Handling Logic (_handlePurchaseUpdates, _grantPremiumAccess, Dialogs RESTORED) ---
  /// Processes incoming purchase updates from the stream.
  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
    BuildContext context, // Keep context passed in
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
        "🛒 Processing purchase: ${purchase.productID}, Status: ${purchase.status}, Error: ${purchase.error?.message}",
      );

      // Handle Purchased or Restored states
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // 1. Grant access / Update backend (Firestore)
        final bool grantSuccess = await _grantPremiumAccess(purchase);

        // 2. Complete the purchase ONLY if grant was successful (or maybe always?)
        // Decide if you want to complete even if Firestore fails (might need manual fix later)
        if (purchase.pendingCompletePurchase) {
          if (grantSuccess) {
            // Complete only if backend update succeeded
            try {
              await InAppPurchase.instance.completePurchase(purchase);
              debugPrint(
                "✅ Purchase completed via IAP instance: ${purchase.purchaseID}",
              );

              try {
                // Optional try-catch
                await _analytics.logEvent(
                  name: purchase.status == PurchaseStatus.restored
                      ? 'purchase_restored'
                      : 'purchase', // Standard name for purchase
                  // These are standard e-commerce parameters
                  parameters: {
                    'transaction_id': purchase.purchaseID ?? 'UNKNOWN_ID',
                    'value':
                        0.0, // Placeholder - ideally get price from ProductDetails
                    'currency': 'USD', // Placeholder - ideally get currency
                    'items': [
                      {
                        'item_id': purchase.productID,
                        'item_name': purchase
                            .productID, // Or a more descriptive name if available
                        // 'item_category': 'subscription', // Optional
                        // 'price': 0.0, // Placeholder
                        'quantity': 1,
                      },
                    ],
                  },
                );
                debugPrint(
                  "[_PeekAppState] Logged ${purchase.status == PurchaseStatus.restored ? 'purchase_restored' : 'purchase'} event.",
                );
              } catch (e) {
                debugPrint("Error logging purchase/restore event: $e");
              }

              // Show success dialog only after Firestore AND completion succeed
              _showPremiumSuccessDialog(
                context,
                purchase.status == PurchaseStatus.restored,
              );
            } catch (e) {
              debugPrint("❌ Error completing purchase via IAP instance: $e");
              _showPurchaseErrorDialog(
                context,
                "Failed to finalize purchase. Restart app or contact support if status hasn't updated.",
              );
            }
          } else {
            debugPrint(
              "⚠️ Firestore grant failed, NOT completing purchase: ${purchase.purchaseID}. Requires manual check/retry.",
            );
            _showPurchaseErrorDialog(
              context,
              "Failed to save premium status. Please check connection or contact support.",
            );
          }
        } else {
          debugPrint(
            "🛒 Purchase ${purchase.purchaseID} requires no completion or already done.",
          );
          // Show restore success if it was a restore and didn't need completion
          if (purchase.status == PurchaseStatus.restored && grantSuccess) {
            try {
              // Optional try-catch
              await _analytics.logEvent(
                name: 'purchase_restored',
                parameters: {
                  'product_id': purchase.productID,
                  'purchase_id': purchase.purchaseID ?? 'UNKNOWN_ID',
                },
              );
              debugPrint(
                "[_PeekAppState] Logged purchase_restored event (no completion needed).",
              );
            } catch (e) {
              debugPrint("Error logging purchase_restored event: $e");
            }

            _showRestoreSuccessDialog(context);
          }
        }
      }
      // Handle Error state
      else if (purchase.status == PurchaseStatus.error) {
        debugPrint(
          '❌ Purchase error for ${purchase.productID}: ${purchase.error?.message} (Code: ${purchase.error?.code})',
        );

        try {
          // Optional try-catch
          await _analytics.logEvent(
            name: 'purchase_failed',
            parameters: {
              'product_id': purchase.productID,
              'error_code': purchase.error?.code ?? 'UNKNOWN',
              'error_message':
                  (purchase.error?.message ?? 'Unknown error').substring(
                0,
                99 < (purchase.error?.message ?? '').length
                    ? 99
                    : (purchase.error?.message ?? '').length,
              ),
            },
          );
          debugPrint("[_PeekAppState] Logged purchase_failed event.");
        } catch (e) {
          debugPrint("Error logging purchase_failed event: $e");
        }

        _showPurchaseErrorDialog(context, purchase.error);
        // It's often recommended to complete errored purchases too, to clear the queue
        if (purchase.pendingCompletePurchase) {
          try {
            await InAppPurchase.instance.completePurchase(purchase);
          } catch (e) {
            /* ignore completion error here */
          }
        }
      }
      // Handle Pending state
      else if (purchase.status == PurchaseStatus.pending) {
        debugPrint('⏳ Purchase pending: ${purchase.productID}');
        // TODO: Optionally show a pending indicator to the user
      }
      // Handle Canceled state
      else if (purchase.status == PurchaseStatus.canceled) {
        debugPrint('🚫 Purchase cancelled by user: ${purchase.productID}');
        try {
          // Optional try-catch
          await _analytics.logEvent(
            name: 'purchase_cancelled', // Custom event for cancellation
            parameters: {'product_id': purchase.productID},
          );
          debugPrint("[_PeekAppState] Logged purchase_cancelled event.");
        } catch (e) {
          debugPrint("Error logging purchase_cancelled event: $e");
        }
        if (purchase.pendingCompletePurchase) {
          try {
            await InAppPurchase.instance.completePurchase(purchase);
          } catch (e) {
            /* ignore completion error here */
          }
        }
      }
    }
  }

  /// Updates Firestore to grant premium access. Returns true on success, false on failure.
  Future<bool> _grantPremiumAccess(PurchaseDetails purchase) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint("⚠️ Cannot grant premium: User is null during grant attempt.");
      return false; // Indicate failure
    }
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'isPremium': true,
          'premiumPlanId': purchase.productID,
          'premiumGrantedAt': FieldValue.serverTimestamp(),
          'lastPurchaseId': purchase.purchaseID,
          'lastPurchaseTimestamp': purchase.transactionDate != null
              ? Timestamp.fromMillisecondsSinceEpoch(
                  int.parse(purchase.transactionDate!),
                )
              : null,
        },
        SetOptions(merge: true), // Merge to keep other user data safe
      );
      debugPrint(
        "✅ Premium status updated in Firestore for user $uid (Purchase/Restore)",
      );
      return true; // Indicate success
    } catch (e) {
      debugPrint(
        "❌ Failed to update Firestore for premium grant ${purchase.productID}: $e",
      );
      // Error reporting (e.g., Sentry, Crashlytics) could be useful here
      return false; // Indicate failure
    }
  }

  /// Helper to show dialogs only if the widget state is still mounted.
  void _showDialogIfMounted(
    BuildContext context,
    Widget Function(BuildContext) builder,
  ) {
    if (mounted) {
      showDialog(
        context: context,
        builder: builder,
        barrierDismissible: false,
      ); // Generally make IAP dialogs non-dismissible
    } else {
      debugPrint(
        "⚠️ Attempted to show dialog but PeekApp state is not mounted.",
      );
    }
  }

  /// Shows a success dialog after purchase or restore confirmation.
  void _showPremiumSuccessDialog(BuildContext context, bool isRestore) {
    _showDialogIfMounted(
      context,
      (dialogContext) => AlertDialog(
        title: Text(isRestore ? "Premium Restored!" : "Premium Activated!"),
        content: const Text("🎉 You now have unlimited access to Peek!"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Awesome!"),
          ),
        ],
      ),
    );
  }

  /// Shows a specific success dialog for restores if needed (distinct from purchase).
  void _showRestoreSuccessDialog(BuildContext context) {
    _showDialogIfMounted(
      context,
      (dialogContext) => AlertDialog(
        title: const Text("Purchases Restored"),
        content: const Text(
          "✅ Your existing premium access has been restored.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  /// Shows an error dialog for purchase-related issues.
  // --- MODIFIED: _showPurchaseErrorDialog (Improved Messages) ---
  /// Shows an error dialog for purchase-related issues with more user-friendly messages.
  void _showPurchaseErrorDialog(BuildContext context, Object? errorDetails) {
    String title = "Purchase Error";
    String message =
        "An unknown error occurred. Please try again later."; // Default message
    String debugInfo = ""; // Optional debug info

    if (errorDetails is IAPError) {
      // --- Handle specific IAPError codes ---
      debugInfo =
          "Code: ${errorDetails.code}, Source: ${errorDetails.source}"; // Log source
      switch (errorDetails.code) {
        // Example interpretations (codes might vary slightly by platform/store)
        // Refer to specific documentation for Google Play Billing / StoreKit error codes
        case 'user_cancelled': // Or similar platform-specific code
          // This might be handled by PurchaseStatus.canceled, but can sometimes appear as an error
          message = "The purchase was cancelled.";
          break;
        case 'payment_declined': // Or similar code
        case 'billing_unavailable': // Or similar code
        case 'payment_invalid': // Or similar code
          message =
              "Payment failed. Please check your payment method or try again later.";
          break;
        case 'item_unavailable': // Or similar code
        case 'item_already_owned': // Or similar code (usually handled by restore)
          message = "This item is currently unavailable or already owned.";
          break;
        case 'store_network_error': // Or similar code
        case 'network_error': // Generic network
          message =
              "Could not connect to the store. Please check your connection and try again.";
          break;
        case 'developer_error': // Or similar code
          message = "A configuration error occurred. Please contact support.";
          break;
        // Add more specific cases as needed based on testing and observed errors
        default:
          // Fallback for other IAPError codes
          message =
              "An error occurred during the purchase (${errorDetails.code}). Please try again.";
          break;
      }
    } else if (errorDetails is String) {
      // Handle custom string errors (e.g., from Firestore grant failure)
      message = errorDetails; // Use the custom message directly
      debugInfo = "Type: String";
      // } else if (errorDetails is PlatformException) {
      // Handle potential platform exceptions if they occur
      // message = "A platform error occurred: ${errorDetails.message}";
      // debugInfo = "Code: ${errorDetails.code}, Type: PlatformException";
    } else if (errorDetails != null) {
      // Generic fallback for other error types
      message = "An unexpected error occurred. Please try again.";
      debugInfo = "Type: ${errorDetails.runtimeType}";
    }

    debugPrint("Displaying purchase error dialog: $message ($debugInfo)");

    _showDialogIfMounted(
      context,
      (dialogContext) => AlertDialog(
        title: Text(title), // Keep title generic or customize further if needed
        content: Text(message), // Show the refined, user-friendly message
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
} // End of _PeekAppState
