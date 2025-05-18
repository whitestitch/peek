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
import 'package:flutter_svg/flutter_svg.dart';

import 'package:peek/features/premium/providers/premium_controller.dart';

// --- userDataProvider (Keep as is) ---
final userDataProvider =
    StreamProvider.autoDispose<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    material.debugPrint(
        "[userDataProvider] No authenticated user. Returning stream with null.");
    return Stream.value(null);
  }
  material
      .debugPrint("[userDataProvider] Listening to user document: users/$uid");
  return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
});

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Timer? _rebuildTimerForCooldown;

  @override
  void initState() {
    super.initState();
    material.WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkPromoModal();
      } // Closing brace for if(mounted)
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
      material.debugPrint("Error checking/showing promo modal: $e");
    }
  }

  // --- _attemptStartPeeking (Keep as is) ---
  Future<void> _attemptStartPeeking() async {
    // ... (Keep existing code) ...
    final userAsyncValue = ref.read(userDataProvider);
    final userDocSnapshot = userAsyncValue.asData?.value;

    if (!mounted) return;

    if (userDocSnapshot == null || !userDocSnapshot.exists) {
      _showErrorSnackbar('User data not available yet. Please wait a moment.');
      return;
    }
    final userData = userDocSnapshot.data()!;
    final isPremium = userData['isPremium'] == true;
    const dailyLimit = 3;
    const cooldownDuration = Duration(seconds: 5);
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
      // The 'receiverUid' parameter is removed from the call,
      // Placeholder
      final requestId = await controller.createPeekRequestAndUpdateStats(
        needsDailyReset: needsDailyReset,
      );

      if (!mounted) return;

      // Check result AFTER await completes
      if (requestId != null) {
        material.debugPrint(
            '[HomePage] Peek request $requestId created. Navigating to /wait');
        context.go('/wait?requestId=$requestId');
      } else {
        _showErrorSnackbar('Could not start Peek. Please try again later.');
      }
    } catch (e) {
      if (mounted) {
        material.debugPrint('🔥 Error calling peek controller: $e');
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
    material.debugPrint("DEBUG: Resetting limits...");
    _rebuildTimerForCooldown?.cancel();
    _rebuildTimerForCooldown = null;
    await ref.read(peekControllerProvider.notifier).debugResetUserLimits();
    if (mounted) {
      _showErrorSnackbar(
          "DEBUG: Limits Reset! UI will update on next data refresh.");
      // Forcing a refresh of userDataProvider can make the UI update faster
      // if the stream update from Firestore has a slight delay.
      ref.refresh(userDataProvider);
    }
  }

  @override
  material.Widget build(material.BuildContext context) {
    final AsyncValue<bool> premiumStatus = ref.watch(premiumStatusProvider);
    final userAsyncValue = ref.watch(userDataProvider);
    final peekControllerState = ref.watch(peekControllerProvider);
    final bool isLoading = peekControllerState.isLoading;

    String startButtonText = 'Start Peeking';
    bool isButtonEnabled = false;
    String? subtitleTextInBuild;
    bool isCooldownActive = false;
    Duration cooldownRemaining = Duration.zero;

    _rebuildTimerForCooldown?.cancel();
    _rebuildTimerForCooldown = null;

    userAsyncValue.when(
      loading: () {
        startButtonText = 'Loading User...';
        isButtonEnabled = false;
        subtitleTextInBuild = 'Connecting...';
      },
      error: (error, stackTrace) {
        startButtonText = 'Error';
        isButtonEnabled = false;
        subtitleTextInBuild = 'Could not load user data.';
        print("Error in userDataProvider build: $error");
      },
      data: (userDoc) {
        if (userDoc == null || !userDoc.exists) {
          // Handle null snapshot from Stream.value(null)
          startButtonText = 'Initializing...';
          isButtonEnabled = false;
          subtitleTextInBuild = 'Waiting for user data...';
        } else {
          final userData = userDoc.data()!;

          final bool isPremiumFromSnapshot =
              userData['isPremium'] as bool? ?? false;

          if (isPremiumFromSnapshot) {
            // Corrected to use isPremiumFromSnapshot
            isButtonEnabled = true;
            startButtonText = 'Start Peeking';
            subtitleTextInBuild = 'Unlimited peeks available!';
            isCooldownActive = false;
          } else {
            // Non-premium user logic
            final lastPeekTimestamp =
                userData['lastPeekRequestTimestamp'] as Timestamp?;
            const cooldownDuration = Duration(seconds: 5);

            isCooldownActive = false; // Reset before check
            if (lastPeekTimestamp != null) {
              final expectedCooldownEndTime =
                  lastPeekTimestamp.toDate().add(cooldownDuration);
              if (expectedCooldownEndTime.isAfter(DateTime.now())) {
                isCooldownActive = true;
                cooldownRemaining =
                    expectedCooldownEndTime.difference(DateTime.now());
                if (mounted) {
                  _rebuildTimerForCooldown =
                      Timer(const Duration(seconds: 1), () {
                    if (mounted) setState(() {});
                  });
                }
              }
            }

            int dailyPeekCount = userData['dailyPeekCount'] as int? ?? 0;
            final peekCountLastResetTimestamp =
                userData['peekCountLastReset'] as Timestamp?;
            final now = DateTime.now();
            final startOfToday = DateTime(now.year, now.month, now.day);
            const dailyLimit = 3;
            bool needsReset = peekCountLastResetTimestamp == null ||
                peekCountLastResetTimestamp.toDate().isBefore(startOfToday);

            if (needsReset) {
              dailyPeekCount = 0;
            }

            // Order of checks: Cooldown > Daily Limit > Peeks Available
            if (isCooldownActive) {
              isButtonEnabled = false; // Disabled during cooldown
              final seconds = (cooldownRemaining.inSeconds >= 0)
                  ? cooldownRemaining.inSeconds + 1
                  : 1;
              startButtonText = '${seconds}s';
              subtitleTextInBuild = 'Please wait for cooldown.';
            } else if (dailyPeekCount >= dailyLimit) {
              isButtonEnabled = false; // Disabled if limit reached
              subtitleTextInBuild = '🚫 Daily peek limit reached!';
              startButtonText = 'Limit Reached';
            } else {
              isButtonEnabled = true; // Enabled if peeks available
              startButtonText = 'Start Peeking';
              final rem = dailyLimit - dailyPeekCount;
              subtitleTextInBuild =
                  'You have ${rem > 0 ? rem : 0} peek${rem == 1 ? '' : 's'} left today.';
            }
          }
        }
      },
    ); // End switch

    if (isLoading) {
      isButtonEnabled = false;
    }

    const String homeBackgroundPath = 'assets/images/onboarding_bg_02.jpg';

    return material.Stack(
      fit: material.StackFit.expand,
      children: [
        material.Image.asset(
          homeBackgroundPath,
          fit: material.BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            material.debugPrint("Error loading home background: $error");
            return material.Container(color: peekBackgroundColor);
          },
        ),
        material.Center(
          child: premiumStatus.when(
            loading: () => const material.CircularProgressIndicator(
                color: peekPrimaryColor),
            error: (e, _) => _buildErrorUI('Error loading premium status.'),
            data: (isPremiumForUI) {
              // isPremiumForUI is from premiumStatusProvider (for UI hints like badge)
              return userAsyncValue.when(
                loading: () => const material.CircularProgressIndicator(
                    color: peekPrimaryColor),
                error: (e, _) => _buildErrorUI('Error loading user data.'),
                data: (doc) {
                  if (doc == null || !doc.exists) {
                    return _buildErrorUI("Waiting for user data...");
                  }

                  return material.SingleChildScrollView(
                    child: material.Padding(
                      padding: const material.EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 80.0,
                      ),
                      child: material.Column(
                        mainAxisAlignment: material.MainAxisAlignment.center,
                        mainAxisSize: material.MainAxisSize.min,
                        children: [
                          if (kDebugMode)
                            material.Padding(
                              padding:
                                  const material.EdgeInsets.only(bottom: 20.0),
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
                                onPressed: isLoading ? null : _debugResetLimits,
                                style: material.OutlinedButton.styleFrom(
                                  side: material.BorderSide(
                                    color: isLoading
                                        ? material.Colors.grey
                                        : material.Colors.orangeAccent,
                                  ),
                                  padding: const material.EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                ),
                              ),
                            ),
                          _buildWelcomeArea(context, isPremiumForUI),
                          const material.SizedBox(height: 20),
                          material.Container(
                            height: 20,
                            alignment: material.Alignment.center,
                            child: subtitleTextInBuild != null
                                ? material.Text(
                                    subtitleTextInBuild ?? '',
                                    textAlign: material.TextAlign.center,
                                    style: material.TextStyle(
                                      fontSize: 16,
                                      fontWeight: material.FontWeight.w600,
                                      color: (doc.data()?['isPremium'] == true)
                                          ? material.Colors.green.shade600
                                          : material.Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.color
                                              ?.withOpacity(0.9),
                                    ),
                                  )
                                : const material.SizedBox.shrink(),
                          ),
                          const material.SizedBox(height: 10),
                          material.SizedBox(
                            width: 450,
                            height: 350,
                            child: material.Stack(
                              alignment: material.Alignment.center,
                              children: [
                                material.SizedBox(
                                  width: 450,
                                  height: 450,
                                  child: RiveAnimation.asset(
                                    'assets/animations/button_underline_effect.riv',
                                    animations: const ['button_peek_effect'],
                                    fit: material.BoxFit.contain,
                                    onInit: (artboard) {},
                                    placeHolder:
                                        const material.SizedBox.shrink(),
                                  ),
                                ),
                                material.SizedBox(
                                  width: 230,
                                  height: 230,
                                  child: material.ElevatedButton(
                                    onPressed: isButtonEnabled
                                        ? _attemptStartPeeking
                                        : null,
                                    style: material.ElevatedButton.styleFrom(
                                      alignment: material.Alignment.center,
                                      shape: const material.CircleBorder(),
                                      padding: material.EdgeInsets.zero,
                                      backgroundColor: isButtonEnabled
                                          ? peekSecondaryColor.withOpacity(0.1)
                                          : peekSurfaceColor.withOpacity(0.5),
                                      foregroundColor: isButtonEnabled
                                          ? peekOnPrimaryColor
                                          : peekOnSurfaceColor.withOpacity(0.6),
                                      elevation: isButtonEnabled ? 4.0 : 0.0,
                                      disabledBackgroundColor:
                                          peekSurfaceColor.withOpacity(0.5),
                                    ),
                                    child: isLoading
                                        ? const material.SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: material
                                                .CircularProgressIndicator(
                                              strokeWidth: 3.0,
                                              color: peekOnPrimaryColor,
                                            ),
                                          )
                                        : isCooldownActive ||
                                                (!isButtonEnabled &&
                                                    subtitleTextInBuild ==
                                                        '🚫 Daily peek limit reached!')
                                            ? material.Text(
                                                startButtonText,
                                                style: material.TextStyle(
                                                  fontSize: (startButtonText ==
                                                          'Limit Reached')
                                                      ? 22
                                                      : 34,
                                                  fontWeight:
                                                      material.FontWeight.w600,
                                                  color: peekOnSurfaceColor
                                                      .withOpacity(0.8),
                                                ),
                                                textAlign:
                                                    material.TextAlign.center,
                                              )
                                            : material.Padding(
                                                padding: const material
                                                    .EdgeInsets.all(15),
                                                child: SvgPicture.asset(
                                                  'assets/images/peekio_logo.svg',
                                                  fit: material.BoxFit.contain,
                                                  colorFilter:
                                                      material.ColorFilter.mode(
                                                          isButtonEnabled
                                                              ? peekWhiteColor
                                                              : peekOnSurfaceColor
                                                                  .withOpacity(
                                                                      0.4),
                                                          material
                                                              .BlendMode.srcIn),
                                                  placeholderBuilder:
                                                      (context) =>
                                                          material.Icon(
                                                    material.Icons
                                                        .visibility_outlined,
                                                    color: isButtonEnabled
                                                        ? peekWhiteColor
                                                        : peekOnSurfaceColor
                                                            .withOpacity(0.5),
                                                    size: 100.0,
                                                  ),
                                                ),
                                              ),
                                  ),
                                ),
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
                                  padding: const material.EdgeInsets.symmetric(
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
                              icon: const material.Icon(material.Icons.sensors),
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

                          if (kDebugMode) // Debug Button
                            material.Padding(
                              /* ... Keep debug button ... */
                              padding:
                                  const material.EdgeInsets.only(bottom: 20.0),
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
                                onPressed: isLoading ? null : _debugResetLimits,
                                style: material.OutlinedButton.styleFrom(
                                  side: material.BorderSide(
                                    color: isLoading
                                        ? material.Colors.grey
                                        : material.Colors.orangeAccent,
                                  ),
                                  padding: const material.EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                ),
                              ),
                            ),

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
    );
  }
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

material.Widget _buildWelcomeArea(
    material.BuildContext context, bool isPremiumForUI) {
  // Accept premium status
  final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? true;
  final userEmail = FirebaseAuth.instance.currentUser?.email;

  // const String peekImagePath = 'assets/images/welcome_logo.png';

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
  String titleText = isPremiumForUI ? 'Welcome Back' : 'Welcome to Peekio!';
  String? subtitleText = isPremiumForUI
      ? 'You\'re browsing as a premium'
      : 'You\'re browsing as a guest.';

  return material.Column(
    // Use Column for standard title/subtitle layout
    children: [
      material.Text(
        titleText,
        textAlign: material.TextAlign.center,
        style: material.Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(
            fontWeight: material.FontWeight.w600,
            fontSize: 32,
            color: peekWhiteColor),
      ),
      if (subtitleText != null)
        material.Padding(
          padding: const material.EdgeInsets.only(top: 10.0),
          child: material.Text(
            subtitleText,
            style: material.Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(
                  fontWeight: material.FontWeight.w500,
                  color: peekOnBackgroundColor.withOpacity(0.85),
                  fontSize: 18,
                ),
          ),
        ),
    ],
  );
}
