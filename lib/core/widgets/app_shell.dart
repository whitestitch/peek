// lib/core/widgets/app_shell.dart
import 'package:flutter/material.dart' as material; // Using alias
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/core/router.dart';
import 'package:peek/features/peek/providers/peek_providers.dart';
import 'package:peek/features/menu/drawer_menu.dart'; // Your existing drawer
import 'package:peek/main.dart';
import 'package:peek/theme/colors.dart'; // Your theme colors

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

class _AppShellState extends ConsumerState<AppShell> {
  // Helper function to determine the selected index directly from the router state.
  int _calculateSelectedIndex(String uri) {
    final path = uri.split('?').first;
    if (path.startsWith('/stats')) return 1;
    if (path.startsWith('/onboarding')) return 2;
    if (path.startsWith('/settings')) return 3;
    return 0; // Default to home
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

  @override
  material.Widget build(material.BuildContext context) {
    // This listener for reactions is safe and does not affect navigation.
    ref.listen(newReactionStreamProvider, (previous, next) {
      if (next.isLoading || !next.hasValue) return;
      final newReactions = next.value ?? [];
      for (final reactionDoc in newReactions) {
        final Set<String> processedIds = ref.read(processedReactionIdsProvider);
        if (processedIds.add(reactionDoc.id)) {
          final data = reactionDoc.data();
          final type = data['reactionType'] as String?;
          final overlayService = ref.read(overlayAnimationServiceProvider);
          if (type == 'like') {
            overlayService.showLikeAnimation();
          } else if (type == 'dislike') {
            overlayService.showDislikeAnimation();
          }
        }
      }
    });

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
        material.Image.asset(
          homeBackgroundPath,
          fit: material.BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return material.Container(color: peekBackgroundColor);
          },
        ),
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
          body: widget.child,
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
