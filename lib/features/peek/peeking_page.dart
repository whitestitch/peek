// lib/features/peek/peeking_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class PeekingPage extends StatefulWidget {
  final String requestId;
  const PeekingPage({super.key, required this.requestId});

  @override
  State<PeekingPage> createState() => _PeekingPageState();
}

class _PeekingPageState extends State<PeekingPage> {
  Stream<DocumentSnapshot<Map<String, dynamic>>> get _requestStream =>
      FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(widget.requestId)
          .snapshots();

  bool _navigated = false; // Prevent duplicate redirects

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _requestStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data();
        final status = data?['status'];
        final imageUrl = data?['imageUrl'];

        if (status == 'rejected') {
          return const Center(child: Text('User was not ready to Peek.'));
        }

        if (status == 'accepted' && imageUrl != null && !_navigated) {
          _navigated = true;
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final splashUri =
                  Uri(
                    path: '/splash',
                    queryParameters: {
                      'requestId': widget.requestId,
                      'imageUrl': imageUrl,
                    },
                  ).toString();
              context.go(splashUri);
            });
          }
          return const Center(child: Text('Preparing your peek...'));
        }

        return const Center(child: Text('👀 Waiting for someone to Peek…'));
      },
    );
  }
}
