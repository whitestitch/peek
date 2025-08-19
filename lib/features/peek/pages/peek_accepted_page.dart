// lib/features/peek/pages/peek_accepted_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/theme/colors.dart';
import 'managers/peek_accepted_celebration_manager.dart';
import 'managers/peek_accepted_navigation_manager.dart';
import 'managers/peek_accepted_ui.dart';

class PeekAcceptedPage extends StatefulWidget {
  final String requestId;
  static String pageBackgroundPath = 'assets/images/peek_accepted_bg.jpg';

  const PeekAcceptedPage({
    super.key,
    required this.requestId,
  });

  @override
  State<PeekAcceptedPage> createState() => _PeekAcceptedPageState();
}

class _PeekAcceptedPageState extends State<PeekAcceptedPage> {
  late final PeekAcceptedCelebrationManager _celebrationManager;
  late final PeekAcceptedNavigationManager _navigationManager;
  late final PeekAcceptedUI _uiBuilder;

  @override
  void initState() {
    super.initState();
    debugPrint("[PeekAcceptedPage] Initialized for 3-second celebration.");

    _initializeManagers();
    _startCelebration();
  }

  void _initializeManagers() {
    _celebrationManager = PeekAcceptedCelebrationManager();
    _navigationManager = PeekAcceptedNavigationManager(
      requestId: widget.requestId,
      onNavigationComplete: () {
        if (mounted) {
          context.go('/peek-sender-wait?requestId=${widget.requestId}');
        }
      },
    );
    _uiBuilder = PeekAcceptedUI();
  }

  void _startCelebration() {
    _celebrationManager.startCelebration();
    _navigationManager.startNavigationTimer();
  }

  @override
  void dispose() {
    debugPrint("[PeekAcceptedPage] Disposing.");
    _celebrationManager.dispose();
    _navigationManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: peekBackgroundColor,
      body: _uiBuilder.buildBody(
        context: context,
        celebrationController: _celebrationManager.confettiController,
        backgroundImagePath: PeekAcceptedPage.pageBackgroundPath,
      ),
    );
  }
}
