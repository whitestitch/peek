// lib/features/peek/peek_receiver_page.dart
import 'package:flutter/material.dart' as material;
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/theme/colors.dart'; // Assuming your color constants are here for peekBackgroundColor

class PeekReceiverPage extends material.StatefulWidget {
  // Define your background image path here
  // Example:
  static String pageBackgroundPath = 'assets/images/onboarding_bg_02.jpg';

  const PeekReceiverPage({material.Key? key}) : super(key: key);

  @override
  material.State<PeekReceiverPage> createState() => _PeekReceiverPageState();
}

class _PeekReceiverPageState extends material.State<PeekReceiverPage> {
  final _auth = FirebaseAuth.instance;
  DocumentSnapshot<Map<String, dynamic>>? _currentRequest;

  @override
  void initState() {
    super.initState();
    _listenForRequests();
  }

  void _listenForRequests() {
    FirebaseFirestore.instance
        .collection('peek_requests')
        .where('status', isEqualTo: 'pending')
        // Optional: You might want to filter requests not sent by the current user
        // .where('from', isNotEqualTo: _auth.currentUser?.uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        // Additional check: ensure the request is not from the current user
        // to prevent a user from responding to their own sent (but somehow pending) request.
        // This depends on your app's logic for how 'pending' requests are managed.
        // If 'from' field exists in your peek_requests:
        // final String? senderId = doc.data()?['from'] as String?;
        // if (senderId != null && senderId == _auth.currentUser?.uid) {
        //   if (mounted) {
        //     setState(() {
        //       _currentRequest = null; // Don't show own request
        //     });
        //   }
        //   return;
        // }

        if (mounted) {
          setState(() {
            _currentRequest = doc;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _currentRequest = null;
          });
        }
      }
    }, onError: (error) {
      material
          .debugPrint("[PeekReceiverPage] Error listening to requests: $error");
      // Handle error appropriately, maybe show a message
    });
  }

  Future<void> _respondToRequest({required bool accept}) async {
    if (_currentRequest == null) return;
    final docRef = _currentRequest!.reference;
    final requestId = _currentRequest!.id;
    final String? uid = _auth.currentUser?.uid;

    if (uid == null) {
      material.debugPrint(
          "Error: User not logged in, cannot respond to peek request.");
      if (mounted) {
        material.ScaffoldMessenger.of(context).showSnackBar(
          const material.SnackBar(
              content:
                  material.Text("Error: You must be logged in to respond.")),
        );
      }
      return;
    }

    await docRef.update({
      'status': accept ? 'accepted' : 'rejected',
      'to': uid,
      'respondedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    if (accept) {
      context.go('/capture?requestId=$requestId');
    } else {
      // If rejected, simply clear the current request from UI and stay on page,
      // or navigate home. Current behavior navigates home.
      // To stay on page and wait for next:
      // setState(() {
      //   _currentRequest = null;
      // });
      context.go('/');
    }
  }

  @override
  material.Widget build(material.BuildContext context) {
    return material.Scaffold(
      backgroundColor: peekBackgroundColor, // Fallback color
      appBar: material.AppBar(
        title: const material.Text('Incoming Peek Requests'),
        backgroundColor:
            peekBackgroundColor.withOpacity(0.8), // Example appbar styling
        elevation: 0, // Flat appbar
        foregroundColor: peekWhiteColor, // Text/icon color
      ),
      body: material.Stack(
        // Use Stack for background image
        fit: material.StackFit.expand,
        children: [
          // --- Layer 1: Background Image ---
          material.Image.asset(
            PeekReceiverPage.pageBackgroundPath, // Use defined path
            fit: material.BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              material.debugPrint(
                  "[PeekReceiverPage] Error loading background: $error");
              return material.Container(color: peekBackgroundColor); // Fallback
            },
          ),

          // --- Layer 2: Optional Dimming Overlay ---
          // material.Container(
          //   color: material.Colors.black.withOpacity(0.3), // Adjust opacity
          // ),

          // --- Layer 3: Main Content ---
          material.Center(
            child: _currentRequest == null
                ? material.Padding(
                    // Added padding for the "no requests" text
                    padding: const material.EdgeInsets.all(20.0),
                    child: material.Text(
                      'No active peek requests right now.',
                      textAlign: material.TextAlign.center,
                      style: material.TextStyle(
                        fontSize: 18,
                        color: peekWhiteColor.withValues(alpha: 0.9),

                        // Optional: Add shadow for readability on background
                        // shadows: [
                        //   material.Shadow(blurRadius: 2.0, color: material.Colors.black54, offset: material.Offset(1,1)),
                        // ]
                      ),
                    ),
                  )
                : material.Padding(
                    // Added padding for the request content
                    padding: const material.EdgeInsets.all(20.0),
                    child: material.Column(
                      mainAxisAlignment: material.MainAxisAlignment.center,
                      children: [
                        material.Icon(
                          Symbols.flash_auto,
                          // material.Icons.camera,
                          size: 120,
                          color: peekWhiteColor.withValues(alpha: 0.5),
                          // Optional: Add shadow for readability
                          // shadows: [
                          //   material.Shadow(blurRadius: 3.0, color: material.Colors.black54, offset: material.Offset(1,1)),
                          // ]
                        ),
                        const material.SizedBox(height: 24),
                        material.Text(
                          'Someone is Peeking you!',
                          textAlign: material.TextAlign.center,
                          style: material.TextStyle(
                            fontWeight:
                                material.FontWeight.bold, // Bolder title
                            fontSize: 28, // Larger title
                            // color: peekWhiteColor,
                            color: peekWhiteColor.withValues(alpha: 0.9),
                            // Optional: Add shadow for readability
                            // shadows: [
                            //   material.Shadow(blurRadius: 3.0, color: material.Colors.black87, offset: material.Offset(1,1)),
                            // ]
                          ),
                        ),
                        const material.SizedBox(height: 12),
                        material.Text(
                          'Do you want to respond with a photo?',
                          textAlign: material.TextAlign.center,
                          style: material.TextStyle(
                              fontSize: 16,
                              color: peekWhiteColor.withValues(alpha: 0.9)
                              // Optional: Add shadow for readability
                              // shadows: [
                              //   material.Shadow(blurRadius: 2.0, color: material.Colors.black54, offset: material.Offset(1,1)),
                              // ]
                              ),
                        ),
                        const material.SizedBox(
                            height: 32), // Increased spacing
                        material.ElevatedButton.icon(
                          style: material.ElevatedButton.styleFrom(
                            backgroundColor:
                                peekPrimaryColor, // Example primary color
                            foregroundColor: peekSurfaceColor,
                            padding: const material.EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                            textStyle: const material.TextStyle(
                                fontSize: 16,
                                fontWeight: material.FontWeight.bold),
                          ),
                          onPressed: () => _respondToRequest(accept: true),
                          icon: const material.Icon(material.Icons.blur_on),
                          label: const material.Text('Accept'),
                        ),
                        const material.SizedBox(height: 16),
                        material.OutlinedButton.icon(
                          style: material.OutlinedButton.styleFrom(
                            side: material.BorderSide(
                                color: peekWhiteColor.withValues(alpha: 0.7)),
                            foregroundColor:
                                peekWhiteColor.withValues(alpha: 0.9),
                            padding: const material.EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                            textStyle: const material.TextStyle(
                                fontSize: 16,
                                fontWeight: material.FontWeight.normal),
                          ),
                          onPressed: () => _respondToRequest(accept: false),
                          icon: const material.Icon(material.Icons.close),
                          label: const material.Text('Not Now'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
