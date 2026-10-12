import 'package:flutter/material.dart';

import '../models/accessibility_report.dart';
import '../services/report_moderation_service.dart';
import 'admin_report_detail_screen.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (_) => const AdminReportsScreen());
  }

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final ReportModerationService _service = ReportModerationService();

  String _statusFilter =
      'all'; // 'all', 'pending', 'approved', 'rejected', 'resolved'
  List<AccessibilityReport> _reports = [];
  bool _isLoading = true;
  bool _isAuthorized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  Future<void> _checkAuthAndLoad() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isStaff = await _service.isUserStaff();
    if (!mounted) return;

    if (!isStaff) {
      setState(() {
        _isAuthorized = false;
        _isLoading = false;
      });
      return;
    }

    _isAuthorized = true;
    await _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reports = await _service.getReports(statusFilter: _statusFilter);
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load reports: $e';
      });
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() => _statusFilter = value);
            _loadReports();
          }
        },
        selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!_isLoading && !_isAuthorized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Moderation Panel')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.gpp_bad, size: 64, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Access Restricted',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This moderation panel requires an administrator or moderator account. Ordinary users are not authorized to review or manage user reports.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Return to App'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Moderation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh reports',
            onPressed: _loadReports,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: colorScheme.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  _buildFilterChip('Pending', 'pending'),
                  _buildFilterChip('Approved', 'approved'),
                  _buildFilterChip('Rejected', 'rejected'),
                  _buildFilterChip('Resolved', 'resolved'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: colorScheme.error,
                          ),
                          const SizedBox(height: 12),
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadReports,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _reports.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 56,
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No reports found in this status',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'When users flag inaccurate accessibility details, they will appear here.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadReports,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reports.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final report = _reports[index];
                        final statusColor = _getStatusColor(report.status);

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: colorScheme.outline),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final updated = await Navigator.push(
                                context,
                                AdminReportDetailScreen.route(report: report),
                              );
                              if (updated == true) {
                                _loadReports();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header: Place name & status pill
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          report.placeName,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: statusColor,
                                          ),
                                        ),
                                        child: Text(
                                          report.status.toUpperCase(),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Target field chip
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          report.targetField,
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'By: ${report.reporterName}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorScheme.onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Excerpt
                                  Text(
                                    report.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium,
                                  ),

                                  // Date
                                  if (report.createdAt != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Filed: ${report.createdAt!.toLocal().toString().split('.')[0]}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.5),
                                            fontSize: 11,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
