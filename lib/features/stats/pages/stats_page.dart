// lib/features/stats/pages/stats_page.dart
import 'dart:math';
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
  // To show a loader for dummy data generation
  bool _isLoadingMonthlyData = true;
  // int _touchedIndex = -1;

  // Define gradient colors (can be themed later)
  final List<Color> likeGradientColors = [
    Colors.greenAccent.shade700,
    Colors.greenAccent.shade200,
  ];
  final List<Color> dislikeGradientColors = [
    Colors.redAccent.shade700,
    Colors.redAccent.shade200,
  ];

  @override
  void initState() {
    super.initState();
    _generateDummyMonthlyData();
  }

  void _generateDummyMonthlyData() {
    final random = Random();
    final List<MonthlyStat> dummyData = [];
    final now = DateTime.now();

    // Generate for the last 6 months, including the current month
    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      dummyData.add(MonthlyStat(
        monthValue: 5 - i, // X-axis value: 0 for earliest, 5 for current
        likes: random.nextInt(25) + 5.toDouble(), // Likes between 5-29
        dislikes: random.nextInt(10) + 2.toDouble(), // Dislikes between 2-11
        monthLabel: DateFormat('MMM').format(monthDate), // e.g., "May"
      ));
    }
    if (mounted) {
      setState(() {
        _monthlyStatsData = dummyData;
        _isLoadingMonthlyData = false;
      });
    }
  }

  Widget _buildMonthlyLineChart(
      BuildContext context, int totalLifetimeLikes, int totalLifetimeDislikes) {
    if (_isLoadingMonthlyData) {
      return const Center(
          child: CircularProgressIndicator(color: peekPrimaryColor));
    }

    if (totalLifetimeLikes == 0 && totalLifetimeDislikes == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome,
                  size: 70, // Slightly smaller icon
                  color: peekAccentColor.withOpacity(0.8)),
              const SizedBox(height: 20),
              Text(
                "You haven't been rated yet!", // More direct message
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall // Adjusted for emphasis
                    ?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Start Peeking to get your first Like and see your stats shine here!",
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.grey.shade400, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    if (_monthlyStatsData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sentiment_dissatisfied_rounded,
                size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              "No Reaction Data Yet",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    double maxYValue = 0;
    for (var stat in _monthlyStatsData) {
      if (stat.likes > maxYValue) maxYValue = stat.likes;
      if (stat.dislikes > maxYValue) maxYValue = stat.dislikes;
    }
    maxYValue = (maxYValue == 0) ? 10 : (maxYValue * 1.2 + 10);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (_monthlyStatsData.length - 1)
            .toDouble(), // Based on number of months
        minY: 0,
        maxY: maxYValue,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true, // Show vertical lines like sample
          horizontalInterval:
              maxYValue > 20 ? (maxYValue / 4).roundToDouble() : 5,
          verticalInterval: 1, // Interval for months
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: peekSurfaceColor.withOpacity(0.7),
              strokeWidth: 0.8,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: peekSurfaceColor.withOpacity(0.7),
              strokeWidth: 0.8,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index < 0 || index >= _monthlyStatsData.length) {
                  return Container();
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 8.0,
                  child: Text(
                    _monthlyStatsData[index].monthLabel,
                    style: TextStyle(
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.bold,
                        fontSize: 12), // Smaller font for month labels
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxYValue > 20 ? (maxYValue / 4).roundToDouble() : 5,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value == meta.min && meta.max == meta.min && value == 0) {
                  return Container();
                }
                if (value == meta.min && meta.max != meta.min && value == 0) {
                  // Hide 0 if not the only y-value
                  return Container();
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4.0,
                  child: Text(value.toInt().toString(),
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                );
              },
              reservedSize: 38,
            ),
          ),
        ),
        borderData: FlBorderData(
            show: true,
            border:
                Border.all(color: peekSurfaceColor.withOpacity(0.8), width: 1)),
        lineBarsData: [
          // Likes Line
          LineChartBarData(
            spots: _monthlyStatsData
                .map((stat) => FlSpot(
                    stat.monthValue.toDouble(), stat.likes)) // Used monthValue
                .toList(),
            isCurved: true,
            gradient: LinearGradient(colors: likeGradientColors),
            // colors: likeGradientColors,
            barWidth: 4, // Thinner line like sample
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: likeGradientColors
                    .map((color) => color.withOpacity(0.3))
                    .toList(),
              ),
            ),
          ),
          // Dislikes Line
          LineChartBarData(
            spots: _monthlyStatsData
                .map((stat) => FlSpot(stat.monthValue.toDouble(),
                    stat.dislikes)) // Used monthValue
                .toList(),
            isCurved: true,
            gradient: LinearGradient(colors: dislikeGradientColors),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: dislikeGradientColors
                    .map((color) => color.withOpacity(0.3))
                    .toList(),
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots
                  .map((barSpot) {
                    final flSpot = barSpot;
                    String title = '';
                    String count = flSpot.y.toInt().toString();
                    Color spotColor = Colors.transparent;

                    final int spotIndex = flSpot.x.toInt();
                    if (spotIndex < 0 || spotIndex >= _monthlyStatsData.length)
                      return null;
                    final monthLabel = _monthlyStatsData[spotIndex].monthLabel;

                    if (barSpot.barIndex == 0) {
                      title = 'Likes: ';
                      spotColor = likeGradientColors.first;
                    } else if (barSpot.barIndex == 1) {
                      title = 'Dislikes: ';
                      spotColor = dislikeGradientColors.first;
                    } else {
                      return null; // Should not happen
                    }

                    return LineTooltipItem(
                        '$monthLabel\n',
                        TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                        children: [
                          TextSpan(
                            text: title,
                            style: TextStyle(
                                color: spotColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 12),
                          ),
                          TextSpan(
                            text: count,
                            style: TextStyle(
                                color: spotColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          )
                        ]);
                  })
                  .whereType<LineTooltipItem>()
                  .toList();
            },
          ),
          handleBuiltInTouches: true,
        ),
        // swapAnimationDuration: const Duration(milliseconds: 250),
        // swapAnimationCurve: Curves.easeInOut,
      ),
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
    const String backgroundPath = 'assets/images/stats_bg.jpg';

    // The Stack is now the root widget of the page content
    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: Background Image (This remains)
        Image.asset(
          backgroundPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(color: peekBackgroundColor);
          },
        ),

        // Layer 2: The page content (The Scaffold and AppBar are removed from here)
        userProfileAsyncValue.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: peekPrimaryColor)),
          error: (err, stack) {
            debugPrint("[StatsPage] Error loading user profile: $err");
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "Could not load your stats. Please try again later.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade300),
                ),
              ),
            );
          },
          data: (userDocSnapshot) {
            if (!isPremium) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/images/lock.svg',
                        height: 180,
                        colorFilter: ColorFilter.mode(
                            peekSecondaryColor.withOpacity(0.6),
                            BlendMode.srcIn),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Peek Stats are a Premium Feature",
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  // color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                  color: peekWhiteColor,
                                ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Upgrade to Peek Premium to see how others react to your Peeks!",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey.shade400,
                            ),
                      ),
                      const SizedBox(height: 30),
                      // ElevatedButton.icon(
                      material.OutlinedButton.icon(
                        icon: const Icon(Icons.star_rounded),
                        label: const Text("Upgrade"),
                        onPressed: () {
                          context.go('/premium');
                        },
                        // style: ElevatedButton.styleFrom(
                        //   backgroundColor: peekSecondaryColor,
                        //   padding: const EdgeInsets.symmetric(
                        //       horizontal: 30, vertical: 15),
                        // ),
                      )
                    ],
                  ),
                ),
              );
            }

            if (userDocSnapshot == null || !userDocSnapshot.exists) {
              return const Center(
                child: Text("No user data found to display stats.",
                    style: TextStyle(color: Colors.white70)),
              );
            }

            final userData = userDocSnapshot.data();
            final likesReceived = userData?['likesReceivedCount'] as int? ?? 0;
            final dislikesReceived =
                userData?['dislikesReceivedCount'] as int? ?? 0;
            final totalReactions = likesReceived + dislikesReceived;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    "Your Peek Performance",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Reactions to Your Peeks",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade400,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 300,
                    child: _buildMonthlyLineChart(
                        context, likesReceived, dislikesReceived),
                  ),
                  const SizedBox(height: 40),
                  _buildStatCard(
                    context: context,
                    icon: Icons.favorite_rounded,
                    label: "Total Likes Received",
                    value: likesReceived.toString(),
                    iconColor: likeCardColor,
                  ),
                  const SizedBox(height: 15),
                  _buildStatCard(
                    context: context,
                    icon: Icons.thumb_down_alt_rounded,
                    label: "Total Dislikes Received",
                    value: dislikesReceived.toString(),
                    iconColor: dislikeCardColor,
                  ),
                  const SizedBox(height: 15),
                  _buildStatCard(
                    context: context,
                    icon: Icons.functions_rounded,
                    label: "Total Reactions",
                    value: totalReactions.toString(),
                    iconColor: Colors.blueGrey.shade300,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ],
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
      color: peekSurfaceColor.withOpacity(0.85),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
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
