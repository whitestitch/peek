// lib/features/splash/splash_start.dart

import 'package:flutter/material.dart';
import 'package:peek/theme/colors.dart';
import 'package:peek/core/widgets/peekio_logo.dart'; // 🔒 FIX: Import reusable widgets

// This widget is now a simple, passive UI component. It contains no logic.
// The GoRouter is solely responsible for navigating away from this screen.
class SplashStartPage extends StatefulWidget {
  const SplashStartPage({super.key});

  @override
  State<SplashStartPage> createState() => _SplashStartPageState();
}

class _SplashStartPageState extends State<SplashStartPage>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _progressController;
  final Duration _splashDuration = const Duration(seconds: 4);

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _progressController = AnimationController(
      vsync: this,
      duration: _splashDuration,
    )..forward();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: peekBackgroundColor,
      body: Center(
        child: SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return CircularProgressIndicator(
                      value: _progressController.value,
                      strokeWidth: 6.0,
                      backgroundColor:
                          Colors.grey.shade800.withValues(alpha: 0.5),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(peekPrimaryColor),
                    );
                  },
                ),
              ),
              RotationTransition(
                turns: _rotationController,
                child: PeekioEye(
                  size:
                      60, // 🔒 FIX: Use reusable widget with proper aspect ratio
                  color: peekWhiteColor,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
