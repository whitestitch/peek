// lib/features/onboarding/pages/onboarding_page.dart
// import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/features/onboarding/providers/onboarding_provider.dart';
import 'package:peek/features/onboarding/widgets/onboarding_slide.dart';
import 'package:peek/theme/colors.dart'; // Import colors

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // --- Define path to your background image ---
  // static const String _backgroundImagePath = 'assets/images/slide-bg.jpg';

  // Define slide content here
  final List<Map<String, dynamic>> slides = [
    {
      'logo': 'assets/images/peekio.png',
      'image': 'assets/images/onboarding_01.png',
      'isHeroFullWidth': true,
      'title': 'View the world as another does.',
      'subtitle': 'Instant, real, anonymous.',
      'text': null, // No text paragraph on slide 1
      'background': 'assets/images/onboarding_bg_01.jpg',
    },
    {
      'logo': 'assets/images/peekio.png',
      // 'image': 'assets/images/onboarding_02.png',
      'image': 'assets/animations/onboarding_pulse_eye.riv',
      'isHeroFullWidth': false,
      'title': 'Just tap Peek',
      'subtitle': 'No names. No profiles.',
      'text':
          'We ping someone, they snap a photo.\nYou see their world for 5 seconds.\nNo profiles. Just pure reality.',
      'background': 'assets/images/onboarding_bg_02.jpg',
    },
    {
      'logo': 'assets/images/peekio.png',
      'image': 'assets/images/onboarding_03.png',
      'isHeroFullWidth': false,
      'title': '100% Private',
      'subtitle': 'No Date Saved.',
      'text':
          'Peek is fully anonymous and safe.\nYour camera, your world — shared\nin the moment only.',
      'background': 'assets/images/onboarding_bg_03.jpg',
    },
  ];

  @override
  void initState() {
    super.initState();
    if (_currentPage == 1) {
      // Check if starting on slide 2
    }
  }

  // @override
  // void initState() {
  //   super.initState(); /* ... Timer logic if needed later ... */
  // }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _skipOnboarding() {
    _completeAndNavigate();
  }

  void _nextPage() {
    if (_currentPage < slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _finishOnboarding() {
    _completeAndNavigate();
  }

  void _completeAndNavigate() {
    ref.read(onboardingNotifierProvider.notifier).completeOnboarding();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Keep fallback background color
      backgroundColor: peekBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: Animated Background Image
          AnimatedSwitcher(
            // Use AnimatedSwitcher to fade between backgrounds
            duration: const Duration(milliseconds: 500), // Fade duration
            child: Image.asset(
              // Use key to ensure switcher recognizes changes
              key: ValueKey<String>(slides[_currentPage]['background']!),
              // Get background path based on current page index
              slides[_currentPage]
                  ['background']!, // Assumes path is always present
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint(
                    "❌ Error loading background image: ${slides[_currentPage]['background']}\nError: $error");
                return Container(color: peekBackgroundColor); // Fallback
              },
            ),
          ),

          // Optional: Overlay Layer
          // Container(color: Colors.black.withOpacity(0.4)),

          // Layer 2: Content
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: slides.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) {
                      final slide = slides[index];
                      // Determine if hero image should be full width for this slide
                      final bool isFullWidthLayout =
                          slide['isHeroFullWidth'] as bool? ?? false;

                      return OnboardingSlide(
                        key: ValueKey('slide_$index'),
                        logoAsset: slide['logo']! as String,
                        imageAsset: slide['image']!
                            as String, // Pass base image/background path
                        title: slide['title']! as String,
                        subtitle: slide['subtitle']! as String,
                        textParagraph: slide['text'] as String?,
                        isHeroImageFullWidth:
                            isFullWidthLayout, // Keep this flag
                      );
                    },
                  ),
                ),
                _buildNavigationControls(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Builds the bottom navigation controls (Skip/Next/Done)
  Widget _buildNavigationControls() {
    bool isLastSlide = _currentPage == slides.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Skip Button
          Opacity(
            opacity: !isLastSlide ? 1.0 : 0.0,
            child: TextButton(
              onPressed: !isLastSlide ? _skipOnboarding : null,
              style: TextButton.styleFrom(
                foregroundColor: peekOnBackgroundColor.withOpacity(0.7),
              ),
              child: const Text('Skip'),
            ),
          ),
          // Indicator Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slides.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                height: 8.0,
                width: _currentPage == index ? 24.0 : 8.0,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? peekPrimaryColor
                      : Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(4.0),
                ),
              );
            }),
          ),
          // Next / Done Button
          ElevatedButton(
            onPressed: isLastSlide ? _finishOnboarding : _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: peekPrimaryColor,
              foregroundColor: peekSurfaceColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(isLastSlide ? 'Done' : 'Next'),
          ),
        ],
      ),
    );
  }
}
