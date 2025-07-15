// lib/features/menu/about_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/theme/colors.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Widget _buildFeatureText(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: peekOnBackgroundColor.withOpacity(0.9),
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: peekBackgroundColor, // Use your theme's background color
      appBar: AppBar(
        title: const Text('About Peekio'), // Updated to Peekio
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new), // Consistent back icon
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/'); // Fallback if cannot pop
            }
          },
        ),
        // backgroundColor: peekSurfaceColor, // Optional: if you want a distinct AppBar color
        // elevation: 1,
      ),
      body: SingleChildScrollView(
        // Make content scrollable
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // SvgPicture.asset('assets/images/peekio_logo.svg',
            //     fit: BoxFit.contain,
            //     errorBuilder: (context, error, stackTrace) {
            //   // debugPrint("Error loading settings logo: $logoPath - $error");
            //   return const Icon(Icons.error_outline,
            //       size: 40, color: Colors.redAccent);
            // }),
            Align(
              alignment: Alignment.centerLeft,
              child: SvgPicture.asset(
                'assets/images/peekio_logo.svg',
                height: 50,
                // ignore: deprecated_member_use
                color: peekWhiteColor,
                fit: BoxFit.cover,
                //     errorBuilder: (context, error, stackTrace) {
                //   return const Icon(Icons.error_outline,
                //       size: 40, color: Colors.redAccent);
                // }
              ),
            ),

            const SizedBox(height: 16),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Welcome to Peekio!",
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: peekPrimaryColor,
                  fontSize: 22,
                ),
                // textAlign is not strictly needed if Align is used for the block,
                // but can be kept if you want to ensure text itself aligns left within its bounds.
                // textAlign: TextAlign.left,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Ever wondered what someone else is seeing, right now, anywhere in the world? Peekio makes it possible.",
              style: textTheme.titleMedium?.copyWith(
                color: peekOnBackgroundColor.withOpacity(0.9),
                height: 1.4,
              ),
              // textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              "What is Peekio?",
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: peekOnBackgroundColor,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Peekio is a unique social experience built on spontaneity and anonymity. It's a window into real moments, shared instantly and fleetingly. No profiles, no history, just a glimpse.",
              style: textTheme.bodyLarge?.copyWith(
                  color: peekOnBackgroundColor.withOpacity(0.9), height: 1.5),
              // textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 24),
            Text(
              "How It Works:",
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: peekOnBackgroundColor,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 12),
            _buildFeatureText(
              context,
              Icons.ads_click_rounded, // Icon for tap/request
              "Tap 'Peek' to send out a request into the void.",
            ),
            _buildFeatureText(
              context,
              Icons.camera_alt_outlined,
              "Someone, somewhere, receives your request and can choose to share a 5-second photo of their current view.",
            ),
            _buildFeatureText(
              context,
              Icons.remove_red_eye_outlined,
              "You get to see their world, unfiltered and in real-time.",
            ),
            _buildFeatureText(
              context,
              Icons.timer_off_outlined,
              "After a few seconds, the image disappears. No strings, no storage.",
            ),
            const SizedBox(height: 24),
            Text(
              "Our Philosophy:",
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: peekOnBackgroundColor,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 12),
            _buildFeatureText(
              context,
              Icons.security_rounded,
              "Privacy First: Your interactions are designed to be anonymous. We don't ask for your name or build detailed profiles.",
            ),
            _buildFeatureText(
              context,
              Icons.delete_sweep_rounded,
              "Ephemeral by Design: Peeks are fleeting moments, not permanent records. Images are deleted after viewing.",
            ),
            _buildFeatureText(
              context,
              Icons.public_rounded,
              "Global & Spontaneous: Connect with random moments from across the globe.",
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                "Made with ❤️ by White Stitch", // Replace placeholder
                style: textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                "Version 1.0.0+12", // Replace with your actual app version or make dynamic
                style:
                    textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
