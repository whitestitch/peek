import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final userDocProvider = StreamProvider<DocumentSnapshot<Map<String, dynamic>>>((
  ref,
) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    throw Exception('User not signed in');
  }

  return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
});
