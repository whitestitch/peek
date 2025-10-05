import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:peek/theme/colors.dart';

/// Contact and Support page to meet App Store guidelines
/// Provides users with ways to report inappropriate activity and contact developer
class ContactSupportPage extends StatelessWidget {
  const ContactSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact & Support'),
        backgroundColor: peekSurfaceColor,
        foregroundColor: peekOnSurfaceColor,
      ),
      backgroundColor: peekSurfaceColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: peekPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: peekPrimaryColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.support_agent,
                    size: 48,
                    color: peekPrimaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Need Help?',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: peekPrimaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'re here to help you with any issues or concerns about the Peekio app.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: peekOnSurfaceColor,
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Report Issues Section
            _buildSection(
              context,
              title: 'Report Issues',
              icon: Icons.report_problem,
              color: Colors.orange,
              children: [
                _buildActionTile(
                  context,
                  title: 'Report Inappropriate Content',
                  subtitle:
                      'Report content that violates our community guidelines',
                  icon: Icons.flag,
                  onTap: () => _showReportGuidelines(context),
                ),
                _buildActionTile(
                  context,
                  title: 'Report Technical Issues',
                  subtitle: 'Report bugs or app problems',
                  icon: Icons.bug_report,
                  onTap: () => _launchEmail(context,
                      'technical-support@peekio.app', 'Technical Issue Report'),
                ),
                _buildActionTile(
                  context,
                  title: 'Report User Behavior',
                  subtitle: 'Report abusive or inappropriate user behavior',
                  icon: Icons.person_off,
                  onTap: () => _launchEmail(
                      context, 'safety@peekio.app', 'User Behavior Report'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Contact Methods Section
            _buildSection(
              context,
              title: 'Contact Methods',
              icon: Icons.contact_support,
              color: peekPrimaryColor,
              children: [
                _buildActionTile(
                  context,
                  title: 'Email Support',
                  subtitle: 'Get help via email (24-48 hour response)',
                  icon: Icons.email,
                  onTap: () => _launchEmail(
                      context, 'support@peekio.app', 'Peekio Support Request'),
                ),
                _buildActionTile(
                  context,
                  title: 'Emergency Safety Issues',
                  subtitle: 'For urgent safety concerns (immediate response)',
                  icon: Icons.emergency,
                  onTap: () => _launchEmail(
                      context, 'safety@peekio.app', 'URGENT: Safety Issue'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Community Guidelines Section
            _buildSection(
              context,
              title: 'Community Guidelines',
              icon: Icons.rule,
              color: Colors.green,
              children: [
                _buildActionTile(
                  context,
                  title: 'View Guidelines',
                  subtitle: 'Learn about our community standards',
                  icon: Icons.description,
                  onTap: () => _showCommunityGuidelines(context),
                ),
                _buildActionTile(
                  context,
                  title: 'Privacy Policy',
                  subtitle: 'Read our privacy and data handling policies',
                  icon: Icons.privacy_tip,
                  onTap: () => _showPrivacyPolicy(context),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Response Time Notice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'We respond to all reports within 24 hours as required by App Store guidelines.',
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: peekOnSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: peekPrimaryColor),
        title: Text(title, style: TextStyle(color: peekOnSurfaceColor)),
        subtitle: Text(subtitle,
            style: TextStyle(color: peekOnSurfaceColor.withValues(alpha: 0.7))),
        trailing: Icon(Icons.arrow_forward_ios,
            color: peekOnSurfaceColor.withValues(alpha: 0.5)),
        onTap: onTap,
      ),
    );
  }

  void _showReportGuidelines(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reporting Guidelines'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please report content that:'),
            SizedBox(height: 8),
            Text('• Contains explicit or inappropriate material'),
            Text('• Promotes violence or harm'),
            Text('• Harasses or bullies others'),
            Text('• Violates our community standards'),
            SizedBox(height: 16),
            Text('All reports are reviewed within 24 hours.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCommunityGuidelines(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Community Guidelines'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Our community is built on:'),
            SizedBox(height: 8),
            Text('• Respect for all users'),
            Text('• Appropriate content only'),
            Text('• No harassment or bullying'),
            Text('• No explicit material'),
            Text('• No impersonation'),
            SizedBox(height: 16),
            Text('Violations may result in account restrictions.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your privacy is important to us.'),
              const SizedBox(height: 8),
              const Text(
                  '• We collect minimal data needed for app functionality'),
              const Text(
                  '• Photos are stored temporarily and deleted after use'),
              const Text('• We never share your personal information'),
              const Text('• You can request data deletion at any time'),
              const SizedBox(height: 12),
              // 🔗 Clickable Privacy Policy URL (shorter text)
              GestureDetector(
                onTap: () => _launchWebUrl('https://peekio.app/privacy.html'),
                child: const Text(
                  'View full Privacy Policy',
                  style: TextStyle(
                    color: peekPrimaryColor,
                    // decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Launch web URL (for Privacy Policy, Terms, etc.)
  Future<void> _launchWebUrl(String url) async {
    final Uri uri = Uri.parse(url);

    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw 'Could not launch URL';
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Future<void> _launchEmail(
      BuildContext context, String email, String subject) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(subject)}',
    );

    try {
      // Try to launch the email client directly
      await launchUrl(emailUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // If email client can't be opened, show a fallback dialog with email info
      debugPrint('Could not open email client: $e');

      if (!context.mounted) return;

      // Show dialog so user can copy email address manually
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Email Client Not Available'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your device does not have an email app configured.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please email us at:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SelectableText(
                email,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: peekPrimaryColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Subject:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              SelectableText(
                subject,
                style: TextStyle(
                  color: peekOnSurfaceColor.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
