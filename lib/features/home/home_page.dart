// lib/features/home/home_page.dart
import 'dart:async'; // For Timer
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peek/shared/upgrade_prompt_dialog.dart';
import 'package:peek/core/feature_flags.dart';
import 'package:peek/features/peek/controllers/peek_controller.dart';
import 'package:flutter/foundation.dart' show kDebugMode; // For debug button

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
        await showDialog(
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
        await showDialog<bool>(
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
        debugPrint(
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
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent[700],
        behavior: SnackBarBehavior.floating,
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
  Widget build(BuildContext context) {
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
            subtitle = '👑 Unlimited peeks available!';
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

    return Scaffold(
      appBar: AppBar(
        /* ... Keep existing AppBar ... */
        title: const Text('PEEK'),
        elevation: 1.0,
        actions: const [SizedBox(width: 48)],
      ),
      drawer: const DrawerMenu(), // Keep drawer
      body: Center(
        // Use premiumStatus.when for top-level loading/error of premium flag
        child: premiumStatus.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => _buildErrorUI('Error loading status.'),
          data: (isPremiumForUI) {
            // isPremiumForUI used ONLY for UI elements
            // Use userAsyncValue.when for main content based on user data snapshot
            return userAsyncValue.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => _buildErrorUI('Error loading user data.'),
              data: (doc) {
                if (!doc.exists) {
                  return _buildErrorUI("Waiting for user data...");
                }
                // *** FIX: Wrap Column in SingleChildScrollView ***
                return SingleChildScrollView(
                  // <--- ADDED THIS
                  child: Padding(
                    // Keep existing padding
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 30.0, // Increased vertical padding slightly
                    ),
                    child: Column(
                      // The Column that was overflowing
                      mainAxisAlignment: MainAxisAlignment.center,
                      // *** FIX: Added mainAxisSize ***
                      mainAxisSize: MainAxisSize.min, // <--- ADDED THIS
                      children: [
                        if (kDebugMode) // Debug Button
                          Padding(
                            /* ... Keep debug button ... */
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.refresh,
                                size: 18,
                                color: Colors.orangeAccent,
                              ),
                              label: const Text(
                                "DEBUG: Reset Limits",
                                style: TextStyle(color: Colors.orangeAccent),
                              ),
                              onPressed: isLoading ? null : _debugResetLimits,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: isLoading
                                      ? Colors.grey
                                      : Colors.orangeAccent,
                                ),
                                padding: const EdgeInsets.symmetric(
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

                        const SizedBox(height: 20),
                        // Subtitle Area (logic uses data from snapshot)
                        Container(
                          /* ... Keep subtitle container ... */
                          height: 24,
                          alignment: Alignment.center,
                          child: subtitle != null
                              ? Text(
                                  subtitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: (doc.data()?['isPremium'] == true)
                                        ? Colors.green.shade600
                                        : Theme.of(
                                            context,
                                          ).textTheme.titleMedium?.color,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 40),

                        // Start Peeking Button (logic uses calculated state)
                        SizedBox(
                          /* ... Keep start peeking button ... */
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                isButtonEnabled ? _attemptStartPeeking : null,
                            icon: isLoading
                                ? Container(
                                    width: 20,
                                    height: 20,
                                    margin: const EdgeInsets.only(right: 8),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: isButtonEnabled
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimary
                                          : Colors.grey.shade400,
                                    ),
                                  )
                                : const Icon(Icons.visibility_outlined),
                            label: Text(startButtonText),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              backgroundColor: isButtonEnabled
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade600,
                              foregroundColor: isButtonEnabled
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Colors.grey.shade400,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Receiver Mode Button (logic uses calculated state)
                        SizedBox(
                          /* ... Keep receiver mode button ... */
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                isLoading ? null : () => context.go('/receive'),
                            icon: const Icon(Icons.sensors),
                            label: const Text('Receiver Mode'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              foregroundColor: isLoading
                                  ? Colors.grey
                                  : Theme.of(context).colorScheme.primary,
                              side: BorderSide(
                                color: isLoading
                                    ? Colors.grey
                                    : Theme.of(context).colorScheme.primary,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // TEMPORARY ONBOARD BUTTON
                        SizedBox(
                          /* ... Keep receiver mode button ... */
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isLoading
                                ? null
                                : () => context.go('/onboarding'),
                            icon: const Icon(Icons.sensors),
                            label: const Text('Onboarding UI'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              foregroundColor: isLoading
                                  ? Colors.grey
                                  : Theme.of(context).colorScheme.primary,
                              side: BorderSide(
                                color: isLoading
                                    ? Colors.grey
                                    : Theme.of(context).colorScheme.primary,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // *** Use isPremiumForUI for upgrade button visibility ***
                        if (!isPremiumForUI) // <--- USE isPremiumForUI
                          SizedBox(
                            /* ... Keep upgrade button ... */
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: isLoading
                                  ? null
                                  : () => context.go('/premium'),
                              icon: const Icon(
                                Icons.star_purple500_outlined,
                                color: Colors.black87,
                              ),
                              label: const Text('Upgrade to Premium'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                backgroundColor: isLoading
                                    ? Colors.grey.shade600
                                    : Colors.amber.shade600,
                                foregroundColor: isLoading
                                    ? Colors.grey.shade400
                                    : Colors.black87,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                        // *** FIX: Removed Spacer ***
                        // Rely on padding/SizedBox instead
                        const SizedBox(height: 20), // Add space at bottom
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

      bottomNavigationBar: BottomNavigationBar(
        /* ... Keep existing BottomNavBar ... */
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.visibility_outlined),
            activeIcon: Icon(Icons.visibility),
            label: 'Peek',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey.shade600,
        onTap: _onItemTapped,
        backgroundColor: Theme.of(context).bottomAppBarTheme.color ??
            Theme.of(context).colorScheme.surface,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: false,
        showSelectedLabels: true,
      ),
    );
  }

  // --- _buildErrorUI (Keep as is) ---
  Widget _buildErrorUI(String message) {
    /* ... */
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  // --- MODIFIED: _buildWelcomeArea (Adds Premium Badge) ---
  Widget _buildWelcomeArea(BuildContext context, bool isPremiumForUI) {
    // Accept premium status
    final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? true;
    final userEmail = FirebaseAuth.instance.currentUser?.email;

    // *** UPDATED: Logic for Badge Display ***
    if (isPremiumForUI && !isAnonymous) {
      // Show badge only if premium AND not anonymous
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            // Welcome message
            'Welcome Back!',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Chip(
            // Premium badge
            avatar: const Icon(
              Icons.star_rounded,
              size: 16,
              color: Colors.black87,
            ),
            label: const Text('Premium'),
            labelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            backgroundColor: Colors.amber.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      );
    }

    // --- Fallback: Non-Premium or Anonymous Title/Subtitle Logic ---
    String titleText = isAnonymous ? 'Welcome to Peek 👀' : 'Welcome Back!';
    String? subtitle = isAnonymous
        ? 'You\'re browsing as a guest.'
        : userEmail; // Show email only if known user and not premium

    return Column(
      // Use Column for standard title/subtitle layout
      children: [
        Text(
          titleText,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ),
      ],
    );
    // --- End UPDATED Logic ---
  }

  // --- END OF MODIFIED _buildWelcomeArea ---
} // End of _HomePageState
