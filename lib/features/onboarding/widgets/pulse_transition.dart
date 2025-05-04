// lib/features/onboarding/widgets/pulse_transition.dart
import 'package:flutter/material.dart';

class PulseTransition extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double
      scaleFactor; // How much bigger it gets (e.g., 1.1 for 10% bigger)

  const PulseTransition({
    super.key,
    required this.child,
    this.duration =
        const Duration(milliseconds: 800), // Speed of one pulse cycle
    this.scaleFactor = 1.08, // Default scale increase
  });

  @override
  State<PulseTransition> createState() => _PulseTransitionState();
}

class _PulseTransitionState extends State<PulseTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true); // Repeat back and forth

    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor)
        .animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut, // Smooth easing
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}
