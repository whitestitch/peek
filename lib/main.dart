// main.dart
import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';

import 'package:peek/core/router.dart';

import 'package:peek/features/onboarding/terms_acceptance_screen.dart';
import 'package:peek/services/terms_service.dart';

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

import 'services/notification_service.dart';
import 'package:http/http.dart' as http;

import 'package:peek/features/auth/auth_wrapper.dart';

// Assuming initializeCameras is defined in photo_capture_page.dart or a utility file
import 'features/peek/photo_capture_page.dart';
import 'package:peek/core/firestore_service.dart';
// For navigatorKeyProvider
import 'package:peek/features/peek/providers/peek_providers.dart';

import 'core/router.dart';

import 'services/notification_service.dart';

void testEmulatorConnection() async {
  // Use the Firestore port or Emulator UI port that worked in your browser
  final url = Uri.parse('http://192.168.1.4:8080'); // Or :4000 for Emulator UI
  try {
    final response = await http.get(url);
    print('APP HTTP TEST: Status Code: ${response.statusCode}');
    print('APP HTTP TEST: Response Body: ${response.body}');
  } catch (e) {
    print('APP HTTP TEST: Error: $e');
  }
}

Future<void> createTestUsersInEmulator() async {
  if (!kDebugMode) return;

  try {
    debugPrint("🧪 Creating test users in emulator...");

    // Create multiple test users
    final testUsers = [
      {
        'uid': 'test_user_alice_001',
        'displayName': 'Alice (Test)',
        'createdAt': FieldValue.serverTimestamp(),
        'isTestUser': true,
        'availableForPeek': true,
        'lastSeenAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'test_user_bob_002',
        'displayName': 'Bob (Test)',
        'createdAt': FieldValue.serverTimestamp(),
        'isTestUser': true,
        'availableForPeek': true,
        'lastSeenAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'test_user_charlie_003',
        'displayName': 'Charlie (Test)',
        'createdAt': FieldValue.serverTimestamp(),
        'isTestUser': true,
        'availableForPeek': true,
        'lastSeenAt': FieldValue.serverTimestamp(),
      }
    ];

    for (final user in testUsers) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user['uid'] as String)
          .set(user, SetOptions(merge: true));
    }

    debugPrint("✅ Created ${testUsers.length} test users in emulator");
  } catch (e) {
    debugPrint("❌ Failed to create test users: $e");
  }
}

/// Set this to true when you run `firebase emulators:start`.
const bool useFirebaseEmulator =
    bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: false);

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

// Disable Firebase Dynamic Links handling during initial setup
Future<void> _configureDynamicLinks() async {
  // Only configure dynamic links after onboarding
  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool(onboardingCompleteKey) ?? false;
  if (!onboardingComplete) {
    debugPrint(
        "🚫 Skipping Dynamic Links configuration - onboarding not complete");
    return;
  }

  // Configure dynamic links here if needed
  debugPrint("✅ Dynamic Links configuration enabled");
}

Future<void> main() async {
  // 1. Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("--- main() Started: WidgetsFlutterBinding initialized.");

  // Initialize cameras at startup
  await initializeCameras();

  // 2. Lock orientation to portrait only
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  debugPrint("✅ Background message handler registered.");

  // 3. Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  debugPrint("✅ App locked to portrait orientation.");

  FirebaseApp? defaultApp;
  bool firebaseCoreInitialized = false;
  debugPrint("Attempting robust Firebase initialization...");

  try {
    // Attempt to initialize. If it's already initialized, this will use the existing instance
    // or throw 'duplicate-app' which we handle.
    defaultApp = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint(
        "✅ Firebase.initializeApp() successful or used existing. Default app: ${defaultApp.name}");
    firebaseCoreInitialized = true;
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      debugPrint(
          "🔶 Firebase.initializeApp() threw 'duplicate-app'. Retrieving existing default app.");
      try {
        defaultApp = Firebase.app(); // Get the existing default app
        debugPrint(
            "   Successfully retrieved existing [DEFAULT] app: ${defaultApp.name}");
        firebaseCoreInitialized =
            true; // Mark as initialized because an app instance exists
      } catch (eDefault) {
        debugPrint(
            "   ❌ CRITICAL: Failed to retrieve existing [DEFAULT] app after 'duplicate-app': $eDefault");
        // firebaseCoreInitialized remains false
      }
    } else {
      debugPrint(
          "❌ CRITICAL: Firebase.initializeApp() failed with FirebaseException: ${e.code} - ${e.message}");
      // firebaseCoreInitialized remains false
    }
  } catch (e) {
    debugPrint(
        "❌ CRITICAL: Unexpected generic error during Firebase.initializeApp(): $e");
    // firebaseCoreInitialized remains false
  }

  if (!firebaseCoreInitialized && Firebase.apps.isNotEmpty) {
    // Fallback: If initializeApp failed but an app somehow exists (e.g., from a plugin)
    debugPrint(
        "⚠️ Firebase.initializeApp() failed, but Firebase.apps is not empty. Attempting to use existing default app.");
    try {
      defaultApp = Firebase.app();
      firebaseCoreInitialized = true;
      debugPrint("   Using existing default app: ${defaultApp.name}");
    } catch (e) {
      debugPrint(
          "   ❌ Failed to get existing default app even when Firebase.apps not empty: $e");
    }
  }

  if (kDebugMode && firebaseCoreInitialized && defaultApp != null) {
    // Call the function to test basic HTTP
    testEmulatorConnection();

    Future<String> getEmulatorHost() async {
      if (Platform.isIOS) {
        try {
          final deviceInfo = await DeviceInfoPlugin().iosInfo;

          debugPrint(
              "🔍 iOS Device Detection - isPhysicalDevice: ${deviceInfo.isPhysicalDevice}");
          debugPrint("🔍 Device model: ${deviceInfo.model}");
          debugPrint("🔍 Device name: ${deviceInfo.name}");

          if (deviceInfo.isPhysicalDevice) {
            // For physical devices, first try to validate the connection
            debugPrint(
                "📱 Detected PHYSICAL device - validating network connection...");

            // Try multiple common local IPs
            final myMachineIP =
                '192.168.1.4'; // <-- UPDATE THIS with your actual IP

            // Try multiple possible IPs including your machine's actual IP
            final possibleHosts = [
              myMachineIP, // Your machine's actual IP
              '192.168.1.2', // Common router gateway
              '192.168.1.3', // Alternative
              '192.168.0.2', // Different subnet
              '192.168.0.3',
              '192.168.0.4',
              '10.0.0.2', // Alternative network range
              '172.20.10.2', // iPhone hotspot range
            ];

            debugPrint("🔍 Trying to find emulator host from: $possibleHosts");

            for (final host in possibleHosts) {
              try {
                debugPrint("🔄 Testing connection to $host:8080...");
                final testUrl = Uri.parse('http://$host:8080');
                final response = await http.get(testUrl).timeout(
                      const Duration(seconds: 2),
                      onTimeout: () => throw TimeoutException(
                          'Connection timeout for $host'),
                    );
                // Check for Firestore emulator response
                if (response.statusCode == 200 ||
                    response.statusCode == 404 ||
                    response.body.contains('Firestore')) {
                  debugPrint("✅ Successfully connected to emulator at $host!");
                  return host;
                }
              } catch (e) {
                debugPrint(
                    "❌ Failed to connect to $host: ${e.toString().split('\n').first}");
              }
            }

            // If all fail, show detailed instructions
            debugPrint("⚠️ ERROR: Could not connect to any emulator host!");
            debugPrint("📱 PHYSICAL DEVICE SETUP INSTRUCTIONS:");
            debugPrint(
                "   1. On your Mac, run: ifconfig | grep 'inet ' | grep -v 127.0.0.1");
            debugPrint("   2. Find your IP (usually starts with 192.168.x.x)");
            debugPrint(
                "   3. Update the 'myMachineIP' variable in main.dart with this IP");
            debugPrint(
                "   4. Ensure both devices are on the same WiFi network");
            debugPrint(
                "   5. Restart the Firebase emulators with: firebase emulators:start --host 0.0.0.0");
            debugPrint(
                "   6. On Mac, check Firewall settings in System Preferences > Security & Privacy");

            // Still return a default but we know it won't work
            return myMachineIP;
          } else {
            debugPrint("💻 Detected SIMULATOR - using localhost");
            return 'localhost';
          }
        } catch (e) {
          debugPrint("❌ Error detecting device type: $e");
          // Fallback: if we can't detect, assume physical device for safety
          debugPrint("⚠️ Falling back to IP address for physical device");
          return '192.168.1.4';
        }
      }
      // For Android and other platforms
      return 'localhost';
    }

    try {
      debugPrint(
          "🔧 Configuring Firebase Emulators IMMEDIATELY after Firebase init, BEFORE any authentication");

      final host = await getEmulatorHost();
      const androidHost = '10.0.2.2';

      final finalHost = Platform.isAndroid ? androidHost : host;

      debugPrint("🔧 Using host: $host for emulator connections");

      bool emulatorsAccessible = false;

      try {
        final testUrl = Uri.parse('http://$host:8080');
        final testResponse = await http.get(testUrl).timeout(
              const Duration(seconds: 3),
              onTimeout: () =>
                  throw TimeoutException('Emulator connection test timeout'),
            );
        emulatorsAccessible = true;
        debugPrint("✅ Emulators are accessible at $host");
      } catch (e) {
        debugPrint("❌ WARNING: Cannot reach emulators at $host: $e");
        debugPrint(
            "❌ The app will continue but Firestore operations will fail!");

        // Show a warning dialog on physical device
        if (Platform.isIOS &&
            await DeviceInfoPlugin()
                .iosInfo
                .then((info) => info.isPhysicalDevice)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (rootNavigatorKey.currentContext != null) {
              showDialog(
                context: rootNavigatorKey.currentContext!,
                builder: (context) => AlertDialog(
                  title: const Text('Emulator Connection Failed'),
                  content: const Text(
                    'Cannot connect to Firebase Emulators.\n\n'
                    'Please ensure:\n'
                    '1. Local Network permission is granted\n'
                    '2. Emulators are running on your machine\n'
                    '3. Both devices are on the same network',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
          });
        }
      }

      // Configure Auth Emulator FIRST
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      debugPrint("✅ Auth Emulator configured for -> $host:9099");

      // Configure Firestore Emulator using Settings (more reliable for iOS)
      FirebaseFirestore.instance.settings = Settings(
        host: '$host:8080',
        sslEnabled: false,
        persistenceEnabled: false,
      );
      debugPrint(
          "✅ Firestore Emulator configured using Settings for -> $host:8080");

      // Configure Functions Emulator
      FirebaseFunctions.instanceFor(region: "us-central1")
          .useFunctionsEmulator(host, 5001);
      debugPrint("✅ Functions Emulator configured for -> $host:5001");

      debugPrint("✅ All Firebase Emulators configured successfully");

      // await Future.delayed(const Duration(seconds: 1));
      // await createTestUsersInEmulator();
    } catch (e) {
      debugPrint("❌ Critical error configuring Firebase Emulators: $e");
    }
  } else if (kDebugMode) {
    debugPrint(
        "⚠️ Emulator configuration skipped - Debug: $kDebugMode, Initialized: $firebaseCoreInitialized");
  }

  runApp(
    ProviderScope(
      overrides: [
        navigatorKeyProvider.overrideWithValue(rootNavigatorKey),
      ],
      child: const PeekApp(),
    ),
  );

  debugPrint("--- main() Finished: runApp called ---");
}

class PeekApp extends ConsumerStatefulWidget {
  const PeekApp({super.key});

  @override
  ConsumerState<PeekApp> createState() => _PeekAppState();
}

class _PeekAppState extends ConsumerState<PeekApp> with WidgetsBindingObserver {
  // StreamSubscription? _directFirestoreListener;
  // ---------
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  final Set<String> _processedRequestIds = <String>{};
  bool _isShowingDialog = false;

  String? _pendingDialogRequestId;

  @override
  void initState() {
    super.initState();
    debugPrint("[PeekApp] initState called.");
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _pendingDialogRequestId != null) {
          // Try to show any pending dialog
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          if (currentUserId != null) {
            ref.invalidate(pendingPeekRequestsProvider);
          }
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint("[PeekApp] App resumed - refreshing peek requests");
      // Just invalidate - the listener in build will handle the rest
      ref.invalidate(pendingPeekRequestsProvider);
    }
  }

  void _initializeApp() async {
    _initializeIAPListener();

    // In debug mode, AWAIT sign-out to ensure a clean slate before attaching listeners.
    // This is the key fix to prevent the race condition.
    if (kDebugMode) {
      debugPrint("[PeekApp] Debug mode: Signing out for a fresh start...");
      await FirebaseAuth.instance.signOut();
      debugPrint("[PeekApp] ✅ Sign-out complete.");
    }

    // Attach the listener AFTER the initial state has been settled.
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted && user != null) {
        debugPrint("[PeekApp] Auth state changed - user: ${user.uid}");
        _initializeUser(user);
      } else if (user == null) {
        debugPrint("[PeekApp] Auth state changed - user signed out");
        _processedRequestIds.clear();
        _isShowingDialog = false;
      }
    });
  }

  Future<void> _initializeUser(User user) async {
    debugPrint("[PeekApp] Initializing user setup for ${user.uid}");

    final firestoreService = ref.read(firestoreServiceProvider);
    await firestoreService.ensureDisplayNameExists();

    await _initializeFCMToken();
    await _initializeNotificationService();

    _processedRequestIds.clear();
    _isShowingDialog = false;

    // Re-setup peek request listener for new user
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _setupPeekRequestListener();
    // });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _purchaseSubscription?.cancel();

    debugPrint('🛒 Purchase stream subscription cancelled in PeekApp dispose.');
    debugPrint("[DirectFirestoreListener] Cancelled in dispose.");
    super.dispose();
  }

  void _handleNewPeekRequest(
      QueryDocumentSnapshot<Map<String, dynamic>> requestDoc) {
    final requestId = requestDoc.id;

    // Set the new provider to track that this dialog is now active.
    ref.read(activePeekRequestDialogProvider.notifier).state = requestId;
    debugPrint(
        "[PeekApp] Set activePeekRequestDialogProvider to: $requestId. Showing dialog.");

    showDialog<void>(
      context: rootNavigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('New Peek Request!'),
        content: const Text('Someone wants to share a peek with you. Accept?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _declinePeekRequest(requestId);
            },
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _acceptPeekRequest(requestId);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    ).then((_) {
      // When the dialog is closed for any reason, clear the provider.
      final activeDialogId = ref.read(activePeekRequestDialogProvider);
      if (activeDialogId == requestId) {
        ref.read(activePeekRequestDialogProvider.notifier).state = null;
        debugPrint(
            "[PeekApp] Dialog for $requestId closed, cleared activePeekRequestDialogProvider.");
      }
    });
  }

  // Fix the _showReliablePeekRequestDialog method (Lines 560-640)
//   void _showReliablePeekRequestDialog(
//       QueryDocumentSnapshot<Map<String, dynamic>> requestDoc) {
//     final requestId = requestDoc.id;

//     // Wait for navigator to be ready using a more reliable method
//     void attemptShowDialog() {
//       // Try multiple context sources
//       BuildContext? dialogContext;

//       // First try: root navigator key
//       if (rootNavigatorKey.currentContext != null) {
//         dialogContext = rootNavigatorKey.currentContext!;
//       }
//       // Second try: current widget context if mounted
//       else if (mounted && context.mounted) {
//         dialogContext = context;
//       }

//       if (dialogContext == null || !mounted) {
//         // Retry after a short delay if context not ready
//         if (mounted) {
//           Future.delayed(const Duration(milliseconds: 200), attemptShowDialog);
//         }
//         return;
//       }

//       _isShowingDialog = true;
//       debugPrint("[PeekApp] Showing dialog for request: $requestId");

//       // Use simple showDialog approach
//       showDialog<bool>(
//         context: dialogContext,
//         barrierDismissible: false,
//         builder: (BuildContext dialogContext) => AlertDialog(
//           title: const Text('New Peek Request!'),
//           content:
//               const Text('Someone wants to share a peek with you. Accept?'),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(dialogContext).pop(false);
//                 _onDialogClosed();
//                 _declinePeekRequest(requestId);
//               },
//               child: const Text('Decline'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.of(dialogContext).pop(true);
//                 _onDialogClosed();
//                 _acceptPeekRequest(requestId);
//               },
//               child: const Text('Accept'),
//             ),
//           ],
//         ),
//       ).then((result) {
//         // Ensure dialog state is cleaned up
//         if (_isShowingDialog) {
//           _onDialogClosed();
//         }
//       });
//     }

//     // Wait for the next frame before attempting to show dialog
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (mounted) {
//         attemptShowDialog();
//       }
//     });
//   }

// // Add these methods at class level (after _showReliablePeekRequestDialog)
//   void _onDialogClosed() {
//     _isShowingDialog = false;
//   }

  Future<void> _initializeFCMToken() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission for notifications
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint("✅ FCM notification permission granted");

        // Get FCM token
        String? token = await messaging.getToken();
        if (token != null && FirebaseAuth.instance.currentUser != null) {
          // Use existing FirestoreService to save token
          final firestoreService = ref.read(firestoreServiceProvider);
          await firestoreService.updateUserPreference({'fcmToken': token});
          debugPrint(
              "✅ FCM token saved via FirestoreService: ${token.substring(0, 20)}...");
        }

        // Listen for token refresh
        messaging.onTokenRefresh.listen((newToken) async {
          if (FirebaseAuth.instance.currentUser != null) {
            final firestoreService = ref.read(firestoreServiceProvider);
            await firestoreService.updateUserPreference({'fcmToken': newToken});
            debugPrint(
                "✅ FCM token refreshed and updated via FirestoreService");
          }
        });
      } else {
        debugPrint("❌ FCM notification permission denied");
      }
    } catch (e) {
      debugPrint("❌ Error initializing FCM token: $e");
    }
  }

  /// Accept peek request
  Future<void> _acceptPeekRequest(String requestId) async {
    debugPrint(
        "✅ [PeekApp] _acceptPeekRequest CALLED for request: $requestId. Mounted: $mounted");
    try {
      if (!mounted) {
        debugPrint(
            "❌ [PeekApp] _acceptPeekRequest: NOT MOUNTED for request: $requestId");
        return;
      }

      await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(requestId)
          .update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
          "✅ [PeekApp] Peek request $requestId status updated to 'accepted' in Firestore.");

      ref
          .read(routerProvider)
          .go('/capture?requestId=$requestId&mode=response');

      debugPrint(
          "✅ [PeekApp] NAVIGATED (or attempted to navigate) to /capture for request: $requestId");
    } catch (e) {
      debugPrint('❌ Error in _acceptPeekRequest: $e');
      if (mounted) {
        // Use rootNavigatorKey.currentContext for ScaffoldMessenger
        final scaffoldMessengerContext = rootNavigatorKey.currentContext;
        if (scaffoldMessengerContext != null) {
          ScaffoldMessenger.of(scaffoldMessengerContext).showSnackBar(
            SnackBar(
              content: Text('Failed to accept peek: ${e.toString()}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        } else {
          debugPrint(
              "❌ _acceptPeekRequest: rootNavigatorKey.currentContext is null, cannot show SnackBar.");
        }
      }
    }
  }

  /// Decline peek request
  Future<void> _declinePeekRequest(String requestId) async {
    debugPrint(
        "✅ [PeekApp] _declinePeekRequest CALLED for request: $requestId. Mounted: $mounted");
    try {
      await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(requestId)
          .update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
          '✅ Peek request $requestId status updated to declined in Firestore.');
    } catch (e) {
      debugPrint('❌ Error declining peek request: $e');
      if (mounted) {
        // Use rootNavigatorKey.currentContext for ScaffoldMessenger
        final scaffoldMessengerContext = rootNavigatorKey.currentContext;
        if (scaffoldMessengerContext != null) {
          ScaffoldMessenger.of(scaffoldMessengerContext).showSnackBar(
            SnackBar(
              content: Text('Failed to decline peek: ${e.toString()}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        } else {
          debugPrint(
              "❌ _declinePeekRequest: rootNavigatorKey.currentContext is null, cannot show SnackBar.");
        }
      }
    }
  }

  Future<void> _initializeNotificationService() async {
    if (!mounted) return;
    debugPrint("[PeekApp] Initializing NotificationService...");

    if (Platform.isIOS) {
      try {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken != null) {
          debugPrint("[NotificationService] APNs token: $apnsToken");
        } else {
          debugPrint(
              "[NotificationService] APNs token was null. This is expected on simulators if not configured for remote notifications.");
        }
      } catch (e) {
        debugPrint("❌ Failed to fetch APNs token: $e");
      }
    }

    final notificationService =
        NotificationService(navigatorKey: rootNavigatorKey);
    try {
      await notificationService.initialize(ref.read(routerProvider));
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
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // This listener handles showing AND hiding the dialog for NEW incoming peek requests.
    ref.listen<AsyncValue<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>(
      pendingPeekRequestsProvider,
      (previous, next) {
        next.whenData((requests) {
          final requestIds = requests.map((req) => req.id).toSet();
          debugPrint(
              "[PeekApp] Pending peek requests updated: ${requests.length} requests. IDs: $requestIds");

          // Check if the currently active dialog corresponds to a request that is no longer pending.
          final activeDialogId = ref.read(activePeekRequestDialogProvider);
          if (activeDialogId != null && !requestIds.contains(activeDialogId)) {
            debugPrint(
                "[PeekApp] Active dialog for request $activeDialogId is no longer pending. Closing dialog.");
            // Pop the dialog if its request is no longer in the pending list.
            if (rootNavigatorKey.currentContext != null &&
                Navigator.of(rootNavigatorKey.currentContext!).canPop()) {
              Navigator.of(rootNavigatorKey.currentContext!).pop();
            }
            ref.read(activePeekRequestDialogProvider.notifier).state = null;
          }

          // Show a dialog for the first new request, if no dialog is already showing.
          if (ref.read(activePeekRequestDialogProvider) == null) {
            if (requests.isNotEmpty) {
              _handleNewPeekRequest(requests.first);
            }
          }
        });
      },
    );

    // This return statement now includes your full theme.
    return MaterialApp.router(
      title: 'PEEK',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
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
        dialogTheme: DialogThemeData(
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
                      : 'purchase',
                  parameters: {
                    'transaction_id': purchase.purchaseID ?? 'UNKNOWN_ID',
                    'value': 0.0,
                    'currency': 'USD',
                    'item_id': purchase.productID,
                    'item_name': purchase.productID,
                    'quantity': 1,
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
    BuildContext callingContext,
    Widget Function(BuildContext) builder,
  ) {
    if (!mounted) {
      debugPrint(
          "⚠️ Attempted to show dialog but _PeekAppState is not mounted.");
      return;
    }
    final BuildContext dialogCtx =
        rootNavigatorKey.currentContext ?? callingContext;

    try {
      MaterialLocalizations.of(dialogCtx);
      showDialog(
        context: dialogCtx,
        builder: builder,
        barrierDismissible: false,
      );
    } catch (e) {
      debugPrint(
          "⚠️ _showDialogIfMounted: dialogCtx ($dialogCtx) from (rootKey: ${rootNavigatorKey.currentContext}, calling: $callingContext) is not valid. Error: $e");
      try {
        // Fallback to ScaffoldMessenger with callingContext
        ScaffoldMessenger.of(callingContext).showSnackBar(const SnackBar(
            content: Text("Error displaying dialog. Please try again later.")));
      } catch (snackbarError) {
        debugPrint(
            "⚠️ Could not show SnackBar with callingContext: $snackbarError");
      }
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
}
