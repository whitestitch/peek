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

  bool _navigated = false; // Prevent multiple redirects

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
          _navigated = true; // Avoid duplicate redirects
          if (mounted) {
            // Avoid async context error
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go(
                '/splash?requestId=${widget.requestId}&imageUrl=$imageUrl',
              );
            });
          }
          return const Center(child: Text('Preparing your peek...'));
        }

        // Default state for requester waiting
        return const Center(child: Text('👀 Waiting for someone to Peek…'));
      },
    );
  }
}
