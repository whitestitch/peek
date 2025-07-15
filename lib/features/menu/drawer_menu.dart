import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/theme/colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peek/features/premium/providers/premium_controller.dart';

import 'package:firebase_auth/firebase_auth.dart';

class DrawerMenu extends ConsumerWidget {
  const DrawerMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<bool> premiumStatusAsync =
        ref.watch(premiumStatusProvider);
    final bool isPremium = premiumStatusAsync.maybeWhen(
      data: (status) => status,
      orElse: () =>
          false, // Default to non-premium if loading/error for UI purposes
    );

    return Drawer(
      backgroundColor: peekBackgroundColor,
      // Optional: Add background color matching theme
      // backgroundColor: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 80.0, // Reduced height for a more compact header
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              decoration: const BoxDecoration(
                color: peekBackgroundColor, // Color for the header background
                // Optional: add a bottom border if desired
                // border: Border(
                //   bottom: BorderSide(color: Colors.grey.shade700, width: 0.5),
                // ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/images/peekio_logo.svg',
                      height: 28,
                      colorFilter: const ColorFilter.mode(
                        peekWhiteColor, // Match text color
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      ' Menu',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: peekWhiteColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.star_outline_rounded),
              title: const Text('Peek Premium'),
              onTap: () => context.go('/premium'),
            ),

            // ListTile(
            //   leading: Icon(
            //     Icons.bar_chart,
            //     // Grey out icon if not premium
            //     color: isPremium
            //         ? Theme.of(context).iconTheme.color
            //         : Colors.grey.shade600,
            //   ),
            //   title: Text(
            //     'My Stats',
            //     style: TextStyle(
            //       // Grey out text if not premium
            //       color: isPremium ? null : Colors.grey.shade600,
            //     ),
            //   ),
            //   // Disable onTap and show a message if not premium
            //   onTap: isPremium
            //       ? () {
            //           Navigator.pop(context); // Close drawer
            //           context.go('/stats');
            //         }
            //       : () {
            //           Navigator.pop(context); // Close drawer
            //           ScaffoldMessenger.of(context).showSnackBar(
            //             SnackBar(
            //               content: const Text(
            //                   'My Stats is a Premium feature. Upgrade to view.'),
            //               action: SnackBarAction(
            //                 label: 'UPGRADE',
            //                 onPressed: () => context.go('/premium'),
            //               ),
            //               duration: const Duration(seconds: 3),
            //             ),
            //           );
            //         },
            //   // Optional: Add a trailing lock icon if not premium
            //   trailing: !isPremium
            //       ? Icon(Icons.lock_outline,
            //           color: Colors.grey.shade600, size: 20)
            //       : null,
            //   enabled:
            //       isPremium, // Visually indicates if the tile is interactive
            // ),

            ListTile(
                leading: const Icon(Icons.bar_chart_rounded),
                title: const Text('My Stats'),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  context.go('/stats');
                }),
            ListTile(
              // leading: Icon(Icons.settings_outlined,
              //     color: Theme.of(context).iconTheme.color),
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                context.go('/settings'); // Assuming you have a /settings route
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline_rounded),
              title: const Text('Privacy & Safety'),
              onTap: () => context.go('/privacy'),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About Peek'),
              onTap: () => context.go('/info'),
            ),
            ListTile(
              leading: const Icon(Icons.slideshow_rounded),
              title: const Text(
                  'View Tutorial'), // Or "How Peek Works", "Show Intro"
              onTap: () {
                Navigator.pop(context); // Close the drawer first
                context.go('/onboarding'); // Navigate to the onboarding route
              },
            ),
            // const Divider(),
          ],
        ),
      ),
    );
  }
}
