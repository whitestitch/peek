// lib/features/onboarding/pages/onboarding_page.dart
// import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/core/providers.dart';
import 'package:peek/features/onboarding/providers/onboarding_provider.dart';
import 'package:peek/features/onboarding/widgets/onboarding_slide.dart';
import 'package:peek/theme/colors.dart';
import 'package:peek/core/widgets/peek_loading_indicator.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _allSlides = [
    {
      'logo': 'assets/images/peekio_logo.svg',
      'image': 'assets/images/onboarding_01.png',
      'isHeroFullWidth': true,
      'title': 'See What They See.',
      'subtitle': 'Instant, real, anonymous.',
      'text': 'Step into another moment. A raw view, through different eyes.',
      'background': 'assets/images/onboarding_bg_01.jpg',
    },
    {
      'logo': 'assets/images/peekio_logo.svg',
      'image': 'assets/animations/onboarding_pulse_eye.riv',
      'isHeroFullWidth': false,
      'title': 'Just Tap Peekio',
      'subtitle': 'No names. No profiles.',
      'text': 'Ping someone. They snap a photo. See their world — 5 seconds.',
      'background': 'assets/images/onboarding_bg_02.jpg',
    },
    {
      'logo': 'assets/images/peekio_logo.svg',
      'image': 'assets/images/onboarding_03.png',
      'isHeroFullWidth': false,
      'title': 'One Shot. 30s.',
      'subtitle': 'Capture fast. Share raw.',
      'text':
          'You’ve got 30 seconds to snap your reality. One glimpse, then it’s gone.',
      'background': 'assets/images/onboarding_bg_03.jpg',
    },
    {
      'logo': 'assets/images/peekio_logo.svg',
      'image': 'assets/images/onboarding_05.png',
      'isHeroFullWidth': false,
      'title': '100% Private',
      'subtitle': 'No data. No trace.',
      'text':
          'Peek is anonymous, safe. Your world is shared once — then it’s gone forever.',
      'background': 'assets/images/onboarding_bg_04.jpg',
    },
    // ✅ REMOVED: Location permission slide moved to just-in-time request
    // This improves UX and increases permission grant rates by providing
    // context right when the feature is needed, following Apple's best practices
    // and patterns used by top apps like Instagram, Uber, and Airbnb.
    //
    // Location permission will now be requested:
    // - When user sends their first Peek (if feature is enabled)
    // - With a clear explanation modal before the system dialog
    // - Users can still decline via the iOS system permission dialog
  ];

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
    _finishOnboarding();
  }

  void _nextPage(List<Map<String, dynamic>> slides) {
    if (_currentPage < slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _finishOnboarding() {
    ref.read(onboardingNotifierProvider.notifier).completeOnboarding();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final userDocAsync = ref.watch(userDocumentProvider);

    return userDocAsync.when(
      loading: () => const Scaffold(
        backgroundColor: peekBackgroundColor,
        body: Center(child: PeekLoadingIndicator.medium()),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: peekBackgroundColor,
        body: Center(child: Text('Error: $err')),
      ),
      data: (userDoc) {
        // ✅ Simplified: No need to filter slides anymore
        final slides = _allSlides;

        if (_currentPage >= slides.length) {
          _currentPage = slides.length - 1;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Image.asset(
                key: ValueKey<String>(slides[_currentPage]['background']!),
                slides[_currentPage]['background']!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(color: peekBackgroundColor);
                },
              ),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              bottomNavigationBar: _buildNavigationControls(slides),
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: slides.length,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) {
                          final slide = slides[index];
                          final isFullWidthLayout =
                              slide['isHeroFullWidth'] as bool? ?? false;
                          return OnboardingSlide(
                            key: ValueKey('slide_image_$index'),
                            logoAsset: slide['logo']! as String,
                            imageAsset: slide['image']! as String,
                            title: '',
                            subtitle: '',
                            isHeroImageFullWidth: isFullWidthLayout,
                            showTextContent: false,
                          );
                        },
                      ),
                    ),
                    _buildTextualContent(slides),

                    // Add a SizedBox to create space above the bottom navigation bar.
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextualContent(List<Map<String, dynamic>> slides) {
    final slideData = slides[_currentPage];
    final textTheme = Theme.of(context).textTheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
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
        key: ValueKey<int>(_currentPage),
        padding: EdgeInsets.symmetric(
          horizontal: 32.0,
          // 🔒 FIX: Reduce top padding for first slide to improve text positioning
          vertical: _currentPage == 0 ? 20.0 : 24.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              slideData['title']!,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: peekWhiteColor,
                letterSpacing: 0.3,
                fontSize: MediaQuery.of(context).size.width < 400 ? 30 : 34,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              slideData['subtitle']!,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: peekOnBackgroundColor.withValues(alpha: 0.9),
                fontSize: MediaQuery.of(context).size.width < 400 ? 16 : 18,
                letterSpacing: 0.2,
              ),
            ),
            if (slideData['text'] != null) ...[
              const SizedBox(height: 24),
              Text(
                slideData['text']!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: peekWhiteColor.withValues(alpha: 0.95),
                  height: 1.6,
                  fontSize: MediaQuery.of(context).size.width < 400 ? 15 : 17,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationControls(List<Map<String, dynamic>> slides) {
    bool isLastSlide = _currentPage == slides.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Opacity(
            opacity: !isLastSlide ? 1.0 : 0.0,
            child: TextButton(
              onPressed: !isLastSlide ? _skipOnboarding : null,
              style: TextButton.styleFrom(
                foregroundColor: peekOnBackgroundColor.withValues(alpha: 0.7),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Skip'),
            ),
          ),
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
          ElevatedButton(
            onPressed: () =>
                isLastSlide ? _finishOnboarding() : _nextPage(slides),
            child: Text(isLastSlide ? 'Done' : 'Next'),
          ),
        ],
      ),
    );
  }
}
