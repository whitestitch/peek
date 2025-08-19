// lib/features/peek/pages/peek_sender_wait_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peek/features/peek/controllers/peek_controller.dart';
import 'package:peek/features/peek/providers/peek_providers.dart';
import 'package:peek/theme/colors.dart';
import 'managers/peek_sender_wait_timer_manager.dart';
import 'managers/peek_sender_wait_listener.dart';
import 'managers/peek_sender_wait_ui.dart';
import 'managers/peek_sender_wait_navigation.dart';
import 'dart:async'; // Added for Timer

class PeekSenderWaitPage extends ConsumerStatefulWidget {
  final String requestId;

  const PeekSenderWaitPage({
    super.key,
    required this.requestId,
  });

  @override
  ConsumerState<PeekSenderWaitPage> createState() => _PeekSenderWaitPageState();
}

class _PeekSenderWaitPageState extends ConsumerState<PeekSenderWaitPage>
    with TickerProviderStateMixin {
  late final PeekSenderWaitTimerManager _timerManager;
  late final PeekSenderWaitListener _listener;
  late final PeekSenderWaitUI _uiBuilder;
  late final PeekSenderWaitNavigation _navigation;

  int? _secondsRemaining;
  bool _navigated = false;
  Timer? _countdownTimer;
  DateTime? _captureExpirationTime;
  bool _isPostSendMode = false; // Track if we're in post-send mode
  Timer? _postSendTimer; // Separate timer for post-send countdown

  @override
  void initState() {
    super.initState();
    debugPrint(
        "[PeekSenderWaitPage] Initialized for request ${widget.requestId}.");

    // Don't pre-initialize countdown - wait for Firestore sync to prevent desync
    _secondsRemaining = null;

    _initializeManagers();
    _startInitialCountdown();
  }

  void _initializeManagers() {
    _timerManager = PeekSenderWaitTimerManager(
      vsync: this,
      onCountdownUpdate: (seconds) {
        if (mounted && !_isPostSendMode) {
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
        debugPrint("[PeekSenderWaitPage] Listener error: $error");
      },
    );

    _uiBuilder = PeekSenderWaitUI();
    _navigation = PeekSenderWaitNavigation();
  }

  void _startInitialCountdown() {
    debugPrint(
        "[PeekSenderWaitPage] Starting photo capture countdown for request ${widget.requestId}");

    // Start the 30-second capture countdown to set captureExpiresAt field
    final peekController = ref.read(peekControllerProvider.notifier);
    peekController.startCaptureCountdown(widget.requestId).then((_) {
      debugPrint("[PeekSenderWaitPage] Capture countdown started successfully");

      // Start countdown immediately with estimated time
      _startImmediateCountdown();
    }).catchError((error) {
      debugPrint(
          "[PeekSenderWaitPage] Error starting capture countdown: $error");

      // Even if there's an error, start countdown immediately
      _startImmediateCountdown();
    });

    // Start watchdog timer as backup (70 seconds)
    _timerManager.startWatchdogTimer();

    debugPrint("[PeekSenderWaitPage] Watchdog timer started as backup");
  }

  void _startImmediateCountdown() {
    // Only start countdown if we have the actual Firestore expiration time
    if (_captureExpirationTime != null) {
      final now = DateTime.now();
      final remaining = _captureExpirationTime!.difference(now).inSeconds;

      setState(() {
        _secondsRemaining = remaining > 0 ? remaining : 0;
      });
      debugPrint(
          "[PeekSenderWaitPage] Immediate countdown started with Firestore sync: ${_secondsRemaining}s");

      // Start the live countdown timer
      _startLiveCountdown();
    } else {
      debugPrint(
          "[PeekSenderWaitPage] Waiting for Firestore expiration time before starting countdown");
    }
  }

  void _startLiveCountdown() {
    // Cancel any existing timer
    _countdownTimer?.cancel();

    if (_captureExpirationTime == null) {
      debugPrint(
          "[PeekSenderWaitPage] No expiration time available, using fallback countdown");

      // Fallback: countdown from current value
      if (_secondsRemaining != null && _secondsRemaining! > 0) {
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }

          setState(() {
            _secondsRemaining = (_secondsRemaining ?? 0) - 1;
          });

          if (_secondsRemaining! <= 0) {
            timer.cancel();
            if (!_navigated) {
              _handleTimeout();
            }
          }

          debugPrint(
              "[PeekSenderWaitPage] Fallback countdown update: ${_secondsRemaining}s remaining");
        });
      }
      return;
    }

    debugPrint(
        "[PeekSenderWaitPage] Starting live countdown with expiration: $_captureExpirationTime");

    // Start a timer that updates every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_captureExpirationTime == null) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final remaining = _captureExpirationTime!.difference(now).inSeconds;

      if (remaining <= 0) {
        // Time expired
        timer.cancel();
        if (!_navigated) {
          _handleTimeout();
        }
      } else {
        // Update the countdown display
        setState(() {
          _secondsRemaining = remaining;
        });
        debugPrint(
            "[PeekSenderWaitPage] Live countdown update: ${remaining}s remaining");
      }
    });
  }

  void _startPostSendCountdown() {
    // Cancel any existing timers
    _countdownTimer?.cancel();
    _postSendTimer?.cancel();

    // Set post-send mode
    _isPostSendMode = true;

    // Start clean 3-second countdown
    setState(() {
      _secondsRemaining = 3;
    });

    debugPrint("[PeekSenderWaitPage] Starting post-send countdown: 3s");

    _postSendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _secondsRemaining = (_secondsRemaining ?? 0) - 1;
      });

      debugPrint(
          "[PeekSenderWaitPage] Post-send countdown: ${_secondsRemaining}s remaining");

      if (_secondsRemaining! <= 0) {
        timer.cancel();
        // Don't navigate here - let the status listener handle it with proper image URL
        debugPrint(
            "[PeekSenderWaitPage] Post-send countdown completed, waiting for image data");
      }
    });
  }

  void _handleStatusUpdate(PeekStatusUpdate update) {
    debugPrint("[PeekSenderWaitPage] Status update received: ${update.status}");

    switch (update.status) {
      case 'accepted':
        // Already on the correct page, no action needed
        break;
      case 'responded_with_image':
        // Photo has been sent, stop main countdown and start post-send countdown
        debugPrint(
            "[PeekSenderWaitPage] Photo sent, starting post-send countdown");
        _startPostSendCountdown();

        // Store the image data for navigation after countdown completes
        if (update.imageUrl != null) {
          debugPrint(
              "[PeekSenderWaitPage] Image URL received: ${update.imageUrl}");
          // The countdown will complete and then we can navigate with proper data
          // This will be handled by the timer manager's final countdown
          _timerManager.startFinalCountdown(
              update.imageUrl!, update.senderLocation);
        }
        break;
      case 'completed':
        // Photo has been sent, start post-send countdown
        debugPrint(
            "[PeekSenderWaitPage] Photo sent, starting post-send countdown");
        _startPostSendCountdown();
        break;
      case 'expired':
        // Request expired, handle timeout
        if (!_navigated) {
          _handleTimeout();
        }
        break;
      default:
        debugPrint("[PeekSenderWaitPage] Unknown status: ${update.status}");
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
    _countdownTimer?.cancel();
    _postSendTimer?.cancel(); // Cancel the post-send timer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for capture expiration time and start countdown when available
    ref.listen(peekCaptureExpirationTimeProvider(widget.requestId),
        (previous, next) {
      next.whenData((expirationTime) {
        if (expirationTime != null &&
            _captureExpirationTime != expirationTime) {
          _captureExpirationTime = expirationTime;
          debugPrint(
              "[PeekSenderWaitPage] Capture expiration time received: $expirationTime");

          // Start the countdown immediately with the actual Firestore time
          if (mounted) {
            _startImmediateCountdown();
          }
        }
      });
    });

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
