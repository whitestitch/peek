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
import 'package:geolocator/geolocator.dart';
import 'package:peek/core/firestore_service.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isRequestingPermission = false;

  final List<Map<String, dynamic>> _allSlides = [
    {
      'logo': 'assets/images/peekio_logo.svg',
      'image': 'assets/images/onboarding_01.png',
      'isHeroFullWidth': true,
      'title': 'View the world as another does.',
      'subtitle': 'Instant, real, anonymous.',
      'text': null,
      'background': 'assets/images/onboarding_bg_01.jpg',
    },
    {
      'logo': 'assets/images/peekio_logo.svg',
      'image': 'assets/animations/onboarding_pulse_eye.riv',
      'isHeroFullWidth': false,
      'title': 'Just tap Peek',
      'subtitle': 'No names. No profiles.',
      'text':
          'We ping someone, they snap a photo. You see their world for 5 seconds.\nNo profiles. Just pure reality.',
      'background': 'assets/images/onboarding_bg_02.jpg',
    },
    {
      'logo': 'assets/images/peekio_logo.svg',
      'image': 'assets/images/onboarding_03.png',
      'isHeroFullWidth': false,
      'title': 'Think Fast: 30 Sec!',
      'subtitle': 'Ready, Set, Peek',
      'text':
          'You have 30 seconds to capture your moment. Share your world instantly.',
      'background': 'assets/images/onboarding_bg_03.jpg',
    },
    {
      'logo': 'assets/images/peekio_logo.svg',
      'image': 'assets/images/onboarding_05.png',
      'isHeroFullWidth': false,
      'title': '100% Private',
      'subtitle': 'No Data Saved.',
      'text':
          'Peek is fully anonymous and safe. RYour camera, your world — shared\nin the moment only.',
      'background': 'assets/images/onboarding_bg_04.jpg',
    },
    {
      'logo': 'assets/images/peekio_logo.svg',
      'image': 'assets/images/onboarding_04.png',
      'isHeroFullWidth': false,
      'title': 'Enable Location',
      'subtitle': 'See where Peekios come from',
      'text': "Enable location to see the city of the Peekios you receive.",
      'background': 'assets/images/onboarding_bg_02.jpg',
      'isLocationSlide': true,
    },
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

  Future<void> _handleLocationPermissionRequest() async {
    if (_isRequestingPermission || !mounted) return;
    setState(() => _isRequestingPermission = true);

    try {
      final permission = await Geolocator.requestPermission();
      bool locationEnabled = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      debugPrint(
          "[Onboarding] Permission status: $permission. Setting preference to: $locationEnabled");
      if (mounted) {
        await ref
            .read(firestoreServiceProvider)
            .updateUserLocationPreference(locationEnabled);
      }
    } catch (e) {
      debugPrint("❌ Error handling location permission: $e");
    } finally {
      if (mounted) {
        setState(() => _isRequestingPermission = false);
        _finishOnboarding();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userDocAsync = ref.watch(userDocumentProvider);

    return userDocAsync.when(
      loading: () => const Scaffold(
        backgroundColor: peekBackgroundColor,
        body: const Center(child: PeekLoadingIndicator.medium()),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: peekBackgroundColor,
        body: Center(child: Text('Error: $err')),
      ),
      data: (userDoc) {
        final locationPrefEnabled =
            userDoc?.data()?['shareLocationPreference'] as bool? ?? false;

        final filteredSlides = _allSlides.where((slide) {
          if (slide['isLocationSlide'] == true) {
            return !locationPrefEnabled;
          }
          return true;
        }).toList();

        if (filteredSlides.isEmpty) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _finishOnboarding());
          return const Scaffold(
              backgroundColor: peekBackgroundColor,
              body: Center(child: Text("Onboarding complete.")));
        }

        if (_currentPage >= filteredSlides.length) {
          _currentPage = filteredSlides.length - 1;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Image.asset(
                key: ValueKey<String>(
                    filteredSlides[_currentPage]['background']!),
                filteredSlides[_currentPage]['background']!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(color: peekBackgroundColor);
                },
              ),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              bottomNavigationBar:
                  filteredSlides[_currentPage]['isLocationSlide'] == true
                      ? _buildLocationPermissionControls()
                      : _buildNavigationControls(filteredSlides),
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: filteredSlides.length,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) {
                          final slide = filteredSlides[index];
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
                    _buildTextualContent(filteredSlides),

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
        padding: const EdgeInsets.symmetric(horizontal: 35.0, vertical: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              slideData['title']!,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: peekWhiteColor,
                letterSpacing: 0.5,
                fontSize: 34,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              slideData['subtitle']!,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: peekOnBackgroundColor.withValues(alpha: 0.85),
                fontSize: 22,
              ),
            ),
            if (slideData['text'] != null) ...[
              const SizedBox(height: 20),
              Text(
                slideData['text']!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: peekWhiteColor.withValues(alpha: 1),
                  height: 1.55,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPermissionControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: _isRequestingPermission
                ? null
                : _handleLocationPermissionRequest,
            child: _isRequestingPermission
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: PeekLoadingIndicator.small(
                      logoColor: peekSurfaceColor,
                    ),
                  )
                : const Text('Enable Location'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isRequestingPermission ? null : _finishOnboarding,
            // Style
            style: TextButton.styleFrom(
              foregroundColor: peekOnBackgroundColor.withValues(alpha: 0.7),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Maybe Later'),
            // color: peekOnBackgroundColor,
          ),
        ],
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
