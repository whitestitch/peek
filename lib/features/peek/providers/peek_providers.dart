// 📁 lib/features/peek/providers/peek_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/peek_repository.dart';

/// ✅ Provider for PeekRepository, injecting Firestore and FirebaseAuth
final peekRepositoryProvider = Provider<PeekRepository>((ref) {
  return PeekRepository(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );
});
