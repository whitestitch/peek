// lib/core/widgets/peekio_logo.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:peek/theme/colors.dart';

/// 🔒 FIX: Reusable PeekioLogo widget that automatically preserves aspect ratio
///
/// The peekio_logo.svg has dimensions 320x177 (aspect ratio ~1.81:1)
/// This widget automatically calculates the correct width to prevent stretching
class PeekioLogo extends StatelessWidget {
  final double height;
  final Color? color;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const PeekioLogo({
    super.key,
    required this.height,
    this.color = peekWhiteColor,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate width to maintain aspect ratio (320/177 = ~1.81)
    final double width = (320 / 177) * height;

    return SvgPicture.asset(
      'assets/images/peekio_logo.svg',
      height: height,
      width: width,
      fit: fit,
      colorFilter:
          color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
      placeholderBuilder: placeholder != null
          ? (context) => placeholder!
          : (context) => SizedBox(
                width: width,
                height: height,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  color: color ?? peekWhiteColor,
                ),
              ),
      errorBuilder: errorWidget != null
          ? (context, error, stackTrace) => errorWidget!
          : (context, error, stackTrace) {
              debugPrint("Error loading PeekioLogo: $error");
              return Icon(
                Icons.error_outline,
                size: height * 0.8,
                color: Colors.redAccent,
              );
            },
    );
  }
}

/// 🔒 FIX: Reusable PeekioEye widget for the eye icon
///
/// The peekio_eye.svg has dimensions 472x472 (aspect ratio 1:1 - square)
class PeekioEye extends StatelessWidget {
  final double size;
  final Color? color;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const PeekioEye({
    super.key,
    required this.size,
    this.color = peekWhiteColor,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/peekio_eye.svg',
      width: size,
      height: size,
      fit: fit,
      colorFilter:
          color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
      placeholderBuilder: placeholder != null
          ? (context) => placeholder!
          : (context) => SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  color: color ?? peekWhiteColor,
                ),
              ),
      errorBuilder: errorWidget != null
          ? (context, error, stackTrace) => errorWidget!
          : (context, error, stackTrace) {
              debugPrint("Error loading PeekioEye: $error");
              return Icon(
                Icons.error_outline,
                size: size * 0.8,
                color: Colors.redAccent,
              );
            },
    );
  }
}
