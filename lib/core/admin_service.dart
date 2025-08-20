import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for handling admin/moderation actions required by App Store guidelines
/// This ensures developer action within 24 hours on objectionable content reports
class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all pending reports that need developer review
  Future<List<Map<String, dynamic>>> getPendingReports() async {
    try {
      final reportsQuery = await _firestore
          .collection('reports')
          .where('status', isEqualTo: 'pending_review')
          .orderBy('reportTimestamp', descending: true)
          .get();

      return reportsQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      debugPrint("[AdminService] Error getting pending reports: $e");
      return [];
    }
  }

  /// Get reports that are older than 24 hours and still pending
  Future<List<Map<String, dynamic>>> getOverdueReports() async {
    try {
      final twentyFourHoursAgo =
          DateTime.now().subtract(const Duration(hours: 24));

      final reportsQuery = await _firestore
          .collection('reports')
          .where('status', isEqualTo: 'pending_review')
          .where('reportTimestamp',
              isLessThan: Timestamp.fromDate(twentyFourHoursAgo))
          .get();

      return reportsQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      debugPrint("[AdminService] Error getting overdue reports: $e");
      return [];
    }
  }

  /// Mark a report as reviewed and take action
  Future<void> reviewReport({
    required String reportId,
    required String
        action, // 'remove_content', 'warn_user', 'restrict_user', 'no_action'
    String? adminNotes,
  }) async {
    try {
      final reportRef = _firestore.collection('reports').doc(reportId);
      final reportDoc = await reportRef.get();

      if (!reportDoc.exists) {
        throw Exception('Report not found');
      }

      final reportData = reportDoc.data()!;
      final reportedUserId = reportData['reportedSenderId'] as String;
      final peekRequestId = reportData['peekRequestId'] as String;

      // Update report status
      await reportRef.update({
        'status': 'reviewed',
        'adminAction': action,
        'adminNotes': adminNotes,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      // Take action based on admin decision
      switch (action) {
        case 'remove_content':
          await _removeReportedContent(peekRequestId);
          break;
        case 'restrict_user':
          await _restrictUser(
              reportedUserId, 'Admin action on report: $reportId');
          break;
        case 'warn_user':
          await _warnUser(reportedUserId, 'Content reported and reviewed');
          break;
        case 'no_action':
          // No additional action needed
          break;
        default:
          debugPrint("[AdminService] Unknown action: $action");
      }

      debugPrint(
          "[AdminService] Report $reportId reviewed with action: $action");
    } catch (e) {
      debugPrint("[AdminService] Error reviewing report: $e");
      rethrow;
    }
  }

  /// Remove reported content from the system
  Future<void> _removeReportedContent(String peekRequestId) async {
    try {
      await _firestore.collection('peek_requests').doc(peekRequestId).update({
        'status': 'removed_due_to_violation',
        'removedAt': FieldValue.serverTimestamp(),
        'removalReason': 'Admin action on reported content',
      });

      debugPrint(
          "[AdminService] Content removed for peek request: $peekRequestId");
    } catch (e) {
      debugPrint("[AdminService] Error removing content: $e");
    }
  }

  /// Restrict a user's account
  Future<void> _restrictUser(String userId, String reason) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'reputation.status': 'restricted',
        'reputation.restrictedAt': FieldValue.serverTimestamp(),
        'reputation.lastModerationAction': FieldValue.serverTimestamp(),
        'reputation.adminNotes': reason,
      });

      debugPrint("[AdminService] User $userId restricted: $reason");
    } catch (e) {
      debugPrint("[AdminService] Error restricting user: $e");
    }
  }

  /// Warn a user about their content
  Future<void> _warnUser(String userId, String reason) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'reputation.lastModerationAction': FieldValue.serverTimestamp(),
        'reputation.adminNotes': reason,
      });

      debugPrint("[AdminService] User $userId warned: $reason");
    } catch (e) {
      debugPrint("[AdminService] Error warning user: $e");
    }
  }

  /// Get moderation statistics for admin dashboard
  Future<Map<String, dynamic>> getModerationStats() async {
    try {
      final totalReports = await _firestore.collection('reports').count().get();
      final pendingReports = await _firestore
          .collection('reports')
          .where('status', isEqualTo: 'pending_review')
          .count()
          .get();
      final overdueReports = await getOverdueReports();

      return {
        'totalReports': totalReports.count,
        'pendingReports': pendingReports.count,
        'overdueReports': overdueReports.length,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint("[AdminService] Error getting moderation stats: $e");
      return {
        'totalReports': 0,
        'pendingReports': 0,
        'overdueReports': 0,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }
}

// Provider for AdminService
final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService();
});
