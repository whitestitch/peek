import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final premiumStatusProvider = StreamProvider<bool>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(false);

  final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
  return docRef.snapshots().map((doc) => doc.data()?['isPremium'] == true);
});

final upgradePremiumProvider = Provider((ref) {
  return () async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'isPremium': true,
      'upgradedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  };
});
