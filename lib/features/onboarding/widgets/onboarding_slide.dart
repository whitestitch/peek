// lib/features/onboarding/widgets/onboarding_slide.dart
import 'package:flutter/material.dart' as material;
import 'package:peek/theme/colors.dart';
// import 'dart:math' as math;
// import 'pulse_transition.dart';
import 'package:rive/rive.dart';

class OnboardingSlide extends material.StatelessWidget {
  final String logoAsset; // e.g., 'assets/logo/peek_logo_main.png'
  final String imageAsset; // e.g., 'assets/images/onboarding_slide1.png'
  final String title;
  final String subtitle;
  final String? textParagraph; // Nullable for slide 1
  final bool isHeroImageFullWidth;

  const OnboardingSlide(
      {super.key,
      required this.logoAsset,
      required this.imageAsset, // Path to static hero or slide 2 background
      required this.title,
      required this.subtitle,
      this.textParagraph,
      required this.isHeroImageFullWidth});

  // Helper for error placeholder
  material.Widget _errorPlaceholder(
      material.BuildContext context, bool isFullWidth,
      {bool isOverlay = false}) {
    final screenWidth = material.MediaQuery.of(context).size.width;
    final screenHeight = material.MediaQuery.of(context).size.height;
    final double placeholderHeight =
        isFullWidth ? screenWidth * (9 / 16) : screenHeight * 0.30;
    final double? placeholderWidth = isFullWidth ? screenWidth : null;

    return material.Container(
        // <<< Use prefix
        width: placeholderWidth,
        height: placeholderHeight,
        constraints: isFullWidth
            ? null
            : material.BoxConstraints(
                maxWidth: screenWidth * 0.8), // <<< Use prefix
        color: isOverlay
            ? material.Colors.red.withOpacity(0.1)
            : material.Colors.grey.shade900.withOpacity(0.5),
        child: material.Center(
            // <<< Use prefix
            child: material.Icon(material.Icons.error_outline, // <<< Use prefix
                color: isOverlay
                    ? material.Colors.red.withOpacity(0.6)
                    : material.Colors.redAccent,
                size: isOverlay ? 25 : 40)));
  }

  @override
  material.Widget build(material.BuildContext context) {
    final textTheme = material.Theme.of(context).textTheme;
    final screenWidth = material.MediaQuery.of(context).size.width;
    final screenHeight = material.MediaQuery.of(context).size.height;

    final bool showRiveAnimation = imageAsset.toLowerCase().endsWith('.riv');

    // Define CONSISTENT spacing values - vertical layout managed by Spacer/structure now
    const double topPadding = 40.0;
    const double spaceBelowLogo = 0;
    const double spaceBelowImageStack = 0; // More space before text
    const double finalBottomPadding = 50.0;

    return material.SingleChildScrollView(
      physics: const material.BouncingScrollPhysics(),
      padding: const material.EdgeInsets.only(
          top: topPadding,
          bottom: finalBottomPadding), // Apply vertical padding here
      child: material.Column(
        crossAxisAlignment:
            material.CrossAxisAlignment.center, // Center horizontally
        children: [
          // 1. Logo Row (Forced Left)
          material.Align(
            alignment: material.Alignment.centerLeft,
            child: material.Padding(
              padding:
                  const material.EdgeInsets.only(left: 35.0), // Indent left
              child: material.Row(
                mainAxisSize: material.MainAxisSize.min,
                crossAxisAlignment: material.CrossAxisAlignment.center,
                children: [
                  material.Image.asset(logoAsset,
                      height: 30, gaplessPlayback: true),
                  const material.SizedBox(width: 10),
                  material.Text(
                    "Peekio",
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: material.FontWeight.w600,
                      color: peekWhiteColor,
                      fontSize: 32, // Restored size
                    ),
                  ),
                  // SizedBox(height: spaceBelowLogo),
                ],
              ),
            ),
          ),
          // Fixed spacing below logo
          const material.SizedBox(height: spaceBelowLogo),

          // 2. Hero Image (Conditional Layout)
          material.Padding(
            // Apply horizontal padding only for slide 3 (constrained hero)
            padding: material.EdgeInsets.symmetric(
                horizontal:
                    (!isHeroImageFullWidth && !showRiveAnimation) ? 35.0 : 0),
            child: material.SizedBox(
              // Use SizedBox to constrain the height consistently
              height:
                  screenHeight * 0.40, // Define height for image/animation area
              width: screenWidth, // Allow full width
              child: showRiveAnimation
                  ? // If Slide 2, show Rive Animation
                  RiveAnimation.asset(
                      'assets/animations/onboarding_pulse_eye.riv', // <<< PATH TO YOUR RIVE FILE
                      // Specify the animation or state machine name from your Rive file
                      animations: const ['PulseLoop'],
                      // or stateMachines: const ['State Machine 1'], // <<< YOUR STATE MACHINE NAME
                      fit: material.BoxFit.contain, // Fit animation
                      // Optional: Add controllers, handle errors
                      onInit: (artboard) {
                        // You can get controllers here if needed
                      },
                      placeHolder: const material.Center(
                          child: material
                              .CircularProgressIndicator()), // Placeholder while loading
                    )
                  : // If Slide 1 or 3, show static Image
                  material.Image.asset(
                      imageAsset, // Hero image path
                      // Width/Height/Fit handled by outer SizedBox/Padding
                      fit: isHeroImageFullWidth
                          ? material.BoxFit.fitWidth
                          : material.BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          _errorPlaceholder(context, isHeroImageFullWidth),
                    ),
            ),
          ),
          // Fixed spacing below image
          const material.SizedBox(height: spaceBelowImageStack),

          // 3. Text Content Area (Centered)
          material.Padding(
            padding: const material.EdgeInsets.symmetric(
                horizontal: 35.0), // Keep horizontal padding
            child: material.Column(
              mainAxisSize: material.MainAxisSize.min,
              crossAxisAlignment: material.CrossAxisAlignment.center,
              children: [
                material.Text(
                  title,
                  textAlign: material.TextAlign.center,
                  // Restore style from your code
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: material.FontWeight.w700,
                    color: peekWhiteColor,
                    letterSpacing: 0.5,
                    fontSize: 34,
                  ),
                ),
                const material.SizedBox(height: 15),
                material.Text(
                  subtitle,
                  textAlign: material.TextAlign.center,
                  // Restore style from your code
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: material.FontWeight.w500,
                    color: peekOnBackgroundColor.withOpacity(0.85),
                  ),
                ),
                if (textParagraph != null) ...[
                  const material.SizedBox(height: 25),
                  material.Text(
                    textParagraph!,
                    textAlign: material.TextAlign.center,
                    // Restore style from your code
                    style: textTheme.bodyMedium?.copyWith(
                      color: peekOnBackgroundColor.withOpacity(0.75),
                      height: 1.5,
                      fontWeight: material.FontWeight.w400,
                    ),
                  ),
                  // const Spacer(),
                  // SizedBox(height: finalBottomSpace),
                ],
              ],
            ),
          ),
          // Bottom spacing handled by SingleChildScrollView padding
        ],
      ),
    );
  }
}
