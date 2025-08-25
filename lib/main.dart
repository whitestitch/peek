// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:peek/core/app_initializer.dart';
import 'package:peek/core/app_lifecycle_manager.dart';
import 'package:peek/features/iap/iap_manager.dart';
import 'package:peek/features/peek/peek_dialog_manager.dart';
import 'package:peek/features/peek/providers/peek_providers.dart';
import 'package:peek/core/providers/session_providers.dart';
import 'package:peek/core/session_manager.dart';
import 'package:peek/core/router.dart';
import 'package:peek/theme/colors.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // Initialize all core app dependencies
  await AppInitializer.initialize();

  runApp(
    ProviderScope(
      overrides: [navigatorKeyProvider.overrideWithValue(rootNavigatorKey)],
      child: const PeekApp(),
    ),
  );
}

class PeekApp extends ConsumerStatefulWidget {
  const PeekApp({super.key});

  @override
  ConsumerState<PeekApp> createState() => _PeekAppState();
}

class _PeekAppState extends ConsumerState<PeekApp> {
  late final AppLifecycleManager _lifecycleManager;
  late final IAPManager _iapManager;
  late final PeekDialogManager _dialogManager;
  late final SessionManager
      _sessionManager; // 🔒 NEW: Store session manager reference

  @override
  void initState() {
    super.initState();
    _initializeManagers();
  }

  /// Initialize all app managers
  void _initializeManagers() async {
    _lifecycleManager = AppLifecycleManager(
      ref: ref,
      navigatorKey: rootNavigatorKey,
    );
    _lifecycleManager.initialize();

    _iapManager = IAPManager(navigatorKey: rootNavigatorKey);
    _iapManager.initialize();

    _dialogManager = PeekDialogManager(
      navigatorKey: rootNavigatorKey,
      ref: ref,
    );
    _dialogManager.initialize(); // Initialize the dialog manager

    // Initialize session manager
    _sessionManager = ref.read(sessionManagerProvider);

    // 🔒 NEW: Set up callback to automatically update providers when session state changes
    _sessionManager.setStateChangeCallback(
        (state, requestId, isInSession, canReceivePeeks) {
      debugPrint(
          '🔒 [PeekApp] Session state changed: $state, canReceivePeeks: $canReceivePeeks');

      // Update all session state providers
      ref.read(sessionStateProvider.notifier).state = state;
      ref.read(sessionRequestIdProvider.notifier).state = requestId;
      ref.read(isInSessionProvider.notifier).state = isInSession;
      ref.read(canReceivePeeksProvider.notifier).state = canReceivePeeks;
    });

    await _sessionManager.initialize();

    // Update session state providers with initial state
    ref.read(sessionStateProvider.notifier).state =
        _sessionManager.currentState;
    ref.read(sessionRequestIdProvider.notifier).state =
        _sessionManager.currentRequestId;
    ref.read(isInSessionProvider.notifier).state = _sessionManager.isInSession;
    ref.read(canReceivePeeksProvider.notifier).state =
        _sessionManager.canReceivePeekRequests();

    debugPrint('🔒 [PeekApp] SessionManager initialized');
  }

  @override
  void dispose() {
    _lifecycleManager.dispose();
    _iapManager.dispose();
    _dialogManager.dispose();
    _sessionManager.dispose(); // 🔒 NEW: Dispose session manager
    super.dispose();
  }

  /// 🔒 ENHANCED: Show synchronized cancellation panel
  void _showSyncedCancellationPanel(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // Auto-close after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (ctx.mounted) {
            Navigator.of(ctx).pop();
          }
        });

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(30, 40, 30, 80),
          decoration: const BoxDecoration(
            color: peekBackgroundColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel_outlined,
                  size: 60, color: Colors.white70),
              const SizedBox(height: 20),
              const Text("Peekio Stopped",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const SizedBox(height: 10),
              const Text("The sender stopped the Peekio request.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: peekSecondaryColor,
                    foregroundColor: peekSurfaceColor,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('OK',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 🔒 ENHANCED: Show synchronized timeout panel
  void _showSyncedTimeoutPanel(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // Auto-close after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (ctx.mounted) {
            Navigator.of(ctx).pop();
          }
        });

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(30, 40, 30, 80),
          decoration: const BoxDecoration(
            color: peekBackgroundColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_off_outlined,
                  size: 60, color: Colors.white70),
              const SizedBox(height: 20),
              const Text("Time's Up!",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const SizedBox(height: 10),
              const Text("The peek request has expired.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: peekSecondaryColor,
                    foregroundColor: peekSurfaceColor,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('OK',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // 🔒 ENHANCED: Listen for session-aware peek request changes and handle dialogs
    // This provider will automatically filter out requests when user is in session
    ref.listen<AsyncValue<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>(
      sessionAwarePendingRequestsProvider,
      (previous, next) {
        next.whenData((requests) async {
          debugPrint(
              '📋 [PeekApp] Handling ${requests.length} session-aware pending requests');
          await _dialogManager.handlePendingRequests(requests);
        });
      },
    );

    // 🔒 ENHANCED: Listen for status changes to show synchronized panels
    ref.listen<AsyncValue<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>(
      requestStatusChangesProvider,
      (previous, next) {
        next.whenData((statusChanges) async {
          for (final request in statusChanges) {
            final data = request.data();
            final status = data['status'] as String?;
            final requestId = request.id;

            debugPrint(
                '🔒 [PeekApp] Status change detected: $requestId -> $status');

            // Show appropriate panel based on status
            if (status == 'cancelled_by_sender') {
              debugPrint(
                  '🔒 [PeekApp] Showing cancellation panel for $requestId');
              _dialogManager
                  .dismissActiveDialog(); // Close any active dialog first
              await Future.delayed(
                  const Duration(milliseconds: 100)); // Small delay
              final context = rootNavigatorKey.currentContext;
              if (context != null && context.mounted) {
                _showSyncedCancellationPanel(context);
              }
              break; // Handle one at a time
            } else if (status == 'expired' ||
                status == 'timeout' ||
                status == 'timed_out') {
              debugPrint(
                  '🔒 [PeekApp] Showing timeout panel for $requestId (status: $status)');
              _dialogManager
                  .dismissActiveDialog(); // Close any active dialog first
              await Future.delayed(
                  const Duration(milliseconds: 100)); // Small delay
              final context = rootNavigatorKey.currentContext;
              if (context != null && context.mounted) {
                _showSyncedTimeoutPanel(context);
              }
              break; // Handle one at a time
            }
          }
        });
      },
    );

    // 🔒 NEW: Listen for route changes to dismiss active dialogs
    // We'll use a simpler approach - dismiss dialogs when pending requests change
    // This ensures dialogs are cleaned up when navigation occurs

    // Note: Cancellation events are now handled directly by individual pages
    // No need for centralized cancellation provider

    return MaterialApp.router(
      title: 'PEEK',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: _buildAppTheme(),
    );
  }

  /// Build the complete app theme
  ThemeData _buildAppTheme() {
    return ThemeData(
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
            fontSize: 18,
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
        backgroundColor: peekSurfaceColor.withValues(alpha: 0.8),
        labelStyle: TextStyle(
          color: peekOnSurfaceColor.withValues(alpha: 0.9),
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        iconTheme: IconThemeData(
          color: peekOnSurfaceColor.withValues(alpha: 0.9),
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
        displayColor: peekOnBackgroundColor.withValues(alpha: 0.9),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: peekSurfaceColor.withValues(alpha: 0.5),
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
          color: peekOnSurfaceColor.withValues(alpha: 0.7),
          fontFamily: 'Poppins',
        ),
        hintStyle: TextStyle(
          color: Colors.grey.shade600,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}
