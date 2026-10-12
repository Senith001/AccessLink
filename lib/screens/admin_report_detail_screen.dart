import 'package:flutter/material.dart';

import '../models/accessibility_report.dart';
import '../services/report_moderation_service.dart';
import 'admin_edit_place_screen.dart';

class AdminReportDetailScreen extends StatefulWidget {
  final AccessibilityReport report;

  const AdminReportDetailScreen({super.key, required this.report});

  static Route<bool?> route({required AccessibilityReport report}) {
    return MaterialPageRoute(
      builder: (_) => AdminReportDetailScreen(report: report),
    );
  }

  @override
  State<AdminReportDetailScreen> createState() =>
      _AdminReportDetailScreenState();
}

class _AdminReportDetailScreenState extends State<AdminReportDetailScreen> {
  final ReportModerationService _service = ReportModerationService();
  late AccessibilityReport _report;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
  }

  Future<void> _handleApprove() async {
    final noteController = TextEditingController();
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Accept this report as valid. This records your moderation approval for audit purposes. (Approval alone does not modify place data).',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Moderator Decision Note (Optional)',
                hintText: 'e.g., Confirmed with facility manager; queued for maintenance update.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade800,
            ),
            child: const Text('Confirm Approval'),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    setState(() => _isProcessing = true);
    try {
      await _service.approveReport(
        reportId: _report.id,
        adminNotes: noteController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report approved successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleReject() async {
    final noteController = TextEditingController();
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Record that this report was not accepted. Please explain the rationale in the decision note below.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Moderator Decision Note (Required)',
                hintText: 'e.g., Information verified accurate on site yesterday; no action required.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (noteController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please provide a decision note explaining the rejection.',
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
            ),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    setState(() => _isProcessing = true);
    try {
      await _service.rejectReport(
        reportId: _report.id,
        adminNotes: noteController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report marked as rejected.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleUpdateInformation() async {
    final updated = await Navigator.push<bool?>(
      context,
      AdminEditPlaceScreen.route(
        placeId: _report.placeId,
        placeName: _report.placeName,
        relatedReportId: _report.id,
        reportedTargetField: _report.targetField,
      ),
    );

    if (updated == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange.shade800;
      case 'approved':
        return Colors.green.shade800;
      case 'rejected':
        return Colors.red.shade800;
      case 'resolved':
        return Colors.blue.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = _getStatusColor(_report.status);

    return Scaffold(
      appBar: AppBar(title: const Text('Report Details')),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: statusColor,
                              ),
                            ),
                            Text(
                              _report.status.toUpperCase(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          _report.isResolved
                              ? Icons.task_alt
                              : _report.isApproved
                              ? Icons.check_circle_outline
                              : _report.isRejected
                              ? Icons.cancel_outlined
                              : Icons.pending_actions,
                          color: statusColor,
                          size: 32,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Place Information
                  Text('Place', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    _report.placeName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Target Feature
                  Text('Reported Item', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _report.targetField,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category
                  Text('Category', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(_report.categoryLabel, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 16),

                  // Reason / Description
                  Text('Reporter Notes', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorScheme.outline),
                    ),
                    child: Text(
                      _report.description,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reporter Details
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reported By',
                              style: theme.textTheme.labelMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _report.reporterName,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      if (_report.createdAt != null)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date Filed',
                                style: theme.textTheme.labelMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _report.createdAt!.toLocal().toString().split(
                                  '.',
                                )[0],
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Moderation Audit Trail (if already reviewed)
                  if (!_report.isPending) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Moderation Decision',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_report.reviewedByName != null)
                      Text('Reviewed by: ${_report.reviewedByName!}'),
                    if (_report.reviewedAt != null)
                      Text(
                        'Date: ${_report.reviewedAt!.toLocal().toString().split('.')[0]}',
                      ),
                    if (_report.adminNotes != null &&
                        _report.adminNotes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Decision note: "${_report.adminNotes!}"',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],

                  // Action Buttons for Pending or Unresolved
                  const SizedBox(height: 32),
                  if (_report.isPending) ...[
                    Text(
                      'Moderator Actions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Action 1: Approve
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _handleApprove,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Approve Report (Valid Discrepancy)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade800,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Action 2: Reject
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _handleReject,
                        icon: const Icon(Icons.cancel),
                        label: const Text(
                          'Reject Report (Invalid / Inaccurate)',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade800,
                          side: BorderSide(color: Colors.red.shade800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Action 3: Update Place Information
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _handleUpdateInformation,
                      icon: const Icon(Icons.edit_location_alt),
                      label: const Text('Correct Place Information & Resolve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
