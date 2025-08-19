// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:peek/core/app_initializer.dart';
import 'package:peek/core/app_lifecycle_manager.dart';
import 'package:peek/features/iap/iap_manager.dart';
import 'package:peek/features/peek/peek_dialog_manager.dart';
import 'package:peek/features/peek/providers/peek_providers.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeManagers();
  }

  /// Initialize all app managers
  void _initializeManagers() {
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
  }

  @override
  void dispose() {
    _lifecycleManager.dispose();
    _iapManager.dispose();
    _dialogManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Listen for peek request changes and handle dialogs
    // Handle requests immediately - dialog manager will handle context checks
    ref.listen<AsyncValue<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>(
      pendingPeekRequestsProvider,
      (previous, next) {
        next.whenData((requests) {
          debugPrint(
              '📋 [PeekApp] Handling ${requests.length} pending requests');
          _dialogManager.handlePendingRequests(requests);
        });
      },
    );

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
    );
  }
}
