// lib/features/onboarding/pages/onboarding_page.dart
// import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/features/onboarding/providers/onboarding_provider.dart';
import 'package:peek/features/onboarding/widgets/onboarding_slide.dart';
import 'package:peek/theme/colors.dart';

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
      'logo': 'assets/images/peekio_logo.svg',
      'image': 'assets/images/onboarding_01.png',
      'isHeroFullWidth': true,
      'title': 'View the world as another does.',
      'subtitle': 'Instant, real, anonymous.',
      'text': null, // No text paragraph on slide 1
      'background': 'assets/images/onboarding_bg_01.jpg',
    },
    {
      'logo': 'assets/images/peekio_logo.svg',
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
      'logo': 'assets/images/peekio_logo.svg',
      'image': 'assets/images/onboarding_03.png',
      'isHeroFullWidth': false,
      'title': 'Think Fast:\n10 Sec!',
      'subtitle': 'Ready, Set, Peek',
      'text':
          'You have 10 seconds to capture your moment. Share your world instantly.',
      // 'Peek is fully anonymous and safe.\nYour camera, your world — shared\nin the moment only.',
      'background': 'assets/images/onboarding_bg_03.jpg',
    },
    {
      'logo': 'assets/images/peekio_logo.svg',
      'image': 'assets/images/onboarding_04.png',
      'isHeroFullWidth': false,
      'title': '100% Private',
      'subtitle': 'No Data Saved.',
      'text':
          'Peek is fully anonymous and safe.\nYour camera, your world — shared\nin the moment only.',
      'background': 'assets/images/onboarding_bg_04.jpg',
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
    // The Stack remains the root to allow the background to go edge-to-edge.
    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: Animated Background Image (fills the whole screen)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Image.asset(
            key: ValueKey<String>(slides[_currentPage]['background']!),
            slides[_currentPage]['background']!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint(
                  "❌ Error loading background image: ${slides[_currentPage]['background']}\nError: $error");
              return Container(color: peekBackgroundColor); // Fallback
            },
          ),
        ),

        // Layer 2: A transparent Scaffold to hold the re-ordered UI content.
        Scaffold(
          backgroundColor: Colors.transparent, // CRUCIAL
          body: SafeArea(
            child: Column(
              children: [
                // Section 1: PageView for Logo & Image, taking up available space
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: slides.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) {
                      final slide = slides[index];
                      final bool isFullWidthLayout =
                          slide['isHeroFullWidth'] as bool? ?? false;

                      // This OnboardingSlide now only renders the top part (logo/image)
                      return OnboardingSlide(
                        key: ValueKey('slide_image_$index'),
                        logoAsset: slide['logo']! as String,
                        imageAsset: slide['image']! as String,
                        title: '', // Not used, text is rendered below
                        subtitle: '', // Not used
                        isHeroImageFullWidth: isFullWidthLayout,
                        showTextContent: false, // This ensures text is hidden
                      );
                    },
                  ),
                ),

                // Section 3: Textual Content for the current page
                _buildTextualContent(),
                const SizedBox(height: 30),

                // Section 2: Navigation Controls
                _buildNavigationControls(),
                const SizedBox(height: 0), // Spacing after controls
              ],
            ),
          ),
        ),
      ],
    );
  }

  // NEW: Builds the text content area that animates with page changes
  Widget _buildTextualContent() {
    final slideData = slides[_currentPage];
    final textTheme = Theme.of(context).textTheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        // Fade and slide transition for a smooth appearance
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.2),
              end: Offset.zero,
            ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        );
      },
      child: Padding(
        // A Key is crucial for AnimatedSwitcher to detect content change
        key: ValueKey<int>(_currentPage),
        padding: const EdgeInsets.symmetric(horizontal: 35.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Takes up only needed space
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              slideData['title']!,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: peekWhiteColor,
                letterSpacing: 0.5,
                fontSize: 36,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              slideData['subtitle']!,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: peekOnBackgroundColor.withOpacity(0.85),
                fontSize: 18,
              ),
            ),
            if (slideData['text'] != null) ...[
              const SizedBox(height: 25),
              Text(
                slideData['text']!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: peekWhiteColor.withOpacity(1),
                  height: 1.55,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
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
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
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
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(isLastSlide ? 'Done' : 'Next'),
          ),
        ],
      ),
    );
  }
}
