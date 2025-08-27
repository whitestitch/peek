// lib/shared/upgrade_prompt_dialog.dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/theme/colors.dart';

// Enum remains the same
enum UpgradeReason {
  dailyLimitReached,
  periodic,
  anonymous,
  custom,
}

class UpgradePromptDialog extends StatelessWidget {
  final UpgradeReason reason;
  final String? customTitle;
  final String? customMessage;

  const UpgradePromptDialog({
    super.key,
    required this.reason,
    this.customTitle,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    try {
      // Optional try-catch
      FirebaseAnalytics.instance.logEvent(
        name: 'upgrade_prompt_shown',
        parameters: {
          'reason': reason?.toString().split('.').last ??
              'unknown', // 'periodic' or 'dailyLimitReached'
        },
      );
      debugPrint(
        "[UpgradePromptDialog] Logged upgrade_prompt_shown event (Reason: ${reason?.toString().split('.').last ?? 'unknown'}).",
      );
    } catch (e) {
      debugPrint("Error logging upgrade_prompt_shown event: $e");
    }

    String titleText;
    String contentText;

    switch (reason) {
      case UpgradeReason.dailyLimitReached:
        titleText = "🚫 Daily Limit Reached!";
        contentText =
            "You've used all your free Peekios for today.\nUpgrade to Premium for unlimited access and more:";
        break;
      case UpgradeReason.periodic:
        titleText = "More Peeks.\nLess Limits.";
        contentText =
            "Upgrade — unlock more eyes, skip the waits, expand your view.";
        break;
      case UpgradeReason.anonymous:
        titleText = 'Account Required';
        contentText =
            'Please sign in or create an account to send Peekios and enjoy all features.';
        break;
      case UpgradeReason.custom:
        titleText = customTitle ?? "Peekio Premium";
        contentText = customMessage ?? "Upgrade to enjoy these benefits:";
        break;
    }

    return AlertDialog(
      // 🔒 FIX: Enlarge dialog and use consistent styling
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      backgroundColor: peekBackgroundColor,
      title: Text(
        titleText,
        textAlign: TextAlign.left,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: peekWhiteColor,
              letterSpacing: 0.5,
              // 🔒 FIX: Make text size responsive
              fontSize: MediaQuery.of(context).size.width < 400 ? 28 : 32,
            ),
      ),

      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              contentText,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: peekWhiteColor.withValues(alpha: 0.9),
                fontSize: MediaQuery.of(context).size.width < 400 ? 15 : 17,
                height: 1.9,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 🔒 FIX: Shorten long feature names to prevent overflow
          const BenefitRow(
            icon: Icons.all_inclusive,
            text: "Unlimited Peekios",
          ),
          const BenefitRow(
            icon: Icons.flash_on,
            text: "No waiting.",
          ),
          const BenefitRow(
            icon: Icons.bar_chart,
            text: "Peek Stats unlocked.",
          ),
          const Divider(height: 20, color: Colors.white24),
          const BenefitRow(
            icon: Icons.drive_file_rename_outline,
            text: "Custom display name.",
          ),
          const BenefitRow(
            icon: Icons.visibility_outlined,
            text: "See who Peek’d you.",
          ),
          const BenefitRow(
            icon: Icons.location_on_outlined,
            text: "Sender’s location hint.",
          ),
          const Divider(height: 20, color: Colors.white24),
          const BenefitRow(
            icon: Icons.chat_outlined,
            text: "Anonymous Chat (soon).",
            isAvailable: false, // This will style it as a "coming soon" feature
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      // Align buttons to the opposite ends of the dialog
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: <Widget>[
        // Use a TextButton for a transparent "Skip" or "Maybe Later" style
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: peekWhiteColor.withValues(alpha: 0.7),
            textStyle: TextStyle(
              // 🔒 FIX: Make text size responsive
              fontSize: MediaQuery.of(context).size.width < 400 ? 15 : 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Maybe Later'),
        ),
        // This is the primary action button
        ElevatedButton.icon(
          // icon: const Icon(Icons.star, size: 18),
          label: const Text('Upgrade'),
          style: ElevatedButton.styleFrom(
            elevation: 2,
            backgroundColor: peekPrimaryColor,
            foregroundColor: peekSurfaceColor,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: () {
            try {
              FirebaseAnalytics.instance.logEvent(
                name: 'upgrade_prompt_accepted',
                parameters: {
                  'reason': reason?.toString().split('.').last ?? 'unknown',
                },
              );
              debugPrint(
                "[UpgradePromptDialog] Logged upgrade_prompt_accepted event.",
              );
            } catch (e) {
              debugPrint("Error logging upgrade_prompt_accepted event: $e");
            }
            Navigator.of(context).pop(true);
            context.go('/premium');
          },
        ),
      ],
    );
  }
}

// Ensure BenefitRow definition is present and public in this file
class BenefitRow extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool isAvailable;

  const BenefitRow({
    super.key,
    required this.text,
    required this.icon,
    this.isAvailable = true,
  });

  @override
  Widget build(BuildContext context) {
    // Use theme colors for consistency
    const Color availableColor = peekPrimaryColor;
    final Color unavailableColor = Colors.grey.shade600;
    final Color iconColor = isAvailable ? availableColor : unavailableColor;
    final Color textColor = isAvailable
        ? Theme.of(context).textTheme.bodyMedium!.color!
        : unavailableColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        // 🔒 FIX: Make text size responsive
                        fontSize:
                            MediaQuery.of(context).size.width < 400 ? 13 : 15,
                      ),
                ),
                // if (!isAvailable)
                //   Text(
                //     " (Coming Soon)",
                //     style: Theme.of(context).textTheme.bodySmall?.copyWith(
                //           color: unavailableColor,
                //           fontStyle: FontStyle.italic,
                //           // 🔒 FIX: Make text size responsive
                //           fontSize:
                //               MediaQuery.of(context).size.width < 400 ? 11 : 13,
                //         ),
                //   ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
