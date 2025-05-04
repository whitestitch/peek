import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

/// Displays status while waiting for a peek request to be accepted or rejected.
/// Navigates to SplashPage on acceptance.
/// (Consider if PeekWaitPage replaces the need for this page).
class PeekingPage extends StatefulWidget {
  final String requestId;
  const PeekingPage({super.key, required this.requestId});

  @override
  State<PeekingPage> createState() => _PeekingPageState();
}

class _PeekingPageState extends State<PeekingPage> {
  // Stream providing live updates for the specific peek request document.
  Stream<DocumentSnapshot<Map<String, dynamic>>> get _requestStream =>
      FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(widget.requestId)
          .snapshots();

  bool _navigated = false; // Flag to prevent duplicate navigation calls

  @override
  void initState() {
    super.initState();
    debugPrint("[PeekingPage] Initialized for request ${widget.requestId}");
    // Check if the document exists initially? Optional robustness check.
    // FirebaseFirestore.instance.collection('peek_requests').doc(widget.requestId).get().then((doc) {
    //   if (!mounted) return;
    //   if (!doc.exists) {
    //     debugPrint("Error: Request document ${widget.requestId} not found on init.");
    //     _navigated = true;
    //     context.go('/'); // Navigate home if request doesn't exist
    //   }
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Add Scaffold for better structure
      backgroundColor: Colors.black, // Match theme
      // Optional AppBar
      // appBar: AppBar(
      //    title: Text("Peeking..."),
      //    leading: IconButton(icon: Icon(Icons.close), onPressed: () => context.go('/')),
      // ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _requestStream,
        builder: (context, snapshot) {
          // Handle connection state while waiting for data
          if (snapshot.connectionState == ConnectionState.waiting) {
            debugPrint("[PeekingPage] Stream waiting...");
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          // Handle errors in the stream
          if (snapshot.hasError) {
            debugPrint("❌ [PeekingPage] Stream error: ${snapshot.error}");
            return Center(
              child: Text(
                'Error loading peek status: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          // Handle case where document doesn't exist or has no data
          if (!snapshot.hasData || !snapshot.data!.exists) {
            debugPrint(
              "⚠️ [PeekingPage] Snapshot has no data or document doesn't exist for ${widget.requestId}.",
            );
            // Prevent potential infinite loops if stream keeps emitting null
            if (!_navigated) {
              _navigated = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) context.go('/'); // Go home if request disappears
              });
            }
            return const Center(
              child: Text(
                'Peek request not found.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          // Data is available, extract status and imageUrl
          final data = snapshot.data!.data();
          final status = data?['status'] as String?;
          final imageUrl = data?['imageUrl'] as String?; // Get raw URL

          debugPrint(
            "[PeekingPage] Stream update: status=$status, imageUrl=${imageUrl != null ? 'present' : 'null'}",
          );

          // Navigate based on status
          switch (status) {
            case 'accepted':
              // Navigate only if accepted, URL exists, and not already navigated
              if (imageUrl != null && imageUrl.isNotEmpty && !_navigated) {
                _navigated = true; // Set flag immediately
                // Use WidgetsBinding to schedule navigation after build completes
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // Check mounted again inside callback before navigating
                  if (mounted) {
                    debugPrint(
                      "[PeekingPage] Peek accepted. Navigating to SplashPage with imageUrl: $imageUrl",
                    );

                    // --- FIX: Pass imageUrl directly ---
                    final splashUri = Uri(
                      path: '/splash',
                      queryParameters: {
                        'requestId': widget.requestId,
                        // Pass the RAW imageUrl string. GoRouter handles encoding.
                        'initialImageUrl': imageUrl,
                      },
                    );
                    // --- End of Fix ---

                    context.go(splashUri.toString());
                  }
                });
                // Show loading momentarily while navigation is scheduled
                return const Center(
                  child: Text(
                    'Preparing your Peek...',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              } else if (imageUrl == null || imageUrl.isEmpty) {
                // Accepted but no URL? Log error, show waiting.
                debugPrint(
                  "⚠️ [PeekingPage] Status 'accepted' but imageUrl missing for ${widget.requestId}.",
                );
                return const Center(
                  child: Text(
                    'Waiting for image URL...',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }
              // If already navigated, just show loading/waiting
              return const Center(
                child: Text(
                  'Preparing your Peek...',
                  style: TextStyle(color: Colors.white),
                ),
              );

            case 'rejected':
              if (!_navigated) {
                _navigated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    // Show message briefly then go home? Or just go home?
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('User was not ready to Peek.'),
                      ),
                    );
                    context.go('/');
                  }
                });
              }
              // Show rejection message until navigation happens
              return const Center(
                child: Text(
                  'User was not ready to Peek.',
                  style: TextStyle(color: Colors.white),
                ),
              );

            case 'timeout':
              if (!_navigated) {
                _navigated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Peek request timed out.')),
                    );
                    context.go('/');
                  }
                });
              }
              return const Center(
                child: Text(
                  'Peek request timed out.',
                  style: TextStyle(color: Colors.white),
                ),
              );

            case 'pending':
            default:
              // Still waiting for receiver action
              return const Center(
                child: Text(
                  '👀 Waiting for someone to Peek…',
                  style: TextStyle(color: Colors.white),
                ),
              );
          }
        },
      ),
    );
  }
}
