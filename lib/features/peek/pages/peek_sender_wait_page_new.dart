// lib/features/peek/pages/peek_sender_wait_page_new.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peek/features/peek/controllers/peek_controller.dart';
import 'package:peek/theme/colors.dart';
import 'managers/peek_sender_wait_timer_manager.dart';
import 'managers/peek_sender_wait_listener.dart';
import 'managers/peek_sender_wait_ui.dart';
import 'managers/peek_sender_wait_navigation.dart';

class PeekSenderWaitPageNew extends ConsumerStatefulWidget {
  final String requestId;

  const PeekSenderWaitPageNew({super.key, required this.requestId});

  @override
  ConsumerState<PeekSenderWaitPageNew> createState() =>
      _PeekSenderWaitPageNewState();
}

class _PeekSenderWaitPageNewState extends ConsumerState<PeekSenderWaitPageNew>
    with TickerProviderStateMixin {
  late final PeekSenderWaitTimerManager _timerManager;
  late final PeekSenderWaitListener _listener;
  late final PeekSenderWaitUI _uiBuilder;
  late final PeekSenderWaitNavigation _navigation;

  int? _secondsRemaining;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    debugPrint(
        "[PeekSenderWaitPageNew] Initialized for request ${widget.requestId}.");

    _initializeManagers();
    _startInitialCountdown();
  }

  void _initializeManagers() {
    _timerManager = PeekSenderWaitTimerManager(
      vsync: this,
      onCountdownUpdate: (seconds) {
        if (mounted) {
          setState(() => _secondsRemaining = seconds);
        }
      },
      onTimeout: () => _handleTimeout(),
      onFinalCountdownComplete: (imageUrl, senderLocation) {
        _navigation.navigateToImageView(
          context,
          widget.requestId,
          imageUrl,
          senderLocation,
        );
      },
    );

    _listener = PeekSenderWaitListener(requestId: widget.requestId);
    _listener.listenForUpdates(
      onStatusUpdate: _handleStatusUpdate,
      onError: (error) {
        debugPrint("[PeekSenderWaitPageNew] Listener error: $error");
      },
    );

    _uiBuilder = PeekSenderWaitUI();
    _navigation = PeekSenderWaitNavigation();
  }

  void _startInitialCountdown() {
    // Start manual 30-second countdown immediately
    _timerManager.startManualCountdown();

    // Start watchdog timer
    _timerManager.startWatchdogTimer();
  }

  void _handleStatusUpdate(PeekStatusUpdate update) {
    if (_navigated) return;

    switch (update.status) {
      case 'responded_with_image':
        if (update.imageUrl != null) {
          _timerManager.startFinalCountdown(
              update.imageUrl!, update.senderLocation);
        }
        break;
      case 'cancelled_by_receiver':
      case 'declined':
        _navigation.navigateToHomeWithCancellation(context);
        _navigated = true;
        break;
      case 'expired_capture':
        _handleTimeout();
        break;
      default:
        // Handle other status updates if needed
        break;
    }
  }

  void _handleTimeout() {
    if (_navigated) return;
    _navigated = true;

    _uiBuilder.showTimeoutDialog(context).then((_) {
      if (mounted) {
        _navigation.navigateToHome(context);
      }
    });
  }

  void _handleCancelPeek() {
    ref
        .read(peekControllerProvider.notifier)
        .cancelPeekBySender(widget.requestId);
    _navigation.navigateToHomeWithCancellation(context);
  }

  @override
  void dispose() {
    _timerManager.dispose();
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: peekBackgroundColor,
      appBar: _uiBuilder.buildAppBar(
        onCancel: _handleCancelPeek,
      ),
      extendBodyBehindAppBar: true,
      body: _uiBuilder.buildBody(
        context: context,
        secondsRemaining: _secondsRemaining,
        animationController: _timerManager.animationController,
      ),
    );
  }
}
