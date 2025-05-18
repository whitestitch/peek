import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../controllers/subscription_controller.dart';
import '../providers/premium_controller.dart';
import '../controllers/subscription_state.dart';
import 'package:url_launcher/url_launcher.dart';

class PeekPremiumPage extends ConsumerWidget {
  const PeekPremiumPage({super.key});

  /// Helper widget for displaying premium features in a list tile format.
  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    String? status,
    bool isAvailable = true,
  }) {
    final Color tileColor = isAvailable ? Colors.white : Colors.grey.shade600;
    final Color statusColor = Colors.grey.shade500;
    // Use const where possible
    return ListTile(
      leading: Icon(icon, color: tileColor, size: 28),
      title: Text(title, style: TextStyle(color: tileColor, fontSize: 16)),
      trailing: status != null
          ? Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: statusColor,
                fontStyle: FontStyle.italic,
              ),
            )
          : null,
      dense: true,
      minLeadingWidth: 10,
    );
  }

  Future<void> _launchUrl(Uri url, BuildContext context) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // Optionally, show an error message if the URL can't be launched
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Could not open subscription settings. Please go to App Store > Account > Subscriptions.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // --- Watch Actual Riverpod Providers ---
    // Watch the premium status directly from premium_controller.dart (using corrected import)
    final AsyncValue<bool> premiumStatusAsync = ref.watch(
      premiumStatusProvider,
    );
    // Watch the state from the new subscription controller (using corrected import)
    final SubscriptionState subState = ref.watch(
      subscriptionControllerProvider,
    );
    final ProductDetails? product = subState.premiumProduct;
    // Use the isLoading state from the subscription controller
    final bool isLoading = subState.isLoading;
    // --- End Watching Providers ---

    // Safely determine premium status
    final bool isAlreadyPremium = premiumStatusAsync.maybeWhen(
      data: (status) => status,
      orElse: () => false, // Default false if loading/error
    );

    // Safely get the price string
    final String priceString = product?.price ?? '...';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Peek Premium'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Restore Purchases Button
          if (!isAlreadyPremium)
            TextButton(
              // Disable while loading
              onPressed: isLoading
                  ? null
                  : () => ref
                      .read(subscriptionControllerProvider.notifier)
                      .restorePurchases(),
              child:
                  isLoading // Show small loader if loading during restore attempt
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Restore",
                          style: TextStyle(color: Colors.white70),
                        ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
          child: Padding(
        padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Title ---
            Center(
              child: Text(
                isAlreadyPremium
                    ? "You are already Premium!"
                    : "Upgrade to Peek Premium",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                "Unlock unlimited access and exclusive features.",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // --- Feature List ---
            _buildFeatureTile(
              icon: Icons.all_inclusive,
              title: "Unlimited Peeks Per Day",
            ),
            _buildFeatureTile(
              icon: Icons.flash_on,
              title: "Peek Without Cooldowns",
            ),
            _buildFeatureTile(
              icon: Icons.hourglass_bottom,
              title: "Longer Image View Duration",
            ),
            const Divider(height: 24, color: Colors.white24),
            _buildFeatureTile(
              icon: Icons.location_on_outlined,
              title: "See General Location of Peeks",
              // status: "Optional Toggle",
            ),
            _buildFeatureTile(
              icon: Icons.visibility_outlined,
              title: "See Who Peeked You",
              // status: "Optional Toggle",
            ),
            _buildFeatureTile(
              icon: Icons.bar_chart,
              title: "Peeks Stats",
              // status: "Optional Toggle",
            ),
            const Divider(height: 24, color: Colors.white24),
            _buildFeatureTile(
              icon: Icons.chat_outlined,
              title: "Temporary Anonymous Chat",
              status: "Coming Soon",
              isAvailable: false,
            ),

            // --- End Feature List ---
            // const Spacer(),
            const SizedBox(height: 24),

            // --- Error Display ---
            if (subState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  subState.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),

            // --- Price Display ---
            Center(
              child: Text(
                priceString, // Shows '...' or actual price
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: product != null
                          ? Colors.deepPurpleAccent
                          : Colors.grey, // Adjust color
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                "Subscription auto-renews. Cancel anytime.", // Clearer text
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),

            // --- Action Button ---
            ElevatedButton.icon(
              onPressed: (isAlreadyPremium || isLoading || product == null)
                  ? null // Disable if premium, loading, or product not ready
                  : () {
                      // Trigger purchase flow via the new controller
                      ref
                          .read(subscriptionControllerProvider.notifier)
                          .initiatePurchase();
                    },
              icon: isLoading
                  ? Container(
                      /* ... loading indicator ... */
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.workspace_premium_outlined),
              label: Text(
                isLoading
                    ? 'Processing...'
                    : (isAlreadyPremium ? 'Currently Premium' : 'Upgrade Now'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade800,
                disabledForegroundColor: Colors.grey.shade500,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 4,
              ),
            ),
            const SizedBox(height: 16), // Bottom padding

            // --- MANAGE SUBSCRIPTION LINK ---
            if (isAlreadyPremium) ...[
              Center(
                child: TextButton(
                  onPressed: () {
                    final Uri manageSubscriptionUrl = Uri.parse(
                        'https://apps.apple.com/account/subscriptions');
                    _launchUrl(manageSubscriptionUrl, context);
                  },
                  child: Text(
                    "Manage Subscription",
                    style: TextStyle(
                      color: Colors.grey[400],
                      decoration: TextDecoration.underline,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8), // Optional padding below the link
            ],
            // --- END MANAGE SUBSCRIPTION LINK ---
          ],
        ),
      )),
    );
  }
}
