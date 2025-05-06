// lib/features/home/home_page.dart
import 'dart:async'; // For Timer
import 'package:flutter/material.dart' as material;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peek/shared/upgrade_prompt_dialog.dart';
import 'package:peek/core/feature_flags.dart';
import 'package:peek/features/peek/controllers/peek_controller.dart';
import 'package:flutter/foundation.dart' show kDebugMode; // For debug button
import 'package:peek/theme/colors.dart';
import 'package:rive/rive.dart';

// Import the premium status provider
import 'package:peek/features/premium/providers/premium_controller.dart'; // Corrected typo if any
import '../menu/drawer_menu.dart'; // Keep existing drawer import

// --- userDataProvider (Keep as is) ---
final userDataProvider = StreamProvider<DocumentSnapshot<Map<String, dynamic>>>(
  (ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.empty();
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  },
);

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Timer? _rebuildTimerForCooldown;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    material.WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkPromoModal();
    });
  }

  @override
  void dispose() {
    _rebuildTimerForCooldown?.cancel();
    super.dispose();
  }

  // --- _checkPromoModal (Keep as is, but verify premiumStatusProvider import) ---
  Future<void> _checkPromoModal() async {
    // ... (Keep existing code, ensure premiumStatusProvider is correctly imported and used) ...
    if (!FeatureFlags.showIntroScreens || !mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastShown = prefs.getInt('upgradePromoLastShown') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      const sevenDaysInMillis = 7 * 24 * 60 * 60 * 1000;
      final bool isPremium = ref
          .read(premiumStatusProvider)
          .maybeWhen(data: (status) => status, orElse: () => false);
      if ((now - lastShown > sevenDaysInMillis) && mounted && !isPremium) {
        await material.showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) =>
              const UpgradePromptDialog(reason: UpgradeReason.periodic),
        );
        if (mounted) await prefs.setInt('upgradePromoLastShown', now);
      }
    } catch (e) {
      print("Error checking/showing promo modal: $e");
    }
  }

  // --- _attemptStartPeeking (Keep as is) ---
  Future<void> _attemptStartPeeking() async {
    // ... (Keep existing code) ...
    final userAsyncValue = ref.read(userDataProvider);
    final userDocSnapshot = userAsyncValue.asData?.value;
    if (userDocSnapshot == null || !userDocSnapshot.exists) {
      _showErrorSnackbar('User data not available yet...');
      return;
    }
    final userData = userDocSnapshot.data()!;
    final isPremium = userData['isPremium'] == true;
    const dailyLimit = 3;
    const cooldownDuration = Duration(seconds: 60);
    final lastPeekTimestamp =
        userData['lastPeekRequestTimestamp'] as Timestamp?;
    int dailyPeekCount = userData['dailyPeekCount'] as int? ?? 0;
    final peekCountLastResetTimestamp =
        userData['peekCountLastReset'] as Timestamp?;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    bool needsDailyReset = false;
    if (!isPremium) {
      DateTime? currentCooldownEndTime;
      if (lastPeekTimestamp != null) {
        currentCooldownEndTime = lastPeekTimestamp.toDate().add(
              cooldownDuration,
            );
        if (now.isBefore(currentCooldownEndTime)) {
          final remainingSeconds =
              currentCooldownEndTime.difference(now).inSeconds;
          _showErrorSnackbar(
            'Please wait ${remainingSeconds > 0 ? remainingSeconds : 1}s.',
          );
          return;
        }
      }
      needsDailyReset = peekCountLastResetTimestamp == null ||
          peekCountLastResetTimestamp.toDate().isBefore(startOfToday);
      if (needsDailyReset) {
        print('[HomePage] Needs daily reset...');
        dailyPeekCount = 0;
      }
      if (dailyPeekCount >= dailyLimit) {
        if (!mounted) return;
        await material.showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const UpgradePromptDialog(
            reason: UpgradeReason.dailyLimitReached,
          ),
        );
        return;
      }
    }
    print(
      '[HomePage] Checks passed. Attempting peek. Needs reset: $needsDailyReset',
    );
    // Optional: Set loading state here if you have one
    // final peekNotifier = ref.read(peekControllerProvider.notifier);
    // peekNotifier.setLoadingState(); // Example
    try {
      final controller = ref.read(peekControllerProvider.notifier);
      final String targetReceiverUid = "BM7KTjYwpdbjqoXgV6ZQQKHusmv1";
      if (targetReceiverUid == "CHANGE_THIS_TEST_UID" ||
          targetReceiverUid.isEmpty) {
        _showErrorSnackbar("Error: Test Receiver UID not set.");
        return;
      }
      final requestId = await controller.createPeekRequestAndUpdateStats(
        receiverUid: targetReceiverUid,
        needsDailyReset: needsDailyReset,
      );
      // Check result AFTER await completes
      if (requestId != null && mounted) {
        // SUCCESS Case: Navigate to wait screen
        print('[HomePage] Peek request $requestId created. Navigating...');
        context.go('/wait?requestId=$requestId');
      } else if (requestId == null && mounted) {
        // FAILURE Case: Controller returned null (error occurred)
        _showErrorSnackbar('Could not start Peek. Please try again later.');
        material.debugPrint(
          "[HomePage] Peek request failed (controller returned null or user not mounted).",
        );
      }
    } catch (e) {
      if (mounted) {
        print('🔥 Error calling peek controller: $e');
        _showErrorSnackbar('An unexpected error occurred. Please try again.');
      }
    }
  }

  // --- _showErrorSnackbar (Keep as is) ---
  void _showErrorSnackbar(String message) {
    // ... (Keep existing code) ...
    if (!mounted) return;
    material.ScaffoldMessenger.of(context).removeCurrentSnackBar();
    material.ScaffoldMessenger.of(context).showSnackBar(
      material.SnackBar(
        content: material.Text(message),
        backgroundColor: material.Colors.redAccent[700],
        behavior: material.SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- _debugResetLimits (Keep as is) ---
  Future<void> _debugResetLimits() async {
    // ... (Keep existing code) ...
    print("DEBUG: Resetting limits...");
    _rebuildTimerForCooldown?.cancel();
    _rebuildTimerForCooldown = null;
    await ref.read(peekControllerProvider.notifier).debugResetUserLimits();
    if (mounted) _showErrorSnackbar("DEBUG: Limits Reset!");
    if (mounted) setState(() {});
  }

  // --- _onItemTapped (Keep as is) ---
  void _onItemTapped(int index) {
    // ... (Keep existing code) ...
    if (index == _selectedIndex) {
      print("Tapped current tab: $index");
      return;
    }
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/settings');
        break;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  material.Widget build(material.BuildContext context) {
    // *** Watch premium status for UI ***
    final AsyncValue<bool> premiumStatus = ref.watch(premiumStatusProvider);
    // *** Watch user data for logic ***
    final userAsyncValue = ref.watch(userDataProvider);
    // *** Watch controller state ***
    final peekControllerState = ref.watch(peekControllerProvider);
    final bool isLoading = peekControllerState.isLoading;

    // --- Calculation logic (Keep as is) ---
    String startButtonText = 'Start Peeking';
    bool isButtonEnabled = false;
    String? subtitle;
    bool isCooldownActive = false;
    Duration cooldownRemaining = Duration.zero;
    _rebuildTimerForCooldown?.cancel();
    _rebuildTimerForCooldown = null;
    switch (userAsyncValue) {
      case AsyncLoading(): /*...*/
        startButtonText = 'Loading User...';
        isButtonEnabled = false;
        break;
      case AsyncError(:final error): /*...*/
        startButtonText = 'Error';
        isButtonEnabled = false;
        subtitle = 'Could not load user data.';
        print("Error in userDataProvider build: $error");
        break;
      case AsyncData(:final value):
        if (!value.exists) {
          /*...*/
          startButtonText = 'Initializing...';
          isButtonEnabled = false;
          subtitle = 'Waiting for user data...';
        } else {
          final userData = value.data()!;
          final bool isPremiumFromSnapshot = userData['isPremium'] == true;
          DateTime? expectedCooldownEndTime;
          if (!isPremiumFromSnapshot) {
            /* Cooldown check */
            final lastPeekTimestamp =
                userData['lastPeekRequestTimestamp'] as Timestamp?;
            const cooldownDuration = Duration(seconds: 60);
            if (lastPeekTimestamp != null) {
              expectedCooldownEndTime = lastPeekTimestamp.toDate().add(
                    cooldownDuration,
                  );
              if (expectedCooldownEndTime.isAfter(DateTime.now())) {
                isCooldownActive = true;
                cooldownRemaining = expectedCooldownEndTime.difference(
                  DateTime.now(),
                );
              }
            }
          }
          if (isCooldownActive) {
            _rebuildTimerForCooldown = Timer(const Duration(seconds: 1), () {
              if (mounted) setState(() {});
            });
          }
          if (isLoading) {
            isButtonEnabled = false;
          } else if (isPremiumFromSnapshot) {
            /* Premium button state */
            isButtonEnabled = true;
            startButtonText = 'Start Peeking';
            subtitle = 'Unlimited peeks available!';
          } else {
            /* Free user button state & limit check */
            isButtonEnabled = true;
            startButtonText = 'Start Peeking';
            if (isCooldownActive) {
              isButtonEnabled = false;
              final seconds = (cooldownRemaining.inSeconds >= 0)
                  ? cooldownRemaining.inSeconds + 1
                  : 1;
              startButtonText = 'Cooldown (${seconds}s)';
            }
            if (isButtonEnabled) {
              int dailyPeekCount = userData['dailyPeekCount'] as int? ?? 0;
              final peekCountLastResetTimestamp =
                  userData['peekCountLastReset'] as Timestamp?;
              final now = DateTime.now();
              final startOfToday = DateTime(now.year, now.month, now.day);
              const dailyLimit = 3;
              bool needsReset = peekCountLastResetTimestamp == null ||
                  peekCountLastResetTimestamp.toDate().isBefore(startOfToday);
              if (needsReset) dailyPeekCount = 0;
              if (dailyPeekCount >= dailyLimit) {
                isButtonEnabled = false;
                subtitle = '🚫 Daily peek limit reached';
              } else {
                final rem = dailyLimit - dailyPeekCount;
                subtitle =
                    'You have ${rem >= 0 ? rem : 0} peek${rem == 1 ? '' : 's'} left today.';
              }
            }
          }
        }
        break;
    } // End switch

    const String homeBackgroundPath = 'assets/images/onboarding_bg_02.jpg';

    return material.Scaffold(
      appBar: material.AppBar(
        /* ... Keep existing AppBar ... */
        title: const material.Text('Peekio'),
        elevation: 1.0,
        actions: const [material.SizedBox(width: 48)],
        // backgroundColor: material.Theme.of(context).bottomAppBarTheme.color ??
        //     material.Theme.of(context).colorScheme.surface,
        // backgroundColor: peekBackgroundColor.withOpacity(0.5),
        backgroundColor: material.Colors.transparent,
      ),

      drawer: const DrawerMenu(), // Keep drawer

      body: material.Stack(
        // Use Stack for layering
        fit: material.StackFit.expand, // Make layers fill body
        children: [
          // --- Layer 1: Background Image ---
          material.Image.asset(
            homeBackgroundPath, // Use defined path
            fit: material.BoxFit.cover, // Cover the entire area
            errorBuilder: (context, error, stackTrace) {
              material.debugPrint("Error loading home background: $error");
              // Fallback solid color if image fails
              return material.Container(color: peekBackgroundColor);
            },
          ),

          material.Center(
            // Use premiumStatus.when for top-level loading/error of premium flag
            child: premiumStatus.when(
              loading: () => const material.CircularProgressIndicator(),
              error: (e, _) => _buildErrorUI('Error loading status.'),
              data: (isPremiumForUI) {
                // isPremiumForUI used ONLY for UI elements
                // Use userAsyncValue.when for main content based on user data snapshot
                return userAsyncValue.when(
                  loading: () => const material.CircularProgressIndicator(),
                  error: (e, _) => _buildErrorUI('Error loading user data.'),
                  data: (doc) {
                    if (!doc.exists) {
                      return _buildErrorUI("Waiting for user data...");
                    }
                    // *** FIX: Wrap Column in SingleChildScrollView ***
                    return material.SingleChildScrollView(
                      // <--- ADDED THIS
                      child: material.Padding(
                        // Keep existing padding
                        padding: const material.EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 30.0, // Increased vertical padding slightly
                        ),
                        child: material.Column(
                          // The Column that was overflowing
                          mainAxisAlignment: material.MainAxisAlignment.center,
                          // *** FIX: Added mainAxisSize ***
                          mainAxisSize:
                              material.MainAxisSize.min, // <--- ADDED THIS
                          children: [
                            if (kDebugMode) // Debug Button
                              material.Padding(
                                /* ... Keep debug button ... */
                                padding: const material.EdgeInsets.only(
                                    bottom: 20.0),
                                child: material.OutlinedButton.icon(
                                  icon: const material.Icon(
                                    material.Icons.refresh,
                                    size: 18,
                                    color: material.Colors.orangeAccent,
                                  ),
                                  label: const material.Text(
                                    "DEBUG: Reset Limits",
                                    style: material.TextStyle(
                                        color: material.Colors.orangeAccent),
                                  ),
                                  onPressed:
                                      isLoading ? null : _debugResetLimits,
                                  style: material.OutlinedButton.styleFrom(
                                    side: material.BorderSide(
                                      color: isLoading
                                          ? material.Colors.grey
                                          : material.Colors.orangeAccent,
                                    ),
                                    padding:
                                        const material.EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                  ),
                                ),
                              ),

                            // *** Use isPremiumForUI for the badge display ***
                            _buildWelcomeArea(
                              context,
                              isPremiumForUI,
                            ), // <--- PASS isPremiumForUI

                            const material.SizedBox(height: 20),
                            // Subtitle Area (logic uses data from snapshot)
                            material.Container(
                              /* ... Keep subtitle container ... */
                              height: 24,
                              alignment: material.Alignment.center,
                              child: subtitle != null
                                  ? material.Text(
                                      subtitle,
                                      textAlign: material.TextAlign.center,
                                      style: material.TextStyle(
                                        fontSize: 16,
                                        fontWeight: material.FontWeight.w600,
                                        color: (doc.data()?['isPremium'] ==
                                                true)
                                            ? material.Colors.green.shade600
                                            : material.Theme.of(
                                                context,
                                              ).textTheme.titleMedium?.color,
                                      ),
                                    )
                                  : null,
                            ),
                            const material.SizedBox(height: 10),

                            material.SizedBox(
                              // Define the total area for the Stack
                              // Make this size slightly larger than the button to show the animation edges
                              width: 300.0,
                              height: 300.0,
                              child: material.Stack(
                                // Use Stack for layering
                                alignment: material.Alignment.center,
                                children: [
                                  // --- Layer 1: Rive Animation (Background) ---
                                  // Positioned.fill ensures it tries to fill the parent SizedBox
                                  material.SizedBox(
                                    width: 300,
                                    height: 300,
                                    child: RiveAnimation.asset(
                                      'assets/animations/button_underline_effect.riv', // <<< PATH TO RIVE
                                      // stateMachines: const ['State Machine 1'],
                                      // animations: const ['button_underline_effect'],
                                      animations: const ['button_peek_effect'],
                                      fit: material.BoxFit.contain,
                                      onInit: (artboard) {},
                                      placeHolder: const material
                                          .SizedBox.shrink(), // Empty placeholder
                                    ),
                                  ),

                                  // Start Peeking Button (logic uses calculated state)
                                  material.SizedBox(
                                    // 1. Existing Circular Button (Keep As Is)
                                    width: 140.0,
                                    height: 140.0,
                                    child: material.ElevatedButton(
                                      onPressed: isButtonEnabled
                                          ? _attemptStartPeeking
                                          : null, // Uses existing logic
                                      style: material.ElevatedButton.styleFrom(
                                        alignment: material.Alignment.center,
                                        shape: const material.CircleBorder(),
                                        padding: material.EdgeInsets.zero,
                                        backgroundColor: isButtonEnabled
                                            ? peekSecondaryColor
                                                .withOpacity(0.1)
                                            : peekSurfaceColor.withOpacity(0.5),
                                        foregroundColor:
                                            isButtonEnabled // Affects default color of child text/icon if not overridden
                                                ? peekOnPrimaryColor
                                                : peekOnSurfaceColor
                                                    .withOpacity(0.6),
                                        elevation: isButtonEnabled ? 4.0 : 0.0,
                                        disabledBackgroundColor:
                                            peekSurfaceColor.withOpacity(0.5),
                                        // No foreground needed if child handles its own color
                                      ),
                                      // --- Child Logic based on isLoading and isCooldownActive ---
                                      child: isLoading
                                          ? const material.SizedBox(
                                              // Consistent Loading indicator
                                              width: 22,
                                              height: 22,
                                              child: material
                                                  .CircularProgressIndicator(
                                                strokeWidth: 3.0,
                                                color:
                                                    peekOnPrimaryColor, // Use theme color
                                              ),
                                            )
                                          : isCooldownActive // <<< CHECK COOLDOWN FLAG
                                              ? material.Text(
                                                  // <<< SHOW COOLDOWN TEXT
                                                  // Extract remaining seconds calculation (ensure cooldownRemaining is available)
                                                  "${(cooldownRemaining.inSeconds >= 0) ? cooldownRemaining.inSeconds + 1 : 1}s",
                                                  style: material.TextStyle(
                                                    fontSize: 34, // Adjust size
                                                    fontWeight: material
                                                        .FontWeight.w600,
                                                    color: peekOnSurfaceColor
                                                        .withOpacity(
                                                            0.8), // Muted cooldown text color
                                                  ),
                                                  textAlign:
                                                      material.TextAlign.center,
                                                )
                                              : material.Padding(
                                                  // Add padding around the image inside the button
                                                  padding: const material
                                                      .EdgeInsets.all(0),
                                                  child: material.Image.asset(
                                                      'assets/images/peek_button_eye.png',
                                                      fit: material.BoxFit
                                                          .contain, // Ensure image fits within padding
                                                      // Optional: Apply color based on enabled state if the image is mono-color
                                                      color: isButtonEnabled
                                                          ? peekOnPrimaryColor // Color for enabled state
                                                          : peekOnSurfaceColor
                                                              .withOpacity(
                                                                  0.5), // Color for disabled state
                                                      errorBuilder: (context,
                                                          error, stackTrace) {
                                                    // Add the missing closing parenthesis to debugPrint
                                                    material.debugPrint(
                                                        "Error loading button icon: $error");

                                                    // 2. Return the fallback widget
                                                    return material.Icon(
                                                      // This is the widget to return
                                                      material
                                                          .Icons.error_outline,
                                                      color: isButtonEnabled
                                                          ? peekOnPrimaryColor
                                                          : peekOnSurfaceColor
                                                              .withOpacity(0.5),
                                                      size:
                                                          120.0, // Adjust size
                                                    );
                                                  }),
                                                ),
                                    ),
                                  ),

                                  // const material.SizedBox(height: 10),
                                ],
                              ),
                            ),

                            const material.SizedBox(height: 10),

                            // *** Use isPremiumForUI for upgrade button visibility ***
                            if (!isPremiumForUI)
                              material.SizedBox(
                                width: double.infinity,
                                child: material.ElevatedButton.icon(
                                  onPressed: isLoading
                                      ? null
                                      : () => context.go('/premium'),
                                  icon: const material.Icon(
                                      material.Icons.star_purple500_outlined),
                                  label:
                                      const material.Text('Upgrade to Premium'),
                                  style: material.ElevatedButton.styleFrom(
                                    padding:
                                        const material.EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    textStyle: const material.TextStyle(
                                      fontSize: 16,
                                      fontWeight: material.FontWeight.bold,
                                    ),
                                    backgroundColor: isLoading
                                        ? material.Colors.grey.shade600
                                        : material.Colors.amber.shade600,
                                    foregroundColor: isLoading
                                        ? material.Colors.grey.shade400
                                        : material.Colors.black87,
                                    shape: material.RoundedRectangleBorder(
                                      borderRadius:
                                          material.BorderRadius.circular(100),
                                    ),
                                  ),
                                ),
                              ),

                            if (!isPremiumForUI)
                              const material.SizedBox(height: 16),

                            // Receiver Mode Button (logic uses calculated state)
                            material.SizedBox(
                              /* ... Keep receiver mode button ... */
                              width: double.infinity,
                              child: material.OutlinedButton.icon(
                                onPressed: isLoading
                                    ? null
                                    : () => context.go('/receive'),
                                icon:
                                    const material.Icon(material.Icons.sensors),
                                label: const material.Text('Receiver Mode'),
                                style: material.OutlinedButton.styleFrom(
                                  padding: const material.EdgeInsets.symmetric(
                                      vertical: 16),
                                  textStyle: const material.TextStyle(
                                    fontSize: 18,
                                    fontWeight: material.FontWeight.bold,
                                  ),
                                  foregroundColor: isLoading
                                      ? material.Colors.grey
                                      : material.Theme.of(context)
                                          .colorScheme
                                          .primary,
                                  side: material.BorderSide(
                                    color: isLoading
                                        ? material.Colors.grey
                                        : material.Theme.of(context)
                                            .colorScheme
                                            .primary,
                                    width: 1.5,
                                  ),
                                  shape: material.RoundedRectangleBorder(
                                    borderRadius:
                                        material.BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const material.SizedBox(height: 20),

                            // TEMPORARY ONBOARD BUTTON
                            material.SizedBox(
                              width: double.infinity,
                              child: material.OutlinedButton.icon(
                                onPressed: isLoading
                                    ? null
                                    : () => context.go('/onboarding'),
                                icon: const material.Icon(
                                    material.Icons.slideshow), // Changed icon
                                label: const material.Text(
                                    'View Tutorial'), // Changed label
                                style: material.OutlinedButton.styleFrom(
                                  padding: const material.EdgeInsets.symmetric(
                                      vertical: 16),
                                  textStyle: const material.TextStyle(
                                    fontSize: 18,
                                    fontWeight: material.FontWeight.bold,
                                  ),
                                  foregroundColor: isLoading
                                      ? material.Colors.grey
                                      : material.Theme.of(context)
                                          .colorScheme
                                          .primary,
                                  side: material.BorderSide(
                                    color: isLoading
                                        ? material.Colors.grey
                                        : material.Theme.of(context)
                                            .colorScheme
                                            .primary,
                                    width: 1.5,
                                  ),
                                  shape: material.RoundedRectangleBorder(
                                    borderRadius:
                                        material.BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            // const material.SizedBox(height: 40),
                          ],
                        ),
                      ),
                    );
                    // *** End FIX ***
                  },
                );
              },
            ),
          ),
        ],
      ),

      bottomNavigationBar: material.BottomNavigationBar(
        /* ... Keep existing BottomNavBar ... */
        items: const <material.BottomNavigationBarItem>[
          material.BottomNavigationBarItem(
            icon: material.Icon(material.Icons.visibility_outlined),
            activeIcon: material.Icon(material.Icons.visibility),
            label: 'Peek',
          ),
          material.BottomNavigationBarItem(
            icon: material.Icon(material.Icons.settings_outlined),
            activeIcon: material.Icon(material.Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: material.Theme.of(context).colorScheme.primary,
        unselectedItemColor: material.Colors.grey.shade600,
        onTap: _onItemTapped,
        backgroundColor: material.Theme.of(context).bottomAppBarTheme.color ??
            material.Theme.of(context).colorScheme.surface,
        type: material.BottomNavigationBarType.fixed,
        showUnselectedLabels: false,
        showSelectedLabels: true,
      ),
    );
  }

  // --- _buildErrorUI (Keep as is) ---
  material.Widget _buildErrorUI(String message) {
    /* ... */
    return material.Padding(
      padding: const material.EdgeInsets.all(30.0),
      child: material.Column(
        mainAxisAlignment: material.MainAxisAlignment.center,
        children: [
          const material.Icon(material.Icons.error_outline,
              color: material.Colors.redAccent, size: 40),
          const material.SizedBox(height: 16),
          material.Text(
            message,
            textAlign: material.TextAlign.center,
            style: const material.TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  // --- MODIFIED: _buildWelcomeArea (Adds Premium Badge) ---
  material.Widget _buildWelcomeArea(
      material.BuildContext context, bool isPremiumForUI) {
    // Accept premium status
    final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? true;
    final userEmail = FirebaseAuth.instance.currentUser?.email;

    const String peekImagePath = 'assets/images/welcome_logo.png';

    // *** UPDATED: Logic for Badge Display ***
    if (isPremiumForUI && !isAnonymous) {
      // Show badge only if premium AND not anonymous
      return material.Row(
        mainAxisAlignment: material.MainAxisAlignment.center,
        crossAxisAlignment: material.CrossAxisAlignment.center,
        children: [
          material.Text(
            // Welcome message
            'Welcome Back!',
            textAlign: material.TextAlign.center,
            style: material.Theme.of(
              context,
            )
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: material.FontWeight.w600),
          ),
          const material.SizedBox(width: 8),
          material.Chip(
            // Premium badge
            avatar: const material.Icon(
              material.Icons.star_rounded,
              size: 16,
              color: material.Colors.black87,
            ),
            label: const material.Text('Premium'),
            labelStyle: const material.TextStyle(
              fontSize: 11,
              fontWeight: material.FontWeight.bold,
              color: material.Colors.black87,
            ),
            backgroundColor: material.Colors.amber.shade600,
            padding:
                const material.EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            visualDensity: material.VisualDensity.compact,
            materialTapTargetSize: material.MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      );
    }

    // --- Fallback: Non-Premium or Anonymous Title/Subtitle Logic ---
    String titleText = isAnonymous ? 'Welcome to Peekio' : 'Welcome Back!';
    String? subtitle = isAnonymous
        ? 'You\'re browsing as a guest.'
        : userEmail; // Show email only if known user and not premium

    return material.Column(
      // Use Column for standard title/subtitle layout
      children: [
        material.Padding(
          padding: const material.EdgeInsets.only(
              bottom: 5), // Add space below the image
          child: material.Image.asset(
            // Use the defined path
            peekImagePath,
            height: 72,
            width: 72,
            fit: material.BoxFit.contain, // Ensure image fits within bounds
            errorBuilder: (context, error, stackTrace) {
              material.debugPrint(
                  "Error loading welcome image: $peekImagePath - $error");
              return const material.SizedBox(
                  height: 60); // Placeholder space on error
            },
          ),
        ),
        material.Text(
          titleText,
          textAlign: material.TextAlign.center,
          style: material.Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(
                fontWeight: material.FontWeight.w600,
                fontSize: 35,
              ),
        ),
        if (subtitle != null)
          material.Padding(
            padding: const material.EdgeInsets.only(top: 10.0),
            child: material.Text(
              subtitle,
              style: material.Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(
                    color: material.Colors.grey.shade600,
                    fontSize: 16,
                  ),
            ),
          ),
      ],
    );
    // --- End UPDATED Logic ---
  }

  // --- END OF MODIFIED _buildWelcomeArea ---
} // End of _HomePageState
