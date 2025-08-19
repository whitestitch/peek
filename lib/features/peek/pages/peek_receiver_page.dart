// lib/features/peek/pages/peek_receiver_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/features/peek/controllers/peek_controller.dart';
import 'package:peek/features/peek/pages/managers/peek_request_listener.dart';
import 'package:peek/features/peek/pages/managers/peek_response_handler.dart';
import 'package:peek/features/peek/pages/managers/peek_receiver_ui.dart';
import 'package:peek/theme/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PeekReceiverPage extends ConsumerStatefulWidget {
  static String pageBackgroundPath = 'assets/images/onboarding_bg_02.jpg';

  const PeekReceiverPage({super.key});

  @override
  ConsumerState<PeekReceiverPage> createState() => _PeekReceiverPageState();
}

class _PeekReceiverPageState extends ConsumerState<PeekReceiverPage> {
  final _requestListener = PeekRequestListener();
  final _responseHandler = PeekResponseHandler();
  final _uiBuilder = PeekReceiverUI();

  DocumentSnapshot<Map<String, dynamic>>? _currentRequest;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeRequestListener();
  }

  void _initializeRequestListener() {
    _requestListener.listenForRequests(
      onRequestReceived: (request) {
        if (mounted) {
          setState(() => _currentRequest = request);
        }
      },
      onRequestRemoved: () {
        if (mounted) {
          setState(() => _currentRequest = null);
        }
      },
      onError: (error) {
        debugPrint("[PeekReceiverPage] Error listening to requests: $error");
      },
    );
  }

  Future<void> _handleResponse({required bool accept}) async {
    if (_currentRequest == null || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final peekController = ref.read(peekControllerProvider.notifier);

      await _responseHandler.respondToRequest(
        request: _currentRequest!,
        accept: accept,
        onSuccess: (requestId) {
          if (accept) {
            context.go('/capture?requestId=$requestId&mode=response');
          } else {
            context.go('/');
          }
        },
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(accept
                  ? 'Failed to accept Peek. Please try again.'
                  : 'Failed to decline Peek. Please try again.'),
              backgroundColor: peekErrorColor,
            ),
          );
        },
        peekController: peekController,
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _requestListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: peekBackgroundColor,
      appBar: _uiBuilder.buildAppBar(),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          _uiBuilder.buildBackgroundImage(),

          // Main content
          _uiBuilder.buildMainContent(
            currentRequest: _currentRequest,
            isProcessing: _isProcessing,
            onAccept: () => _handleResponse(accept: true),
            onDecline: () => _handleResponse(accept: false),
          ),
        ],
      ),
    );
  }
}
