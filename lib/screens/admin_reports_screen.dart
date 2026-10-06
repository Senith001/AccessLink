import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/accessibility_report.dart';
import '../services/admin_service.dart';

/// Screen for administrators to review submitted accessibility reports.
///
/// Only accessible when the user has the `admin` custom claim.
/// Lists reports with place, reason, date, and status.
/// Admin can approve (with optional corrected info), reject, or view details.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final AdminService _adminService = AdminService();

  List<AccessibilityReport> _reports = [];
  bool _isLoading = true;
  bool _isUnauthorized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isUnauthorized = false;
    });

    try {
      final isAdmin = await _adminService.isCurrentUserAdmin();
      if (!isAdmin) {
        if (!mounted) return;
        setState(() {
          _isUnauthorized = true;
          _isLoading = false;
        });
        return;
      }

      final reports = await _adminService.getAllReports();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load reports: $e';
        _isLoading = false;
      });
    }
  }

  Color _statusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return Colors.orange;
      case ReportStatus.approved:
        return Colors.green;
      case ReportStatus.rejected:
        return Colors.red;
    }
  }

  IconData _statusIcon(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return Icons.hourglass_empty;
      case ReportStatus.approved:
        return Icons.check_circle;
      case ReportStatus.rejected:
        return Icons.cancel;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy – h:mm a').format(date);
  }

  Future<void> _showReviewDialog(AccessibilityReport report) async {
    if (report.status != ReportStatus.pending) {
      _showSnackBar('This report has already been ${report.status.name}.');
      return;
    }

    final correctedInfoController = TextEditingController();
    bool isProcessing = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.rate_review, color: Colors.blue.shade700),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Review Report',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _infoRow('Place', report.placeName),
                    const SizedBox(height: 8),
                    _infoRow('Place ID', report.placeId),
                    const SizedBox(height: 8),
                    _infoRow('Reporter', report.reporterUid),
                    const SizedBox(height: 8),
                    _infoRow('Date', _formatDate(report.createdAt)),
                    const SizedBox(height: 12),
                    const Text(
                      'Reason:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        report.reason,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: correctedInfoController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Corrected info (optional)',
                        hintText:
                            'Enter corrected accessibility information...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isProcessing ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          setDialogState(() => isProcessing = true);
                          try {
                            await _adminService.rejectReport(report.id);
                            if (!ctx.mounted) return;
                            Navigator.pop(dialogContext);
                            _showSnackBar('Report rejected.');
                            _loadReports();
                          } catch (e) {
                            setDialogState(() => isProcessing = false);
                            if (!ctx.mounted) return;
                            _showSnackBar('Error: $e');
                          }
                        },
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          setDialogState(() => isProcessing = true);
                          try {
                            await _adminService.approveReport(
                              report.id,
                              correctedInfo:
                                  correctedInfoController.text.trim().isNotEmpty
                                      ? correctedInfoController.text.trim()
                                      : null,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(dialogContext);
                            _showSnackBar('Report approved.');
                            _loadReports();
                          } catch (e) {
                            setDialogState(() => isProcessing = false);
                            if (!ctx.mounted) return;
                            _showSnackBar('Error: $e');
                          }
                        },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Admin – Reports'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        ),
        toolbarHeight: 64,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isUnauthorized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gpp_bad, size: 64, color: Colors.red.shade400),
              const SizedBox(height: 16),
              const Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'This section is restricted to authorized administrators. Your account does not possess the required administrator credentials.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadReports,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No reports submitted yet.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _reports.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final report = _reports[index];
          final statusColor = _statusColor(report.status);

          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showReviewDialog(report),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Place name + status badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            report.placeName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _statusIcon(report.status),
                                size: 14,
                                color: statusColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                report.status.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Reason snippet
                    Text(
                      report.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Date
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(report.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),

                    // Reviewer info (if reviewed)
                    if (report.reviewerUid != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Reviewed by ${report.reviewerUid}'
                              '${report.reviewedAt != null ? ' on ${_formatDate(report.reviewedAt!)}' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
