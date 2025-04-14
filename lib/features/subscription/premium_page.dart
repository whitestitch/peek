import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<bool> isUserPremium() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final doc = await _firestore.collection('subscriptions').doc(uid).get();
    final data = doc.data();
    return data != null && data['plan'] == 'premium';
  }

  Future<void> upgradeToPremium() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    final now = Timestamp.now();
    await _firestore.collection('subscriptions').doc(uid).set({
      'plan': 'premium',
      'startedAt': now,
    });
  }

  Stream<bool> premiumStatusStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false);

    return _firestore
        .collection('subscriptions')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data()?['plan'] == 'premium');
  }
}
