// lib/core/widgets/app_shell.dart
import 'package:flutter/material.dart' as material; // Using alias
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/core/router.dart';
import 'package:peek/features/peek/providers/peek_providers.dart';
import 'package:peek/features/menu/drawer_menu.dart'; // Your existing drawer
import 'package:peek/main.dart';
import 'package:peek/theme/colors.dart'; // Your theme colors
import 'package:cloud_firestore/cloud_firestore.dart'; // Added for Timestamp

class AppShell extends ConsumerStatefulWidget {
  final GoRouterState routerState; // Current router state
  final material.Widget child; // The child page to display

  const AppShell({
    super.key,
    required this.routerState,
    required this.child,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with material.TickerProviderStateMixin {
  // Helper function to determine the selected index directly from the router state.
  int _calculateSelectedIndex(String uri) {
    final path = uri.split('?').first;
    if (path.startsWith('/stats')) return 1;
    if (path.startsWith('/onboarding')) return 2;
    if (path.startsWith('/settings')) return 3;
    return 0; // Default to home
  }

  // State to track reaction animation display
  String? _currentReactionId;
  String? _currentReactionType;
  bool _showReactionAnimation = false;
  // Dedupe reactions within this app session
  final Set<String> _processedReactionIds = <String>{};
  // Track last seen reaction timestamp to avoid showing old reactions
  DateTime? _lastSeenReactionTime = DateTime.now();

  // Animation controllers for smooth card animations
  late material.AnimationController _cardAnimationController;
  late material.Animation<double> _cardSlideAnimation;
  late material.Animation<double> _cardScaleAnimation;
  late material.Animation<double> _cardFadeAnimation;

  // Track the specific context of the reaction dialog so we only pop that dialog
  material.BuildContext? _reactionDialogContext;

  @override
  void initState() {
    super.initState();
    // Initialize last seen time to now to avoid showing old reactions
    _lastSeenReactionTime = DateTime.now();

    // Initialize card animation controller
    _cardAnimationController = material.AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Setup slide animation (from bottom)
    _cardSlideAnimation = material.Tween<double>(
      begin: 1.0, // Start from bottom
      end: 0.0, // End at center
    ).animate(material.CurvedAnimation(
      parent: _cardAnimationController,
      curve: material.Curves.easeOutBack,
    ));

    // Setup scale animation (subtle pop effect)
    _cardScaleAnimation = material.Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(material.CurvedAnimation(
      parent: _cardAnimationController,
      curve: material.Curves.easeOutBack,
    ));

    // Setup fade animation
    _cardFadeAnimation = material.Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(material.CurvedAnimation(
      parent: _cardAnimationController,
      curve: material.Curves.easeInOut,
    ));
  }

  void _onItemTapped(int index, material.BuildContext context) {
    switch (index) {
      case 0:
        GoRouter.of(context).go('/');
        break;
      case 1:
        GoRouter.of(context).go('/stats');
        break;
      case 2:
        // Use the root router for top-level navigation outside the shell.
        GoRouter.of(rootNavigatorKey.currentContext!).go('/onboarding');
        break;
      case 3:
        GoRouter.of(context).go('/settings');
        break;
      default:
        return;
    }
  }

  // Method to show the reaction dialog
  void _showReactionDialog(String reactionId, String reactionType) {
    if (_currentReactionId != reactionId) {
      material.debugPrint(
          '[AppShell] ▶ Showing reaction dialog for $reactionType ($reactionId)');
      material.debugPrint(
          '[AppShell] 🔧 Setting state: _showReactionAnimation = true');
      setState(() {
        _currentReactionId = reactionId;
        _currentReactionType = reactionType;
        _showReactionAnimation = true;
      });

      // Start the card entrance animation
      _cardAnimationController.forward();

      // Show the reaction dialog using showDialog to avoid z-index conflicts
      material.showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: material.Colors.transparent,
        builder: (dialogContext) {
          _reactionDialogContext = dialogContext;
          return material.AnimatedBuilder(
            animation: _cardAnimationController,
            builder: (context, child) {
              return material.Material(
                color: material.Colors.transparent,
                child: material.Stack(
                  children: [
                    // Background gradient layer that animates with the dialog
                    material.Opacity(
                      opacity: _cardFadeAnimation.value * 0.8,
                      child: material.Container(
                        decoration: material.BoxDecoration(
                          gradient: material.LinearGradient(
                            begin: material.Alignment.topCenter,
                            end: material.Alignment.bottomCenter,
                            colors: [
                              peekBackgroundColor.withValues(alpha: 0.9),
                              peekBackgroundColor.withValues(alpha: 0.7),
                              peekBackgroundColor.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Centered dialog
                    material.Center(
                      child: _buildReactionDialog(),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      // Auto-hide after 2 seconds
      Future.delayed(const Duration(milliseconds: 5000), () {
        if (mounted && _currentReactionId == reactionId) {
          material.debugPrint(
              '[AppShell] ⏹ Hiding reaction dialog for $reactionType ($reactionId)');
          material.debugPrint(
              '[AppShell] 🔧 Setting state: _showReactionAnimation = false');
          _hideReactionDialog();
        } else {
          material.debugPrint(
              '[AppShell] ⚠️ Cannot hide dialog - widget not mounted or reaction changed');
        }
      });
    } else {
      material.debugPrint(
          '[AppShell] ⏭️ Skipping duplicate reaction: $reactionType ($reactionId)');
    }
  }

  void _hideReactionDialog() {
    // Reverse the animation for smooth exit
    _cardAnimationController.reverse().then((_) {
      if (!mounted) return;

      // Close only the reaction dialog if still present
      final ctx = _reactionDialogContext;
      if (ctx != null && material.Navigator.of(ctx).canPop()) {
        material.Navigator.of(ctx).pop();
      }
      _reactionDialogContext = null;

      setState(() {
        _showReactionAnimation = false;
        _currentReactionId = null;
        _currentReactionType = null;
      });
      // Reset controller for next use
      _cardAnimationController.reset();
    });
  }

  // Method to build the new card-style reaction dialog
  material.Widget _buildReactionDialog() {
    material.debugPrint(
        '[AppShell] 🎨 Building card-style reaction dialog: type=$_currentReactionType, show=$_showReactionAnimation');

    return material.AnimatedBuilder(
      animation: _cardAnimationController,
      builder: (context, child) {
        return material.Transform.translate(
          offset: material.Offset(0, _cardSlideAnimation.value * 100),
          child: material.Transform.scale(
            scale: _cardScaleAnimation.value,
            child: material.Opacity(
              opacity: _cardFadeAnimation.value,
              child: material.Center(
                child: material.Container(
                  width: 320,
                  height: 280,
                  margin: const material.EdgeInsets.all(32),
                  decoration: material.BoxDecoration(
                    color: peekBackgroundColor,
                    borderRadius: material.BorderRadius.circular(24),
                  ),
                  padding: const material.EdgeInsets.all(24.0),
                  child: material.Column(
                    mainAxisAlignment: material.MainAxisAlignment.center,
                    children: [
                      // Title (no emoji, just text like existing dialogs)
                      material.Text(
                        _currentReactionType == 'like'
                            ? "A positive reaction!"
                            : "Not their favorite!",
                        style: const material.TextStyle(
                          fontSize: 24,
                          fontWeight: material.FontWeight.bold,
                          color: peekWhiteColor,
                        ),
                        textAlign: material.TextAlign.center,
                      ),

                      const material.SizedBox(height: 8),

                      // Body text (shortened to max 2 lines)
                      material.Text(
                        _currentReactionType == 'like'
                            ? "Someone thinks your peek is absolutely amazing!"
                            : "Sorry, what you're watching isn't quite their style.",
                        style: const material.TextStyle(
                          fontSize: 16,
                          color: material.Colors.white70,
                          height: 1.4,
                        ),
                        textAlign: material.TextAlign.center,
                      ),

                      const material.SizedBox(height: 32),

                      // Full-width button matching existing dialog style
                      material.SizedBox(
                        width: double.infinity,
                        child: material.ElevatedButton(
                          style: material.ElevatedButton.styleFrom(
                            backgroundColor: _currentReactionType == 'like'
                                ? peekPrimaryColor
                                : peekErrorColor,
                          ),
                          onPressed: () {
                            // Auto-dismiss the dialog
                            _hideReactionDialog();
                          },
                          child: const material.Text(
                            'OK',
                            style: material.TextStyle(
                              fontWeight: material.FontWeight.w600,
                              color: peekOnSecondaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    super.dispose();
  }

  @override
  material.Widget build(material.BuildContext context) {
    // Debug: Monitor reaction stream for debugging
    final reactionStream = ref.watch(newReactionStreamProvider);
    material.debugPrint(
        "[AppShell] 🔍 Reaction stream status: ${reactionStream.toString()}");
    if (reactionStream.hasValue && reactionStream.value!.isNotEmpty) {
      material.debugPrint(
          "[AppShell] ✅ Reaction stream active with ${reactionStream.value!.length} reactions");
      for (final doc in reactionStream.value!) {
        final data = doc.data();
        material.debugPrint(
            "[AppShell] 📄 Reaction doc: ${doc.id} - type: ${data['reactionType']}");
      }
    } else if (reactionStream.isLoading) {
      material.debugPrint("[AppShell] ⏳ Reaction stream loading...");
    } else if (reactionStream.hasError) {
      material.debugPrint(
          "[AppShell] ❌ Reaction stream error: ${reactionStream.error}");
    } else {
      material.debugPrint("[AppShell] ℹ️ Reaction stream empty or no data");
    }

    // Declaratively calculate the index and UI visibility from the router state.
    final int selectedIndex =
        _calculateSelectedIndex(widget.routerState.uri.toString());
    final String currentPath =
        widget.routerState.uri.toString().split('?').first;
    final bool showAppBar = !routesInShellWithoutAppBar.contains(currentPath);
    final bool showBottomNav = !routesWithoutBottomNav.contains(currentPath);

    const String homeBackgroundPath = 'assets/images/onboarding_bg_02.jpg';

    return material.Stack(
      fit: material.StackFit.expand,
      children: [
        // Layer 1: Background Image (bottom)
        material.Image.asset(
          homeBackgroundPath,
          fit: material.BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return material.Container(color: peekBackgroundColor);
          },
        ),

        // Layer 2: Main Content (middle)
        material.Scaffold(
          backgroundColor: material.Colors.transparent,
          appBar: showAppBar
              ? material.AppBar(
                  title: const material.Text('Peekio'),
                  elevation: 0.0,
                  leading: currentPath == '/stats'
                      ? material.IconButton(
                          icon: const material.Icon(
                              material.Icons.arrow_back_ios_new),
                          onPressed: () => GoRouter.of(context).go('/'),
                        )
                      : material.Builder(
                          builder: (material.BuildContext context) {
                            return material.IconButton(
                              icon: const material.Icon(
                                  material.Icons.menu_rounded),
                              iconSize: 28,
                              tooltip:
                                  material.MaterialLocalizations.of(context)
                                      .openAppDrawerTooltip,
                              onPressed: () {
                                material.Scaffold.of(context).openDrawer();
                              },
                            );
                          },
                        ),
                )
              : null,
          drawer: const DrawerMenu(),
          body: material.Stack(
            children: [
              widget.child,
              // Reaction watcher - positioned above the main content
              Consumer(
                builder: (context, ref, child) {
                  // Watch for new reactions and show dialog (only once per reaction)
                  final newReactions = ref.watch(newReactionStreamProvider);

                  // Only process if we have new reactions and don't already have one showing
                  if (newReactions.hasValue &&
                      newReactions.value!.isNotEmpty &&
                      !_showReactionAnimation) {
                    final latest = newReactions.value!.last;
                    final data = latest.data();
                    material.debugPrint(
                        '[AppShell] 🔍 Reaction document data: $data');
                    final reactionType =
                        (data['reactionType'] ?? '').toString().toLowerCase();
                    final reactionId = latest.id;

                    // Get reaction timestamp (serverTimestamp or timestamp)
                    final reactionTime = data['timestamp'] as Timestamp?;
                    if (reactionTime == null) {
                      material.debugPrint(
                          '[AppShell] ⚠️ No timestamp found for reaction: $reactionId');
                      return const material.SizedBox.shrink();
                    }

                    material.debugPrint(
                        '[AppShell] 🔍 Reaction timestamp: ${reactionTime.toDate()}, Last seen: $_lastSeenReactionTime');

                    // Skip if this reaction is older than our last seen time
                    if (_lastSeenReactionTime != null &&
                        reactionTime
                            .toDate()
                            .isBefore(_lastSeenReactionTime!)) {
                      material.debugPrint(
                          '[AppShell] ⏭️ Skipping old reaction: $reactionType ($reactionId)');
                      return const material.SizedBox.shrink();
                    }

                    // Skip if already processed in this session
                    if (_processedReactionIds.contains(reactionId)) {
                      material.debugPrint(
                          '[AppShell] ⏭️ Skipping duplicate reaction: $reactionType ($reactionId)');
                      return const material.SizedBox.shrink();
                    }

                    if (reactionType == 'like' || reactionType == 'dislike') {
                      material.debugPrint(
                          '[AppShell] 🎯 Processing new reaction: $reactionType ($reactionId)');
                      material.debugPrint(
                          '[AppShell] 🔧 About to set _showReactionAnimation = true');
                      // Mark as processed and update last seen time
                      _processedReactionIds.add(reactionId);
                      _lastSeenReactionTime = reactionTime.toDate();
                      material.WidgetsBinding.instance
                          .addPostFrameCallback((_) {
                        _showReactionDialog(reactionId, reactionType);
                      });
                    }
                  }

                  // No reaction to show
                  return const material.SizedBox.shrink();
                },
              ),
            ],
          ),
          bottomNavigationBar: showBottomNav
              ? material.BottomNavigationBar(
                  backgroundColor: material.Colors.transparent,
                  elevation: 0,
                  items: const <material.BottomNavigationBarItem>[
                    material.BottomNavigationBarItem(
                      icon: material.Icon(material.Icons.visibility),
                      activeIcon: material.Icon(material.Icons.visibility),
                      label: 'Peekio',
                    ),
                    material.BottomNavigationBarItem(
                      icon: material.Icon(material.Icons.leaderboard),
                      activeIcon: material.Icon(material.Icons.leaderboard),
                      label: 'Stats',
                    ),
                    material.BottomNavigationBarItem(
                      icon: material.Icon(material.Icons.info),
                      activeIcon: material.Icon(material.Icons.info),
                      label: 'onboarding',
                    ),
                    material.BottomNavigationBarItem(
                      icon: material.Icon(material.Icons.settings),
                      activeIcon: material.Icon(material.Icons.settings),
                      label: 'Settings',
                    ),
                  ],
                  currentIndex: selectedIndex,
                  selectedItemColor:
                      material.Theme.of(context).colorScheme.primary,
                  unselectedItemColor: material.Colors.grey.shade600,
                  onTap: (index) => _onItemTapped(index, context),
                  type: material.BottomNavigationBarType.fixed,
                  showUnselectedLabels: false,
                  showSelectedLabels: true,
                )
              : null,
        ),
      ],
    );
  }
}
