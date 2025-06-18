// lib/core/provider.dart
// lib/core/providers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// This provider is now centralized here to be safely used across the app
final userDataProvider =
    StreamProvider.autoDispose<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Stream.value(null);
  }
  return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
});
