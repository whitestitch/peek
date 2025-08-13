// lib/features/stats/pages/stats_page.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:peek/features/peek/providers/peek_providers.dart'; // For userProfileStreamProvider
import 'package:peek/features/premium/providers/premium_controller.dart'; // For premiumStatusProvider
import 'package:peek/theme/colors.dart'; // Your app's theme colors

class MonthlyStat {
  final int monthValue; // 1 for Jan, 2 for Feb, etc. or 0-5 for last 6 months
  final double likes;
  final double dislikes;
  final String monthLabel;

  MonthlyStat({
    required this.monthValue,
    required this.likes,
    required this.dislikes,
    required this.monthLabel,
  });
}

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  // New State class
  List<MonthlyStat> _monthlyStatsData = [];

  // bool _isLoadingMonthlyData = true;
  // bool _hasFetchedRealData = false;

  // final List<Color> likeGradientColors = [
  //   peekPrimaryColor,
  //   peekErrorColor,
  // ];
  // final List<Color> dislikeGradientColors = [
  //   Colors.redAccent.shade700,
  //   Colors.redAccent.shade200,
  // ];

  // Define colors for the new chart sections
  final Color likeColor = peekPrimaryColor;
  final Color dislikeColor = peekErrorColor;

  @override
  void initState() {
    super.initState();
    // The old data fetch is no longer needed.
  }

  /// Fetches reactions for the current user from the last 6 months and processes them for the chart.

  Widget _buildEmptyState(BuildContext context) {
    // This layout uses an Expanded widget to push the text to the bottom,
    // exactly like the onboarding page.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 35.0),
      child: Column(
        children: [
          // 1. Image Area: Expanded to take up all available vertical space
          //    and push the text content down.
          Expanded(
            child: Center(
              child: SvgPicture.asset(
                'assets/images/no-stats.svg',
                height: 220,
                // colorFilter: ColorFilter.mode(
                //   peekSecondaryColor.withAlpha(200),
                //   BlendMode.srcIn,
                // ),
                colorFilter: ColorFilter.mode(
                  peekSecondaryColor.withOpacity(0.8),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),

          // 2. Text Content Area: This column now sits at the bottom.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "No Feedback Yet",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: peekWhiteColor,
                      letterSpacing: 0.5,
                      fontSize: 34,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                "Your stats will appear here.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: peekOnBackgroundColor.withOpacity(0.85),
                      fontSize: 22,
                    ),
              ),
              const SizedBox(height: 20),
              Text(
                "Start Peeking to get reactions from others and see your performance.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: peekWhiteColor.withOpacity(1),
                      height: 1.55,
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                    ),
              ),
            ],
          ),

          // 3. Bottom Padding: A fixed space between the text and the nav bar.
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildReactionsDoughnutChart(
      BuildContext context, int likes, int dislikes) {
    final totalReactions = likes + dislikes;
    if (totalReactions == 0) {
      return const SizedBox.shrink();
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // This container adds the shadow effect behind the chart
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 45,
              ),
            ],
          ),
        ),
        // The PieChart widget
        PieChart(
          PieChartData(
            sectionsSpace: 4,
            centerSpaceRadius: 85, // Increased for more space
            startDegreeOffset: -90,
            sections: [
              // Dislikes Section
              PieChartSectionData(
                value: dislikes.toDouble(),
                color: dislikeColor.withOpacity(0.5), // Opacity added
                radius: 25, // Increased thickness
                showTitle: false,
              ),
              // Likes Section
              PieChartSectionData(
                value: likes.toDouble(),
                color: likeColor.withOpacity(0.9), // Opacity added
                radius: 25, // Increased thickness
                showTitle: false,
              ),
            ],
          ),
        ),
        // The centered text showing the total count
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              totalReactions.toString(),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: peekWhiteColor,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              "Total Reactions",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade400,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsyncValue = ref.watch(userProfileStreamProvider);
    final isPremiumAsyncValue = ref.watch(premiumStatusProvider);

    final bool isPremium = isPremiumAsyncValue.maybeWhen(
      data: (status) => status,
      orElse: () => false,
    );

    final Color likeCardColor = Colors.green.shade400; // For stat cards
    final Color dislikeCardColor = Colors.red.shade400; // For stat cards

    // Define the background path, consistent with other pages
    // to allow the background to depend on the loaded data.
    return userProfileAsyncValue.when(
      loading: () => const Scaffold(
        backgroundColor: peekBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: peekPrimaryColor)),
      ),
      error: (err, stack) {
        debugPrint("[StatsPage] Error loading user profile: $err");
        return Scaffold(
          backgroundColor: peekBackgroundColor,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "Could not load your stats. Please try again later.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade300),
              ),
            ),
          ),
        );
      },
      data: (userDocSnapshot) {
        // --- All rendering logic is now safely inside the data callback ---

        if (!isPremium) {
          // Non-premium users see the paywall with a specific background.
          const String backgroundPath =
              'assets/images/stats_none_premium_bg.jpg';
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(backgroundPath, fit: BoxFit.cover),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 35.0),
                  child: Column(
                    children: [
                      const Spacer(flex: 10),
                      SvgPicture.asset(
                        'assets/images/lock.svg',
                        height: 260,
                        colorFilter: ColorFilter.mode(
                          peekSecondaryColor.withOpacity(0.6),
                          BlendMode.srcIn,
                        ),
                      ),
                      const Spacer(flex: 10),
                      Text(
                        "Peekio Stats are a Premium Feature",
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w600,
                                  color: peekWhiteColor,
                                ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Upgrade to see how others react to your Peeks!",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: peekWhiteColor.withOpacity(1),
                            ),
                      ),
                      const SizedBox(height: 30),
                      material.OutlinedButton.icon(
                        icon: const Icon(Icons.star_rounded),
                        label: const Text("Upgrade"),
                        onPressed: () => context.go('/premium'),
                      ),
                      const Spacer(flex: 5),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        // --- Logic for Premium Users ---

        if (userDocSnapshot == null || !userDocSnapshot.exists) {
          return const Center(
              child: Text("No user data found to display stats.",
                  style: TextStyle(color: Colors.white70)));
        }

        final userData = userDocSnapshot.data();
        final likesReceived = userData?['likesReceivedCount'] as int? ?? 0;
        final dislikesReceived =
            userData?['dislikesReceivedCount'] as int? ?? 0;
        final totalReactions = likesReceived + dislikesReceived;
        final bool hasStats = totalReactions > 0;

        // **This is the core of the new logic:**
        // The background is premium ONLY if the user is premium AND has stats.
        final String backgroundPath = (isPremium && hasStats)
            ? 'assets/images/stats_premium_bg.jpg'
            : 'assets/images/stats_none_premium_bg.jpg';

        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              backgroundPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: peekBackgroundColor);
              },
            ),
            if (hasStats)
              // If stats exist, return the scrollable column.
              SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Text("Your Peek Performance",
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Text("Reactions to Your Peeks",
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.grey.shade400)),
                    const SizedBox(height: 40),
                    SizedBox(
                      height: 280,
                      child: _buildReactionsDoughnutChart(
                          context, likesReceived, dislikesReceived),
                    ),
                    const SizedBox(height: 50),
                    _buildStatCard(
                        context: context,
                        icon: Icons.favorite_rounded,
                        label: "Total Likes Received",
                        value: likesReceived.toString(),
                        iconColor: likeCardColor),
                    const SizedBox(height: 15),
                    _buildStatCard(
                        context: context,
                        icon: Icons.thumb_down_alt_rounded,
                        label: "Total Dislikes Received",
                        value: dislikesReceived.toString(),
                        iconColor: dislikeCardColor),
                    const SizedBox(height: 15),
                    _buildStatCard(
                        context: context,
                        icon: Icons.functions_rounded,
                        label: "Total Reactions",
                        value: totalReactions.toString(),
                        iconColor: Colors.blueGrey.shade300),
                    const SizedBox(height: 30),
                  ],
                ),
              )
            else
              // If no stats, return the empty state widget.
              _buildEmptyState(context),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Card(
      elevation: 2,
      color: peekSecondaryColor.withAlpha(35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 28,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: peekOnSurfaceColor.withOpacity(0.9),
                    fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: iconColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
