import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:peek/core/admin_service.dart';
import 'package:peek/theme/colors.dart';

/// Admin dashboard for reviewing reports and taking moderation actions
/// Ensures compliance with App Store 24-hour response requirement
class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _pendingReports = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final adminService = ref.read(adminServiceProvider);
      final reports = await adminService.getPendingReports();
      final stats = await adminService.getModerationStats();

      setState(() {
        _pendingReports = reports;
        _stats = stats;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: peekSurfaceColor,
        foregroundColor: peekOnSurfaceColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      backgroundColor: peekSurfaceColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsCards(),
                    const SizedBox(height: 24),
                    _buildReportsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Reports',
          '${_stats['totalReports'] ?? 0}',
          Icons.report,
          Colors.blue,
        ),
        _buildStatCard(
          'Pending Review',
          '${_stats['pendingReports'] ?? 0}',
          Icons.pending,
          Colors.orange,
        ),
        _buildStatCard(
          'Overdue (>24h)',
          '${_stats['overdueReports'] ?? 0}',
          Icons.warning,
          Colors.red,
        ),
        _buildStatCard(
          'Last Updated',
          _formatTimestamp(_stats['lastUpdated']),
          Icons.update,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: peekOnSurfaceColor.withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsList() {
    if (_pendingReports.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: Colors.green.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No pending reports!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: peekOnSurfaceColor,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'All reports have been reviewed.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: peekOnSurfaceColor.withOpacity(0.7),
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending Reports (${_pendingReports.length})',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: peekOnSurfaceColor,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        ..._pendingReports.map((report) => _buildReportCard(report)),
      ],
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final isOverdue = _isReportOverdue(report['reportTimestamp']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isOverdue ? Colors.red.withOpacity(0.1) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isOverdue ? Icons.warning : Icons.report,
                  color: isOverdue ? Colors.red : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Report #${report['id'].toString().substring(0, 8)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: peekOnSurfaceColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (isOverdue)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'OVERDUE',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildReportField(
                'Reason', report['reason'] ?? 'No reason provided'),
            _buildReportField('Reporter', report['reporterId'] ?? 'Unknown'),
            _buildReportField(
                'Reported User', report['reportedSenderId'] ?? 'Unknown'),
            _buildReportField(
                'Peek Request', report['peekRequestId'] ?? 'Unknown'),
            _buildReportField(
                'Timestamp', _formatTimestamp(report['reportTimestamp'])),
            if (report['reportedImageUrl'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Image URL:',
                style: TextStyle(
                  color: peekOnSurfaceColor.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  report['reportedImageUrl'],
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showActionDialog(report),
                    icon: const Icon(Icons.rate_review),
                    label: const Text('Take Action'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: peekPrimaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewReportDetails(report),
                    icon: const Icon(Icons.info),
                    label: const Text('Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: peekPrimaryColor,
                      side: BorderSide(color: peekPrimaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: peekOnSurfaceColor.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: peekOnSurfaceColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showActionDialog(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Take Action'),
        content:
            const Text('What action would you like to take on this report?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _takeAction(report, 'remove_content');
            },
            child: const Text('Remove Content'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _takeAction(report, 'warn_user');
            },
            child: const Text('Warn User'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _takeAction(report, 'restrict_user');
            },
            child: const Text('Restrict User'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _takeAction(report, 'no_action');
            },
            child: const Text('No Action'),
          ),
        ],
      ),
    );
  }

  Future<void> _takeAction(Map<String, dynamic> report, String action) async {
    try {
      final adminService = ref.read(adminServiceProvider);
      await adminService.reviewReport(
        reportId: report['id'],
        action: action,
        adminNotes: 'Action taken via admin dashboard',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report reviewed with action: $action')),
        );
        _loadData(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking action: $e')),
        );
      }
    }
  }

  void _viewReportDetails(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildReportField('Report ID', report['id']),
              _buildReportField('Status', report['status'] ?? 'Unknown'),
              _buildReportField('Reason', report['reason'] ?? 'No reason'),
              _buildReportField(
                  'Reporter ID', report['reporterId'] ?? 'Unknown'),
              _buildReportField(
                  'Reported User ID', report['reportedSenderId'] ?? 'Unknown'),
              _buildReportField(
                  'Peek Request ID', report['peekRequestId'] ?? 'Unknown'),
              _buildReportField(
                  'Timestamp', _formatTimestamp(report['reportTimestamp'])),
              if (report['reportedImageUrl'] != null)
                _buildReportField('Image URL', report['reportedImageUrl']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  bool _isReportOverdue(dynamic timestamp) {
    if (timestamp == null) return false;

    final reportTime = timestamp is Timestamp
        ? timestamp.toDate()
        : DateTime.parse(timestamp.toString());
    final twentyFourHoursAgo =
        DateTime.now().subtract(const Duration(hours: 24));

    return reportTime.isBefore(twentyFourHoursAgo);
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      if (timestamp is Timestamp) {
        return timestamp.toDate().toString().substring(0, 19);
      } else if (timestamp is String) {
        return DateTime.parse(timestamp).toString().substring(0, 19);
      }
      return timestamp.toString();
    } catch (e) {
      return 'Invalid timestamp';
    }
  }
}
