// lib/core/widgets/peek_loading_indicator.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:peek/theme/colors.dart';

/// Unified loading indicator with spinning Peek logo
/// Consistent with splash_start.dart implementation
class PeekLoadingIndicator extends StatefulWidget {
  /// Size of the loading indicator
  final double size;

  /// Whether to show progress circle background
  final bool showProgressCircle;

  /// Color of the progress circle (defaults to peekPrimaryColor)
  final Color? progressColor;

  /// Color of the spinning logo (defaults to peekWhiteColor)
  final Color? logoColor;

  /// Optional loading text below the indicator
  final String? loadingText;

  /// Text style for loading text
  final TextStyle? textStyle;

  const PeekLoadingIndicator({
    super.key,
    this.size = 120.0,
    this.showProgressCircle = true,
    this.progressColor,
    this.logoColor,
    this.loadingText,
    this.textStyle,
  });

  /// Small variant for buttons and inline loading
  const PeekLoadingIndicator.small({
    super.key,
    this.size = 24.0,
    this.showProgressCircle = false,
    this.progressColor,
    this.logoColor,
    this.loadingText,
    this.textStyle,
  });

  /// Medium variant for page sections
  const PeekLoadingIndicator.medium({
    super.key,
    this.size = 60.0,
    this.showProgressCircle = true,
    this.progressColor,
    this.logoColor,
    this.loadingText,
    this.textStyle,
  });

  /// Medium variant for page sections
  const PeekLoadingIndicator.large({
    super.key,
    this.size = 90.0,
    this.showProgressCircle = true,
    this.progressColor,
    this.logoColor,
    this.loadingText,
    this.textStyle,
  });

  @override
  State<PeekLoadingIndicator> createState() => _PeekLoadingIndicatorState();
}

class _PeekLoadingIndicatorState extends State<PeekLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Consistent with splash_start.dart
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = widget.size * 0.5; // Logo is 50% of total size
    final effectiveProgressColor = widget.progressColor ?? peekPrimaryColor;
    final effectiveLogoColor = widget.logoColor ?? peekWhiteColor;

    Widget indicator = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circular progress (optional)
          if (widget.showProgressCircle)
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CircularProgressIndicator(
                strokeWidth: widget.size > 60 ? 6.0 : 3.0,
                backgroundColor: Colors.grey.shade800.withOpacity(0.3),
                valueColor:
                    AlwaysStoppedAnimation<Color>(effectiveProgressColor),
              ),
            ),

          // Spinning logo
          RotationTransition(
            turns: _rotationController,
            child: SvgPicture.asset(
              'assets/images/peekio_eye.svg',
              width: logoSize,
              height: logoSize,
              colorFilter: ColorFilter.mode(
                effectiveLogoColor,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );

    // Add loading text if provided
    if (widget.loadingText != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          indicator,
          const SizedBox(height: 16),
          Text(
            widget.loadingText!,
            style: widget.textStyle ??
                const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return indicator;
  }
}
