// lib/features/home/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart' as material;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peek/shared/upgrade_prompt_dialog.dart';
import 'package:peek/core/feature_flags.dart';
import 'package:peek/features/peek/controllers/peek_controller.dart';
import 'package:peek/features/home/providers/home_state_provider.dart';
import 'package:peek/core/firestore_service.dart';
import 'package:peek/theme/colors.dart';
import 'package:peek/core/widgets/peek_loading_indicator.dart';
import 'package:rive/rive.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Timer? _cooldownTimer;
  Timer? _restrictionTimer;
  bool _restrictionTimerActive = false; // 🔧 NEW: Prevent multiple timers
  int? _secondsRemaining;

  // Track which cancellation panels have already been shown to prevent duplicates
  final Set<String> _shownCancellationPanels = <String>{};

  @override
  void initState() {
    super.initState();
    material.WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkPromoModal();
        // _checkIfPeekWasCancelled();
        // 🔧 NEW: Fix existing restricted users on app start
        _fixExistingRestrictedUsers();
      }
    });
  }

  /// 🔧 NEW: Fix existing restricted users by adding missing restrictionEndTime
  Future<void> _fixExistingRestrictedUsers() async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.fixExistingRestrictedUsers();
      // Refresh the home state after migration
      ref.invalidate(homeStateProvider);
    } catch (e) {
      debugPrint("[HomePage] ❌ Error fixing restricted users: $e");
    }
  }

  void _showPeekCancelledSheet(String reason) {
    // Check if we've already shown a cancellation panel recently
    if (_shownCancellationPanels.contains(reason)) {
      print("⚠️ Cancellation panel already shown for reason: $reason");
      return;
    }

    // Mark this cancellation as shown
    _shownCancellationPanels.add(reason);

    // Clean up old entries after 5 seconds to prevent memory leaks
    Future.delayed(const Duration(seconds: 5), () {
      _shownCancellationPanels.remove(reason);
    });

    final scaffoldContext = material.Scaffold.of(context).context;
    if (scaffoldContext == null) {
      print("❌ Cannot show cancelled sheet: root context is null.");
      return;
    }

    // Check if we're in the middle of a navigation transition
    if (!mounted) {
      print("❌ Cannot show cancelled sheet: page not mounted.");
      return;
    }

    // Determine title and message based on reason
    String title;
    String message;

    if (reason == 'receiver_cancelled') {
      title = "Peekio Cancelled!";
      message = "The receiver cancelled the Peekio request.";
    } else if (reason == 'sender_cancelled') {
      title = "Peekio Stopped";
      message = "The sender stopped the Peekio request.";
    } else {
      title = "Peekio Cancelled";
      message = "The Peekio request was cancelled.";
    }

    // Add a small delay to ensure navigation is complete
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      material.showModalBottomSheet(
        context: scaffoldContext,
        backgroundColor: material.Colors.transparent,
        isScrollControlled: true,
        isDismissible: true,
        builder: (ctx) {
          return material.StatefulBuilder(
            builder: (context, setState) {
              // Track if the sheet has been dismissed
              bool isSheetDismissed = false;

              // Auto-close after 5 seconds
              Timer? autoCloseTimer;
              autoCloseTimer = Timer(const Duration(seconds: 5), () {
                if (ctx.mounted && !isSheetDismissed) {
                  try {
                    // Check if the context is still valid before trying to pop
                    if (material.Navigator.of(ctx).canPop()) {
                      material.Navigator.of(ctx).pop();
                    } else {
                      // If we can't pop, just cancel the timer
                      autoCloseTimer?.cancel();
                    }
                  } catch (e) {
                    // If there's an error, just log it and don't crash
                    print("❌ Error auto-closing cancelled sheet: $e");
                    // Cancel the timer to prevent further attempts
                    autoCloseTimer?.cancel();
                  }
                }
              });

              return material.Stack(
                alignment: material.Alignment.topCenter,
                children: [
                  // The main content container with rounded corners
                  material.Container(
                    height: material.MediaQuery.of(context).size.height * 0.4,
                    width: double.infinity,
                    decoration: const material.BoxDecoration(
                      color: peekBackgroundColor,
                      borderRadius: material.BorderRadius.vertical(
                        top: material.Radius.circular(24),
                      ),
                    ),
                    padding: const material.EdgeInsets.all(24.0),
                    child: material.Column(
                      mainAxisAlignment: material.MainAxisAlignment.center,
                      children: [
                        const material.Icon(
                          material.Icons.cancel_outlined,
                          size: 60,
                          color: material.Colors.white70,
                        ),
                        const material.SizedBox(height: 20),
                        material.Text(
                          title,
                          style: const material.TextStyle(
                              fontSize: 24,
                              fontWeight: material.FontWeight.bold,
                              color: material.Colors.white),
                        ),
                        const material.SizedBox(height: 8),
                        material.Text(
                          message,
                          textAlign: material.TextAlign.center,
                          style: const material.TextStyle(
                              fontSize: 16, color: material.Colors.white70),
                        ),
                        const material.SizedBox(height: 32),
                        material.SizedBox(
                          width: double.infinity,
                          child: material.ElevatedButton(
                            style: material.ElevatedButton.styleFrom(
                              backgroundColor: peekSecondaryColor,
                              foregroundColor: peekSurfaceColor,
                            ),
                            onPressed: () {
                              // Cancel the auto-close timer
                              autoCloseTimer?.cancel();
                              setState(() {
                                isSheetDismissed = true;
                              });

                              // Use the sheet context to dismiss itself properly
                              if (ctx.mounted) {
                                material.Navigator.of(ctx).pop();
                              }
                            },
                            child: const material.Text('OK'),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    });
  }

  Future<void> _checkPromoModal() async {
    if (!FeatureFlags.showIntroScreens || !mounted) return;
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final currentLocation =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    if (currentLocation == '/terms' || currentLocation == '/onboarding') {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final bool onboardingComplete =
        prefs.getBool('onboardingComplete') ?? false;
    if (!onboardingComplete) {
      return;
    }

    final lastShown = prefs.getInt('upgradePromoLastShown') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const sevenDaysInMillis = 7 * 24 * 60 * 60 * 1000;

    final bool isPremium =
        ref.read(homeStateProvider).asData?.value.isPremium ?? false;

    if ((now - lastShown > sevenDaysInMillis) && mounted && !isPremium) {
      await material.showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const UpgradePromptDialog(reason: UpgradeReason.periodic),
      );
      if (mounted) await prefs.setInt('upgradePromoLastShown', now);
    }
  }

  Future<void> _attemptStartPeeking() async {
    ref.read(homeStateProvider.notifier).attemptStartPeeking(context);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _restrictionTimer?.cancel();
    _restrictionTimerActive = false; // 🔧 NEW: Reset timer flag
    super.dispose();
  }

  void _manageCooldownTimer(DateTime? cooldownEndTime) {
    // If a cooldown is active and no timer is running, start one.
    if (cooldownEndTime != null && cooldownEndTime.isAfter(DateTime.now())) {
      if (_cooldownTimer?.isActive ?? false) return; // Timer already running

      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final now = DateTime.now();
        if (now.isAfter(cooldownEndTime)) {
          timer.cancel();
          if (mounted) {
            setState(() => _secondsRemaining = null);
            ref.invalidate(homeStateProvider); // Refresh the state
          }
        } else {
          if (mounted) {
            setState(() {
              _secondsRemaining = cooldownEndTime.difference(now).inSeconds;
            });
          }
        }
      });
    } else {
      // If no cooldown is active, ensure any lingering timer is cancelled.
      if (_cooldownTimer != null) {
        _cooldownTimer?.cancel();
        _cooldownTimer = null;
        if (_secondsRemaining != null) {
          if (mounted) setState(() => _secondsRemaining = null);
        }
      }
    }
  }

  /// 🔧 NEW: Get restriction countdown text
  String _getRestrictionCountdown() {
    final homeState = ref.read(homeStateProvider).value;

    if (homeState?.restrictionEndTime == null) {
      return '24:00:00';
    }

    final now = DateTime.now();
    final endTime = homeState!.restrictionEndTime!;

    if (now.isAfter(endTime)) {
      return 'LIFTED';
    }

    final difference = endTime.difference(now);
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    String result;
    if (days > 0) {
      result = '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      result = '${hours}h ${minutes}m';
    } else {
      result = '${minutes}m';
    }

    return result;
  }

  /// 🔧 NEW: Manage restriction countdown timer
  void _manageRestrictionTimer(DateTime? restrictionEndTime) {
    // 🔧 FIX: Prevent multiple timers from being created
    if (_restrictionTimerActive && _restrictionTimer != null) {
      return;
    }

    // 🔧 FIX: Always cancel existing timer first
    _restrictionTimer?.cancel();
    _restrictionTimer = null;
    _restrictionTimerActive = false;

    if (restrictionEndTime == null) {
      return;
    }

    _restrictionTimerActive = true;

    // 🔧 FIX: Update every 30 seconds for smoother countdown
    _restrictionTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        _restrictionTimerActive = false;
        return;
      }

      final now = DateTime.now();
      if (now.isAfter(restrictionEndTime)) {
        timer.cancel();
        _restrictionTimer = null;
        _restrictionTimerActive = false;
        setState(() {});
        ref.invalidate(homeStateProvider); // Refresh the state
      } else {
        setState(() {}); // Update countdown display every 30 seconds
      }
    });

    // 🔧 NEW: Update immediately for better UX
    if (mounted) {
      setState(() {});
    }
  }

  @override
  material.Widget build(material.BuildContext context) {
    final goRouterState = GoRouterState.of(context);

    // Handle cancellation events from centralized handler
    if (goRouterState.uri.queryParameters['show'] == 'peekCancelled') {
      final reason = goRouterState.uri.queryParameters['reason'];

      material.WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Clear the URL parameters and show the cancellation panel
          context.go('/');
          _showPeekCancelledSheet(reason ?? 'cancelled');
        }
      });
    }

    final homeStateAsync = ref.watch(homeStateProvider);

    return material.Center(
      child: homeStateAsync.when(
        loading: () => const PeekLoadingIndicator.medium(),
        error: (e, _) => _buildErrorUI('Error loading user data.'),
        data: (state) {
          _manageCooldownTimer(state.cooldownEndTime);
          _manageRestrictionTimer(state.restrictionEndTime);

          // Bridge state to local variables for UI clarity
          final isLoading = ref.watch(peekControllerProvider).isLoading;
          final isButtonEnabled = state.isButtonEnabled && !isLoading;
          final startButtonText = state.buttonText;
          final subtitleTextInBuild = state.subtitleText;
          final isPremiumForUI = state.isPremium;
          final isRestricted = state.isRestricted;

          final bool isCooldownActive = state.cooldownEndTime != null;

          return material.SingleChildScrollView(
            child: material.Padding(
              padding: const material.EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 40.0,
              ),
              child: material.Column(
                mainAxisAlignment: material.MainAxisAlignment.center,
                mainAxisSize: material.MainAxisSize.min,
                children: [
                  // 🔧 Add top margin to center content better on screen
                  const material.SizedBox(height: 20),
                  _buildWelcomeArea(context, isPremiumForUI),

                  // Add peek counter text under the main title
                  const material.SizedBox(height: 15),
                  material.Container(
                    alignment: material.Alignment.center,
                    child: material.Text(
                      isRestricted
                          ? 'You are banned for inappropriate content'
                          : subtitleTextInBuild,
                      textAlign: material.TextAlign.center,
                      style: material.TextStyle(
                        fontSize: 17,
                        fontWeight: material.FontWeight.w600,
                        color: isRestricted
                            ? peekErrorColor
                            : isPremiumForUI
                                ? material.Colors.green.shade600
                                : material.Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.color
                                    ?.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  const material.SizedBox(height: 30),
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
                          ),
                        ),
                        material.SizedBox(
                          width: 280,
                          height: 280,
                          child: material.ElevatedButton(
                            onPressed:
                                isButtonEnabled ? _attemptStartPeeking : null,
                            style: material.ElevatedButton.styleFrom(
                              alignment: material.Alignment.center,
                              shape: const material.CircleBorder(),
                              padding: material.EdgeInsets.zero,
                              backgroundColor: isRestricted
                                  ? material.Colors.red.shade100
                                  : isButtonEnabled
                                      ? peekSecondaryColor.withValues(
                                          alpha: 0.1)
                                      : peekSurfaceColor.withValues(alpha: 0.5),
                            ),
                            child: isLoading
                                ? const PeekLoadingIndicator.medium(
                                    logoColor: material.Colors.white)
                                : isRestricted
                                    ? const material.Icon(
                                        material.Icons.block,
                                        color: material.Colors.red,
                                        size: 64,
                                      )
                                    : isCooldownActive &&
                                            _secondsRemaining != null
                                        ? material.Text(
                                            '$_secondsRemaining',
                                            key: const material.ValueKey(
                                                'cooldown_timer'),
                                            style: const material.TextStyle(
                                              fontSize: 34,
                                              fontWeight:
                                                  material.FontWeight.w600,
                                            ),
                                          )
                                        : startButtonText == 'Limit Reached'
                                            ? material.Text(
                                                startButtonText,
                                                style: const material.TextStyle(
                                                  fontSize: 22,
                                                  fontWeight:
                                                      material.FontWeight.w600,
                                                ),
                                              )
                                            : material.Padding(
                                                padding: const material
                                                    .EdgeInsets.all(15),
                                                child: SvgPicture.asset(
                                                  'assets/images/peekio_eye.svg',
                                                  // height: 200,
                                                  // ignore: deprecated_member_use
                                                  // color: peekPrimaryColor,
                                                  // colorFilter:
                                                  //     const material.ColorFilter.mode(
                                                  //   material.Colors.white,
                                                  //   material.BlendMode.srcIn,
                                                  // ),
                                                ),
                                              ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const material.SizedBox(height: 30),

                  // 🔧 NEW: Show restriction info when user is banned

                  if (isRestricted)
                    material.Container(
                      width: double.infinity,
                      padding: const material.EdgeInsets.all(16),
                      margin: const material.EdgeInsets.only(top: 20),
                      decoration: material.BoxDecoration(
                        color: material.Colors.red.shade50,
                        borderRadius: material.BorderRadius.circular(12),
                        border: material.Border.all(
                          color: material.Colors.red.shade200,
                          width: 1,
                        ),
                      ),
                      child: material.Column(
                        children: [
                          material.Row(
                            mainAxisAlignment:
                                material.MainAxisAlignment.center,
                            children: [
                              const material.Icon(
                                material.Icons.warning_amber_rounded,
                                color: material.Colors.red,
                                size: 20,
                              ),
                              const material.SizedBox(width: 8),
                              material.Text(
                                'Account Suspended',
                                style: material.TextStyle(
                                  fontSize: 16,
                                  fontWeight: material.FontWeight.w600,
                                  color: material.Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                          const material.SizedBox(height: 8),
                          material.Text(
                            'Account suspended due to violations',
                            textAlign: material.TextAlign.center,
                            style: material.TextStyle(
                              fontSize: 14,
                              color: material.Colors.red.shade600,
                            ),
                          ),
                          const material.SizedBox(height: 12),
                          // 🔧 NEW: Countdown timer instead of contact support
                          material.Container(
                            padding: const material.EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: material.BoxDecoration(
                              color: material.Colors.red.shade100,
                              borderRadius: material.BorderRadius.circular(20),
                            ),
                            child: material.Text(
                              'Restriction lifts in: ${_getRestrictionCountdown()}',
                              style: material.TextStyle(
                                fontSize: 14,
                                fontWeight: material.FontWeight.w600,
                                color: material.Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const material.SizedBox(height: 30),

                  if (!isPremiumForUI && !isRestricted)
                    material.SizedBox(
                      width: double.infinity,
                      // SPACE

                      child: material.OutlinedButton.icon(
                        style: material.OutlinedButton.styleFrom(
                          padding: const material.EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 18,
                          ),
                        ),
                        onPressed:
                            isLoading ? null : () => context.go('/premium'),
                        icon: const material.Icon(
                          material.Icons.star_purple500_outlined,
                        ),
                        label: const material.Text('Upgrade to Premium'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  material.Widget _buildErrorUI(String message) {
    return material.Padding(
      padding: const material.EdgeInsets.all(30.0),
      child: material.Column(
        mainAxisAlignment: material.MainAxisAlignment.center,
        children: [
          const material.Icon(material.Icons.error_outline,
              color: peekErrorColor, size: 40),
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
      material.BuildContext context, bool isPremium) {
    final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? true;

    String titleText = isPremium ? 'Welcome Back!' : 'Welcome to Peekio!';

    if (isPremium && !isAnonymous) {
      return material.Column(
        mainAxisAlignment: material.MainAxisAlignment.center,
        children: [
          material.Text(
            titleText,
            style: const material.TextStyle(
              fontSize: 36,
              fontWeight: material.FontWeight.w600,
              letterSpacing: 0.5,
              color: peekWhiteColor,
            ),
          ),
          const material.SizedBox(height: 8),
          material.Chip(
            avatar: const material.Icon(material.Icons.star, size: 16),
            label: const material.Text('Premium'),
            backgroundColor: material.Colors.amber.shade600,
          ),
        ],
      );
    }

    // For non-premium users, also use a Column for consistent alignment
    return material.Column(
      mainAxisAlignment: material.MainAxisAlignment.center,
      children: [
        material.Text(
          titleText,
          style: const material.TextStyle(
            fontSize: 33,
            fontWeight: material.FontWeight.bold,
            color: peekWhiteColor,
          ),
        ),
      ],
    );
  }
}
