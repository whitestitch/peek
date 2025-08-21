// lib/features/onboarding/terms_acceptance_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:url_launcher/url_launcher.dart';
import 'package:peek/services/terms_service.dart';
import 'package:peek/theme/colors.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TermsAcceptanceScreen extends ConsumerStatefulWidget {
  const TermsAcceptanceScreen({super.key});

  @override
  ConsumerState<TermsAcceptanceScreen> createState() =>
      _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends ConsumerState<TermsAcceptanceScreen> {
  bool _termsAccepted = false;
  bool _isProcessing = false;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🎯 [TermsScreen] initState called');
  }

  Future<void> _handleAcceptTerms() async {
    if (!_termsAccepted || _isProcessing) {
      setState(() {
        _showError = true;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _showError = false;
    });

    try {
      debugPrint('[TermsScreen] Starting terms acceptance process...');

      // Step 2: Accept the terms
      await TermsService.acceptTerms();
      debugPrint('[TermsScreen] ✅ Terms accepted and saved');

      // Add a small delay to ensure SharedPreferences is written
      await Future.delayed(const Duration(milliseconds: 100));

      // Step 3: Navigate to onboarding - Reset state BEFORE navigation
      if (mounted) {
        setState(() {
          _isProcessing = false; // Reset here to stop spinner
        });
        debugPrint('[TermsScreen] Navigating to /onboarding...');
        context.go('/onboarding');
        debugPrint('[TermsScreen] ✅ Navigation called');
      }
    } catch (e) {
      debugPrint('[TermsScreen] ❌ Error accepting terms: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🎯 [TermsScreen] build() called');
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: peekBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    peekBackgroundColor,
                    peekBackgroundColor.withOpacity(0.95),
                    peekSurfaceColor.withOpacity(0.3),
                  ],
                ),
              ),
            ),

            SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.08,
                vertical: screenHeight * 0.02,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: screenHeight * 0.05),

                  // Logo
                  SvgPicture.asset(
                    'assets/images/peekio_eye.svg',
                    width: 80,
                    height: 80,
                    colorFilter: const ColorFilter.mode(
                      peekPrimaryColor,
                      BlendMode.srcIn,
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.03),

                  // Title
                  Text(
                    'Welcome to Peek',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: peekOnBackgroundColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),

                  SizedBox(height: screenHeight * 0.01),

                  // Subtitle
                  Text(
                    'User Agreement',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: peekOnBackgroundColor.withOpacity(0.7),
                        ),
                  ),

                  SizedBox(height: screenHeight * 0.04),

                  // Terms content
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: peekSurfaceColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: peekPrimaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Before you continue',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: peekOnSurfaceColor,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Peekio has a zero-tolerance policy for objectionable content or abusive users. '
                          'By continuing, you agree to our Terms of Service and Privacy Policy.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: peekOnSurfaceColor.withOpacity(0.9),
                                    height: 1.5,
                                  ),
                        ),
                        const SizedBox(height: 20),

                        // Links to terms and privacy
                        RichText(
                          text: TextSpan(
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: peekOnSurfaceColor.withOpacity(0.9),
                                ),
                            children: [
                              const TextSpan(text: 'Read our '),
                              TextSpan(
                                text: 'Terms of Service',
                                style: const TextStyle(
                                  color: peekSecondaryColor,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _launchURL(
                                      'https://peekio.app/terms.html'),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: const TextStyle(
                                  color: peekSecondaryColor,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _launchURL(
                                      'https://peekio.app/privacy.html'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.03),

                  // Checkbox
                  Container(
                    decoration: BoxDecoration(
                      color: peekSurfaceColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: _showError && !_termsAccepted
                          ? Border.all(color: peekErrorColor, width: 2)
                          : null,
                    ),
                    child: CheckboxListTile(
                      value: _termsAccepted,
                      onChanged: _isProcessing
                          ? null
                          : (value) {
                              setState(() {
                                _termsAccepted = value ?? false;
                                if (_termsAccepted) {
                                  _showError = false;
                                }
                              });
                            },
                      title: Text(
                        'I agree to the Terms of Service and Privacy Policy',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: peekOnSurfaceColor,
                              fontWeight: _termsAccepted
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: peekPrimaryColor,
                      checkColor: peekOnPrimaryColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),

                  if (_showError && !_termsAccepted)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Please accept the terms to continue',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: peekErrorColor,
                            ),
                      ),
                    ),

                  SizedBox(height: screenHeight * 0.04),

                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _handleAcceptTerms,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _termsAccepted ? peekPrimaryColor : Colors.grey,
                        foregroundColor: peekSurfaceColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: _termsAccepted ? 4 : 0,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: peekOnPrimaryColor,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Continue',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: peekOnPrimaryColor,
                                    fontSize: 16,
                                  ),
                            ),
                    ),
                  ),

                  if (kDebugMode) ...[
                    SizedBox(height: screenHeight * 0.02),
                    TextButton(
                      onPressed: _isProcessing
                          ? null
                          : () async {
                              setState(() => _isProcessing = true);
                              try {
                                //SPACE

                                //SPACE
                                await TermsService.acceptTerms();
                                if (mounted) {
                                  // context.go('/');
                                  context.go('/onboarding');
                                }
                              } catch (e) {
                                debugPrint('[DEBUG] Skip error: $e');
                              } finally {
                                if (mounted) {
                                  setState(() => _isProcessing = false);
                                }
                              }
                            },
                      child: const Text(
                        '[DEBUG] Skip Terms',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],

                  SizedBox(height: screenHeight * 0.03),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
