import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PeekService {
  /// Create a new peek request and return the document reference
  Future<DocumentReference<Map<String, dynamic>>> createPeekRequest() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw Exception("User not authenticated");
    }

    return FirebaseFirestore.instance.collection('peek_requests').add({
      'from': uid,
      'to': null,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
