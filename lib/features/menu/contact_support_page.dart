import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
                color: peekPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: peekPrimaryColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
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
                  onTap: () => _launchEmail(
                      'technical-support@peekio.app', 'Technical Issue Report'),
                ),
                _buildActionTile(
                  context,
                  title: 'Report User Behavior',
                  subtitle: 'Report abusive or inappropriate user behavior',
                  icon: Icons.person_off,
                  onTap: () =>
                      _launchEmail('safety@peekio.app', 'User Behavior Report'),
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
                      'support@peekio.app', 'Peekio Support Request'),
                ),
                _buildActionTile(
                  context,
                  title: 'Emergency Safety Issues',
                  subtitle: 'For urgent safety concerns (immediate response)',
                  icon: Icons.emergency,
                  onTap: () =>
                      _launchEmail('safety@peekio.app', 'URGENT: Safety Issue'),
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
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue),
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
            style: TextStyle(color: peekOnSurfaceColor.withOpacity(0.7))),
        trailing: Icon(Icons.arrow_forward_ios,
            color: peekOnSurfaceColor.withOpacity(0.5)),
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
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your privacy is important to us.'),
            SizedBox(height: 8),
            Text('• We collect minimal data needed for app functionality'),
            Text('• Photos are stored temporarily and deleted after use'),
            Text('• We never share your personal information'),
            Text('• You can request data deletion at any time'),
            SizedBox(height: 16),
            Text('Full privacy policy available at peekio.app/privacy'),
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

  Future<void> _launchEmail(String email, String subject) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(subject)}',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      // Fallback: copy email to clipboard
      // You can implement clipboard functionality here
    }
  }
}
