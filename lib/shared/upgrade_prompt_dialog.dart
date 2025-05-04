// lib/shared/upgrade_prompt_dialog.dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Enum remains the same
enum UpgradeReason { periodic, dailyLimitReached }

class UpgradePromptDialog extends StatelessWidget {
  final UpgradeReason? reason;
  const UpgradePromptDialog({super.key, this.reason});

  @override
  Widget build(BuildContext context) {
    // Log dialog shown event immediately
    try {
      // Optional try-catch
      FirebaseAnalytics.instance.logEvent(
        name: 'upgrade_prompt_shown',
        parameters: {
          'reason':
              reason?.toString().split('.').last ??
              'unknown', // 'periodic' or 'dailyLimitReached'
        },
      );
      debugPrint(
        "[UpgradePromptDialog] Logged upgrade_prompt_shown event (Reason: ${reason?.toString().split('.').last ?? 'unknown'}).",
      );
    } catch (e) {
      debugPrint("Error logging upgrade_prompt_shown event: $e");
    }
    String titleText = "✨ Unlock Peek Premium";
    String contentText = "Upgrade to enjoy these benefits:";
    switch (reason) {
      case UpgradeReason.dailyLimitReached:
        titleText = "🚫 Daily Limit Reached!";
        contentText =
            "You've used all your free peeks for today.\nUpgrade to Premium for unlimited access and more:";
        break;
      case UpgradeReason.periodic:
        contentText =
            "Enjoying Peek? Upgrade to Premium and enjoy these benefits:";
        break;
      case null:
      default:
        break;
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      title: Center(
        child: Text(
          titleText,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Text(contentText, textAlign: TextAlign.center)),
          const SizedBox(height: 20),
          // *** FIX: Call the public BenefitRow constructor ***
          const BenefitRow(text: 'Unlimited Peeking'),
          const BenefitRow(text: 'No Cooldowns'),
          const BenefitRow(text: 'Longer Peek Duration'),
          const BenefitRow(text: 'Replay Peeks'),
          // Ensure BenefitRow definition below handles text correctly
          const BenefitRow(text: 'More features coming soon...'),
          // *** END OF FIX ***
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actionsAlignment: MainAxisAlignment.center,
      actions: <Widget>[
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Maybe Later'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.star, size: 18),
          label: const Text('Upgrade Now'),
          style: ElevatedButton.styleFrom(
            elevation: 2,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          onPressed: () {
            try {
              // Optional try-catch
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
  const BenefitRow({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    // Determine if text starts with an emoji (simple check)
    String iconText = '✅'; // Default icon
    String mainText = text;
    if (text.isNotEmpty &&
        !RegExp(r'^[a-zA-Z0-9 ]').hasMatch(text.substring(0, 1))) {
      // Assume first char is an icon/emoji if not alphanumeric/space
      iconText = text.substring(0, text.indexOf(' ')).trim();
      mainText = text.substring(text.indexOf(' ')).trim();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Use Text for flexible icons/emojis
          Text(iconText, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mainText, // Display text without the leading icon/emoji
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.3),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}
