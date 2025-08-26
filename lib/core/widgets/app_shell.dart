import 'package:flutter/material.dart' as material;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/core/router.dart';
import 'package:peek/features/peek/providers/peek_providers.dart';
import 'package:peek/core/providers/session_providers.dart';
import 'package:peek/features/menu/drawer_menu.dart';
import 'package:peek/theme/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:peek/main.dart';

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
  // 🔒 ENHANCED: Track navigation state to prevent reactions during transitions
  bool _isNavigating = false;
  DateTime? _lastNavigationTime;
  String? _lastRoute;
  // 🔒 ENHANCED: Queue reactions during sessions/navigation
  final List<Map<String, dynamic>> _queuedReactions = [];
  bool _isProcessingQueue = false;

  // 🔒 ENHANCED: Clear processed reactions (called when session changes)
  void _clearProcessedReactions() {
    material.debugPrint(
        '[AppShell] 🧹 Clearing processed reactions (${_processedReactionIds.length} items)');
    _processedReactionIds.clear();
    _lastSeenReactionTime = DateTime.now();
    // Also reset animation state to prevent stuck animations
    if (_showReactionAnimation) {
      _showReactionAnimation = false;
      _currentReactionId = null;
      _currentReactionType = null;
    }
    // Mark as navigating to suppress reactions during state changes
    _markNavigating();
  }

  // 🔒 ENHANCED: Mark navigation state to prevent reactions during transitions
  void _markNavigating() {
    _isNavigating = true;
    _lastNavigationTime = DateTime.now();
    material.debugPrint(
        '[AppShell] 🚦 Navigation state marked - suppressing reactions');

    // Clear navigation state after a short delay
    Future.delayed(const Duration(milliseconds: 1000), () {
      // Reduced from 2000ms to 1000ms
      if (mounted) {
        _isNavigating = false;
        material.debugPrint(
            '[AppShell] 🚦 Navigation state cleared - reactions can resume');
        // Process any queued reactions
        _processQueuedReactions();
      }
    });
  }

  // 🔒 ENHANCED: Queue a reaction to show later
  void _queueReaction(
      String reactionId, String reactionType, DateTime timestamp) {
    // Don't queue if already processed or queued
    if (_processedReactionIds.contains(reactionId) ||
        _queuedReactions.any((r) => r['id'] == reactionId)) {
      return;
    }

    material.debugPrint(
        '[AppShell] 📥 Queuing reaction: $reactionType ($reactionId)');
    _queuedReactions.add({
      'id': reactionId,
      'type': reactionType,
      'timestamp': timestamp,
    });

    // Sort by timestamp (newest first)
    _queuedReactions.sort((a, b) =>
        (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    // Keep only the most recent 3 reactions to avoid spam
    if (_queuedReactions.length > 3) {
      _queuedReactions.removeRange(3, _queuedReactions.length);
    }
  }

  // 🔒 ENHANCED: Process queued reactions when safe to do so
  void _processQueuedReactions() {
    if (_isProcessingQueue ||
        _queuedReactions.isEmpty ||
        _showReactionAnimation ||
        _isNavigating) {
      return;
    }

    _isProcessingQueue = true;
    material.debugPrint(
        '[AppShell] 📤 Processing ${_queuedReactions.length} queued reactions');

    // Process the newest queued reaction
    final reaction = _queuedReactions.removeAt(0);
    final reactionId = reaction['id'] as String;
    final reactionType = reaction['type'] as String;

    // Double-check it hasn't been processed already
    if (!_processedReactionIds.contains(reactionId)) {
      _processedReactionIds.add(reactionId);
      _lastSeenReactionTime = reaction['timestamp'] as DateTime;

      material.debugPrint(
          '[AppShell] 🎯 Processing queued reaction: $reactionType ($reactionId)');
      _showReactionDialog(reactionId, reactionType);
    }

    _isProcessingQueue = false;

    // Schedule next queued reaction if any remain
    if (_queuedReactions.isNotEmpty && mounted) {
      Future.delayed(const Duration(seconds: 6), () {
        // Wait for current dialog to finish
        if (mounted) _processQueuedReactions();
      });
    }
  }

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
    // 🔒 ENHANCED: Initialize last seen time to a reasonable past time to allow recent reactions
    // This allows reactions from the last 5 minutes to be shown when app starts
    _lastSeenReactionTime = DateTime.now().subtract(const Duration(minutes: 5));

    // 🔒 ENHANCED: Listen for session state changes to clear processed reactions
    material.WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Listen for session state changes and clear processed reactions on session end
        _clearProcessedReactions(); // Clear on init
      }
    });

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

  // 🔒 ENHANCED: Method to show the reaction dialog with better state management
  void _showReactionDialog(String reactionId, String reactionType) {
    // Prevent showing if already showing animation or same reaction
    if (_showReactionAnimation || _currentReactionId == reactionId) {
      material.debugPrint(
          '[AppShell] ⚠️ Skipping reaction dialog - showing: $_showReactionAnimation, same ID: ${_currentReactionId == reactionId}');
      return;
    }

    // Check if we have a valid context
    if (!mounted) {
      material.debugPrint(
          '[AppShell] ⚠️ Cannot show reaction dialog - not mounted');
      return;
    }

    material.debugPrint(
        '[AppShell] ▶ Showing reaction dialog for $reactionType ($reactionId)');

    // Mark as processed to prevent duplicates
    _processedReactionIds.add(reactionId);

    setState(() {
      _currentReactionId = reactionId;
      _currentReactionType = reactionType;
      _showReactionAnimation = true;
    });

    // Start the card entrance animation
    _cardAnimationController.forward();

    // Show the reaction dialog using showDialog to avoid z-index conflicts
    try {
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
    } catch (e) {
      material.debugPrint('[AppShell] ❌ Error in showDialog: $e');
      // Reset state if dialog fails
      setState(() {
        _showReactionAnimation = false;
        _currentReactionId = null;
        _currentReactionType = null;
      });
      return;
    }

    // Auto-hide after 5 seconds
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (mounted &&
          _currentReactionId == reactionId &&
          _showReactionAnimation) {
        material.debugPrint(
            '[AppShell] ⏹ Auto-hiding reaction dialog for $reactionType ($reactionId)');
        _hideReactionDialog();
      } else {
        material.debugPrint(
            '[AppShell] ⚠️ Skipping auto-hide - mounted: $mounted, correct ID: ${_currentReactionId == reactionId}, showing: $_showReactionAnimation');
      }
    });
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

  // 🔒 OPTIMIZED: Method to build the card-style reaction dialog
  material.Widget _buildReactionDialog() {
    // Build the content once and cache it
    final dialogContent = _buildReactionDialogContent();

    return material.AnimatedBuilder(
      animation: _cardAnimationController,
      child: dialogContent, // Pass as child to avoid rebuilding
      builder: (context, child) {
        return material.Transform.translate(
          offset: material.Offset(0, _cardSlideAnimation.value * 100),
          child: material.Transform.scale(
            scale: _cardScaleAnimation.value,
            child: material.Opacity(
              opacity: _cardFadeAnimation.value,
              child: child, // Use the cached content
            ),
          ),
        );
      },
    );
  }

  // 🔒 OPTIMIZED: Build the static content of the reaction dialog (called once)
  material.Widget _buildReactionDialogContent() {
    return material.Center(
      child: material.Container(
        width: 320,
        height: 320, // Increased from 280 to accommodate the icon above title
        margin: const material.EdgeInsets.all(32),
        decoration: material.BoxDecoration(
          color: peekBackgroundColor,
          borderRadius: material.BorderRadius.circular(24),
        ),
        padding: const material.EdgeInsets.all(24.0),
        child: material.Column(
          mainAxisAlignment: material.MainAxisAlignment.center,
          children: [
            // Title with icon above
            material.Column(
              children: [
                // Icon above title
                material.Icon(
                  _currentReactionType == 'like'
                      ? material.Icons.favorite
                      : material.Icons.heart_broken,
                  size: 48,
                  color: _currentReactionType == 'like'
                      ? peekPrimaryColor
                      : peekErrorColor,
                ),
                const material.SizedBox(height: 16),
                // Title text
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
              ],
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
    );
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    super.dispose();
  }

  @override
  material.Widget build(material.BuildContext context) {
    // 🔒 ENHANCED: Track route changes to suppress reactions during navigation
    final currentRoute = widget.routerState.uri.toString();
    if (_lastRoute != currentRoute) {
      _lastRoute = currentRoute;
      _markNavigating();
    }

    // 🔒 ENHANCED: Monitor session state to process queued reactions
    final sessionState = ref.watch(sessionStateProvider);
    if (sessionState == 'idle' &&
        _queuedReactions.isNotEmpty &&
        !_isNavigating) {
      material.WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _processQueuedReactions();
      });
    }

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
    } else if (reactionStream.hasError) {
      material.debugPrint(
          "[AppShell] ❌ Reaction stream error: ${reactionStream.error}");
    } else {}

    // Declaratively calculate the index and UI visibility from the router state.
    final int selectedIndex =
        _calculateSelectedIndex(widget.routerState.uri.toString());
    final String currentPath =
        widget.routerState.uri.toString().split('?').first;
    final bool showAppBar = !routesInShellWithoutAppBar.contains(currentPath);
    final bool showBottomNav = !routesWithoutShell.contains(currentPath);

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
              // 🔒 ENHANCED: Reaction watcher with proper state management
              Consumer(
                builder: (context, ref, child) {
                  // Watch for new reactions
                  final newReactions = ref.watch(newReactionStreamProvider);

                  // 🔒 ENHANCED: Process reactions only when safe to do so
                  if (newReactions.hasValue &&
                      newReactions.value!.isNotEmpty &&
                      !_showReactionAnimation &&
                      !_isNavigating && // Don't show during navigation
                      mounted) {
                    material.debugPrint(
                        '[AppShell] 🔍 Processing reactions - animation: $_showReactionAnimation, navigating: $_isNavigating, mounted: $mounted');
                    // Process all reactions to find the newest unprocessed one
                    QueryDocumentSnapshot<Map<String, dynamic>>? newestReaction;
                    DateTime? newestTimestamp;

                    for (final reaction in newReactions.value!) {
                      final reactionId = reaction.id;
                      final data = reaction.data();
                      final reactionTime = data['timestamp'] as Timestamp?;

                      // Skip if already processed or no timestamp
                      if (_processedReactionIds.contains(reactionId) ||
                          reactionTime == null) {
                        continue;
                      }

                      final timestamp = reactionTime.toDate();

                      // Skip very old reactions (30+ minutes)
                      final reactionAge = DateTime.now().difference(timestamp);
                      if (reactionAge > const Duration(minutes: 30)) {
                        continue;
                      }

                      // Skip if older than last seen (with 2 minute buffer)
                      if (_lastSeenReactionTime != null &&
                          timestamp.isBefore(_lastSeenReactionTime!)) {
                        final timeSinceLastSeen =
                            _lastSeenReactionTime!.difference(timestamp);
                        if (timeSinceLastSeen > const Duration(minutes: 2)) {
                          continue;
                        }
                      }

                      // 🔒 ENHANCED: Skip reactions that are too close to navigation events
                      if (_lastNavigationTime != null) {
                        final timeSinceNavigation =
                            timestamp.difference(_lastNavigationTime!).abs();
                        if (timeSinceNavigation < const Duration(seconds: 2)) {
                          // Reduced from 5s to 2s
                          material.debugPrint(
                              '[AppShell] ⏭️ Skipping reaction too close to navigation: $reactionId (${timeSinceNavigation.inSeconds}s)');
                          continue;
                        }
                      }

                      // Check if this is the newest unprocessed reaction
                      if (newestTimestamp == null ||
                          timestamp.isAfter(newestTimestamp)) {
                        newestReaction = reaction;
                        newestTimestamp = timestamp;
                      }
                    }

                    // 🔒 ENHANCED: Handle newest unprocessed reaction with queuing
                    if (newestReaction != null) {
                      final data = newestReaction.data();

                      final reactionType =
                          (data['reactionType'] ?? '').toString().toLowerCase();
                      final reactionId = newestReaction.id;

                      material.debugPrint(
                          '[AppShell] 🔍 Extracted - ID: $reactionId, Type: "$reactionType", Already processed: ${_processedReactionIds.contains(reactionId)}');

                      if (reactionType == 'like' || reactionType == 'dislike') {
                        material.debugPrint(
                            '[AppShell] 🔍 Found valid reaction: $reactionType ($reactionId) - Raw data: ${data['reactionType']}');

                        // Check if we should show immediately or queue
                        final canShowNow =
                            !_showReactionAnimation && !_isNavigating;

                        material.debugPrint(
                            '[AppShell] 🔍 Can show now: $canShowNow (animation: $_showReactionAnimation, navigating: $_isNavigating)');

                        if (canShowNow) {
                          material.debugPrint(
                              '[AppShell] 🎯 Processing newest reaction: $reactionType ($reactionId)');

                          // Don't mark as processed yet - let _showReactionDialog do it
                          _lastSeenReactionTime = newestTimestamp;

                          // Show reaction dialog in next frame with better error handling
                          material.WidgetsBinding.instance
                              .addPostFrameCallback((_) {
                            try {
                              if (mounted && !_showReactionAnimation) {
                                material.debugPrint(
                                    '[AppShell] 🚀 About to show reaction dialog');
                                _showReactionDialog(reactionId, reactionType);

                                // Update the last processed reaction time provider
                                ref
                                    .read(lastProcessedReactionTimeProvider
                                        .notifier)
                                    .state = newestTimestamp!;
                              } else {
                                material.debugPrint(
                                    '[AppShell] ⚠️ Cannot show dialog - mounted: $mounted, animation: $_showReactionAnimation');
                              }
                            } catch (e) {
                              material.debugPrint(
                                  '[AppShell] ❌ Error showing reaction dialog: $e');
                              // If showing fails, queue it for later
                              _queueReaction(
                                  reactionId, reactionType, newestTimestamp!);
                            }
                          });
                        } else {
                          // Queue for later processing
                          material.debugPrint(
                              '[AppShell] 📥 Queueing reaction due to state: animation=$_showReactionAnimation, navigating=$_isNavigating');
                          _queueReaction(
                              reactionId, reactionType, newestTimestamp!);
                        }
                      } else {
                        material.debugPrint(
                            '[AppShell] ⚠️ Invalid reaction type: $reactionType');
                      }
                    }
                  }

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
