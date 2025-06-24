// lib/core/widgets/app_shell.dart
import 'package:flutter/material.dart' as material; // Using alias
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/core/router.dart';
import 'package:peek/features/peek/providers/peek_providers.dart';
import 'package:peek/features/menu/drawer_menu.dart'; // Your existing drawer
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
  int _selectedIndex = 0;
  material.RouteInformationProvider? _routeInformationProviderInstance;

  @override
  void initState() {
    super.initState();
    material.WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          _routeInformationProviderInstance =
              GoRouter.of(context).routeInformationProvider;
          // Initial sync based on the routerState passed to the ShellRoute
          _updateSelectedIndex(widget.routerState.uri.toString());
          _routeInformationProviderInstance?.addListener(_routeListener);
        } catch (e) {
          material.debugPrint(
              "[AppShell] Error accessing GoRouter in initState: $e");
        }
        // _setupAnimationListener();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update selected index if the routerState changes (e.g., navigated via browser bar or deep link)
    if (widget.routerState.uri.toString() !=
        oldWidget.routerState.uri.toString()) {
      _updateSelectedIndex(widget.routerState.uri.toString());
    }
  }

  @override
  void dispose() {
    try {
      _routeInformationProviderInstance?.removeListener(_routeListener);
    } catch (e) {
      material.debugPrint(
          "[AppShell] Error removing GoRouter listener in dispose: $e");
    }
    super.dispose();
  }

  void _routeListener() {
    if (mounted) {
      try {
        // Use widget.routerState.uri as it reflects the current location for the shell's child
        final currentPath = widget.routerState.uri.toString().split('?').first;
        _updateSelectedIndex(currentPath);
      } catch (e) {
        material.debugPrint("[AppShell] Error in _routeListener: $e");
      }
    }
  }

  void _updateSelectedIndex(String currentPathWithQuery) {
    final path = currentPathWithQuery.split('?').first;
    int newIndex = _selectedIndex;
    if (path == '/') {
      newIndex = 0;
    } else if (path == '/stats') {
      newIndex = 1;
    } else if (path == '/onboarding') {
      newIndex = 2;
    } else if (path == '/settings') {
      // Assuming settings is also part of shell
      newIndex = 3;
    }

    if (_selectedIndex != newIndex) {
      if (mounted) {
        setState(() {
          _selectedIndex = newIndex;
        });
      }
    }
  }

  void _onItemTapped(int index, material.BuildContext context) {
    String newRoute;
    switch (index) {
      case 0:
        newRoute = '/';
        break;
      case 1:
        newRoute = '/stats';
        break;
      case 2:
        newRoute = '/onboarding';
        break;
      case 3:
        newRoute = '/settings';
        break;
      default:
        return;
    }
    // Use context.go from the shell's context for top-level navigation
    GoRouter.of(context).go(newRoute);
  }

  @override
  material.Widget build(material.BuildContext context) {
    // Riverpod ensures this only creates one subscription.
    ref.listen(newReactionStreamProvider, (previous, next) {
      if (next.isLoading || !next.hasValue) return;

      final newReactions = next.value ?? [];

      for (final reactionDoc in newReactions) {
        // A Set is used to track processed IDs to prevent re-playing animations on rebuilds.
        final Set<String> processedIds = ref.read(processedReactionIdsProvider);
        if (processedIds.add(reactionDoc.id)) {
          final data = reactionDoc.data();
          final type = data['reactionType'] as String?;

          material.debugPrint(
              "✅ [AppShell] New reaction event received! Type: $type. Triggering animation.");

          final overlayService = ref.read(overlayAnimationServiceProvider);
          if (type == 'like') {
            overlayService.showLikeAnimation();
          } else if (type == 'dislike') {
            overlayService.showDislikeAnimation();
          }
        }
      }
    });

    // The rest of the build method remains exactly the same.
    final String currentPath =
        widget.routerState.uri.toString().split('?').first;

    final bool showAppBar = !routesInShellWithoutAppBar.contains(currentPath);
    final bool showBottomNav = !routesWithoutBottomNav.contains(currentPath);

    const String homeBackgroundPath = 'assets/images/onboarding_bg_02.jpg';

    return material.Stack(
      fit: material.StackFit.expand,
      children: [
        // Layer 1: Persistent Background Image
        material.Image.asset(
          homeBackgroundPath,
          fit: material.BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback color if the image fails to load
            return material.Container(color: peekBackgroundColor);
          },
        ),

        // Layer 2: The Scaffold and the actual page content
        material.Scaffold(
          backgroundColor: material
              .Colors.transparent, // CRUCIAL: Makes the Scaffold see-through
          appBar: showAppBar
              ? material.AppBar(
                  title: const material.Text('Peekio'),
                  elevation: 1.0,
                  backgroundColor: material.Colors.black.withOpacity(0.85),
                  leading: material.Builder(
                      // Use Builder to get context below Scaffold
                      builder: (material.BuildContext context) {
                    return material.IconButton(
                      icon: const material.Icon(material.Icons.menu_rounded),
                      iconSize: 28,
                      tooltip: material.MaterialLocalizations.of(context)
                          .openAppDrawerTooltip,
                      onPressed: () {
                        material.Scaffold.of(context).openDrawer();
                      },
                    );
                  }),
                )
              : null,
          drawer: const DrawerMenu(),
          body: widget.child,
          bottomNavigationBar: showBottomNav
              ? material.BottomNavigationBar(
                  items: const <material.BottomNavigationBarItem>[
                    material.BottomNavigationBarItem(
                      icon: material.Icon(material.Icons.visibility),
                      activeIcon: material.Icon(material.Icons.visibility),
                      label: 'Peek',
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
                  currentIndex: _selectedIndex,
                  selectedItemColor:
                      material.Theme.of(context).colorScheme.primary,
                  unselectedItemColor: material.Colors.grey.shade600,
                  onTap: (index) => _onItemTapped(index, context),
                  backgroundColor: material.Colors.black.withOpacity(1),
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
