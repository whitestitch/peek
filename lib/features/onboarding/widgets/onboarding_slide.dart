// lib/features/onboarding/widgets/onboarding_slide.dart
import 'package:flutter/material.dart' as material;
import 'package:peek/theme/colors.dart';
import 'package:rive/rive.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OnboardingSlide extends material.StatelessWidget {
  final String logoAsset;
  final String imageAsset;
  final String title;
  final String subtitle;
  final String? textParagraph;
  final bool isHeroImageFullWidth;
  final bool showTextContent;

  const OnboardingSlide(
      {super.key,
      required this.logoAsset,
      required this.imageAsset, // Path to static hero or slide 2 background
      required this.title,
      required this.subtitle,
      this.textParagraph,
      required this.isHeroImageFullWidth,
      this.showTextContent = true});

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
        width: placeholderWidth,
        height: placeholderHeight,
        constraints: isFullWidth
            ? null
            : material.BoxConstraints(maxWidth: screenWidth * 0.8),
        color: isOverlay
            ? material.Colors.red.withOpacity(0.1)
            : material.Colors.grey.shade900.withOpacity(0.5),
        child: material.Center(
            child: material.Icon(material.Icons.error_outline,
                color: isOverlay
                    ? material.Colors.red.withOpacity(0.6)
                    : peekErrorColor,
                size: isOverlay ? 25 : 40)));
  }

  @override
  material.Widget build(material.BuildContext context) {
    final textTheme = material.Theme.of(context).textTheme;
    final screenWidth = material.MediaQuery.of(context).size.width;
    final screenHeight = material.MediaQuery.of(context).size.height;

    final bool showRiveAnimation = imageAsset.toLowerCase().endsWith('.riv');
    final double finalBottomSpace = isHeroImageFullWidth ? 35.0 : 35.0; // Less

    material.Widget logoWidget;
    if (logoAsset.toLowerCase().endsWith('.svg')) {
      logoWidget = SvgPicture.asset(
        logoAsset,
        height: 30, // Match existing Image.asset height
        // width: 100, // Optional: specify width if needed
        colorFilter: const material.ColorFilter.mode(
            // Apply color if your SVG is single-color and needs theming
            peekWhiteColor, // Or any color you want the SVG to be
            material.BlendMode.srcIn),
        placeholderBuilder: (material.BuildContext context) =>
            const material.SizedBox(
                width: 30,
                height: 30,
                child: material.CircularProgressIndicator(
                  strokeWidth: 2.0,
                  color: peekWhiteColor,
                )),
      );
    } else {
      logoWidget = material.Image.asset(
        logoAsset,
        height: 30,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          material.debugPrint("Error loading logo asset ($logoAsset): $error");
          return const material.Icon(material.Icons.broken_image,
              size: 30,
              color: peekWhiteColor); // Fallback for raster image errors
        },
      );
    }

    return material.SingleChildScrollView(
      physics: const material.BouncingScrollPhysics(),
      child: material.Column(
        crossAxisAlignment:
            material.CrossAxisAlignment.center, // Center horizontally
        children: [
          // 1. Logo Row (Forced Left)
          material.Align(
            alignment: material.Alignment.centerLeft,
            child: material.Padding(
              padding: const material.EdgeInsets.only(
                  left: 35.0, top: 35.0), // Indent left
              child: material.Row(
                mainAxisSize: material.MainAxisSize.min,
                crossAxisAlignment: material.CrossAxisAlignment.center,
                children: [
                  logoWidget,
                  // material.Image.asset(
                  //   logoAsset,
                  //     height: 30, gaplessPlayback: true),
                  const material.SizedBox(
                    width: 12,
                    height: 12,
                  ),
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
          // material.SizedBox(height: spaceBelowImage),

          // 2. Hero Image (Conditional Layout)
          material.Padding(
            // Apply horizontal padding only for slide 3 (constrained hero)
            padding: material.EdgeInsets.only(
              left: (!isHeroImageFullWidth && !showRiveAnimation) ? 35.0 : 0,
              right: (!isHeroImageFullWidth && !showRiveAnimation) ? 35.0 : 0,
              bottom: isHeroImageFullWidth ? 20.0 : 0,
            ),

            child: material.SizedBox(
              // Use SizedBox to constrain the height consistently
              height: showRiveAnimation || !isHeroImageFullWidth
                  ? screenHeight * 0.50
                  : null,
              width: screenWidth, // Allow full width
              child: showRiveAnimation
                  ? // If Slide 2, show Rive Animation
                  RiveAnimation.asset(
                      // 'assets/animations/button_underline_effect.riv',
                      // animations: const ['button_peek_effect'],
                      'assets/animations/onboarding_pulse_eye.riv',
                      stateMachines: const ['State Machine 1'],
                      // animations: const ['button_underline_effect'],
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
                      // height: spaceBelowCentralImage,
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

          // material.SizedBox(height: spaceBelowImage),
          // material.SizedBox(height: spaceBelowCentralImage),

          // 3. Text Content Area (Centered)
          if (showTextContent)
            material.Padding(
              padding: const material.EdgeInsets.only(
                  top: 30.0, left: 35.0, right: 35.0),
              child: material.Column(
                mainAxisSize: material.MainAxisSize.min,
                crossAxisAlignment: material.CrossAxisAlignment.center,
                children: [
                  material.Text(
                    title,
                    textAlign: material.TextAlign.center,
                    // Restore style from your code
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: material.FontWeight.w600,
                      color: peekWhiteColor,
                      letterSpacing: 0.5,
                      fontSize: 36,
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
                      fontSize: 18,
                    ),
                  ),
                  if (textParagraph != null) ...[
                    const material.SizedBox(height: 25),
                    material.Text(
                      textParagraph!,
                      textAlign: material.TextAlign.center,
                      // Restore style from your code
                      style: textTheme.bodyMedium?.copyWith(
                        color: peekWhiteColor.withOpacity(1),
                        height: 1.55,
                        fontSize: 16,
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
          material.SizedBox(height: finalBottomSpace),
        ],
      ),
    );
  }
}
