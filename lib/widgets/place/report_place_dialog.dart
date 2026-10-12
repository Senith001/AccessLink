import 'package:flutter/material.dart';

import '../../models/accessibility_report.dart';
import '../../services/report_moderation_service.dart';

class ReportPlaceDialog extends StatefulWidget {
  final String placeId;
  final String placeName;

  const ReportPlaceDialog({
    super.key,
    required this.placeId,
    required this.placeName,
  });

  static Future<AccessibilityReport?> show(
    BuildContext context, {
    required String placeId,
    required String placeName,
  }) {
    return showDialog<AccessibilityReport>(
      context: context,
      builder: (_) => ReportPlaceDialog(placeId: placeId, placeName: placeName),
    );
  }

  @override
  State<ReportPlaceDialog> createState() => _ReportPlaceDialogState();
}

class _ReportPlaceDialogState extends State<ReportPlaceDialog> {
  final ReportModerationService _reportService = ReportModerationService();
  final TextEditingController _reasonController = TextEditingController();

  String _selectedCategory = 'incorrect_accessibility';
  String _selectedTarget = 'Wheelchair Accessible';
  bool _isSubmitting = false;
  String? _errorMessage;

  static const List<Map<String, String>> _categories = [
    {
      'id': 'incorrect_accessibility',
      'label': 'Incorrect accessibility details',
      'description':
          'Features listed as available are missing, broken, or inaccurate',
    },
    {
      'id': 'outdated_info',
      'label': 'Outdated information',
      'description': 'Hours, contact details, or location have changed',
    },
    {
      'id': 'inappropriate_content',
      'label': 'Inappropriate content',
      'description': 'Offensive photos, spam, or false reviews',
    },
    {
      'id': 'other',
      'label': 'Other',
      'description': 'Other accessibility-related issues',
    },
  ];

  static const List<String> _targetFields = [
    'Wheelchair Accessible',
    'Accessible Toilet',
    'Elevator',
    'Accessible Parking',
    'Tactile Paving',
    'Audio Support',
    'Hearing Support',
    'Opening Hours',
    'Contact Information',
    'General Information',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final trimmedReason = _reasonController.text.trim();

    if (trimmedReason.isEmpty) {
      setState(
        () => _errorMessage = 'Please explain what information is incorrect.',
      );
      return;
    }

    if (trimmedReason.length > 2000) {
      setState(() => _errorMessage = 'Reason cannot exceed 2,000 characters.');
      return;
    }

    if (_reportService.currentUser == null) {
      setState(
        () =>
            _errorMessage = 'Please sign in to report inaccurate information.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final report = await _reportService.submitReport(
        placeId: widget.placeId,
        placeName: widget.placeName,
        category: _selectedCategory,
        targetField: _selectedTarget,
        description: trimmedReason,
      );

      if (!mounted) return;

      Navigator.of(context).pop(report);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Report submitted! Our accessibility team will review your report.',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('StateError: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.report_problem_outlined, color: colorScheme.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Report Incorrect Information',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Place name indication
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.placeName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Category Selector
              Text(
                'Category',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: _categories.map((c) {
                  return DropdownMenuItem<String>(
                    value: c['id'],
                    child: Text(c['label']!),
                  );
                }).toList(),
                onChanged: _isSubmitting
                    ? null
                    : (val) {
                        if (val != null)
                          setState(() => _selectedCategory = val);
                      },
              ),
              const SizedBox(height: 16),

              // Target Feature
              Text(
                'Specific Feature / Field',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedTarget,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: _targetFields.map((field) {
                  return DropdownMenuItem<String>(
                    value: field,
                    child: Text(field),
                  );
                }).toList(),
                onChanged: _isSubmitting
                    ? null
                    : (val) {
                        if (val != null) setState(() => _selectedTarget = val);
                      },
              ),
              const SizedBox(height: 16),

              // Reason
              Text(
                'Reason for Report',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                maxLines: 4,
                maxLength: 2000,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  hintText: 'Describe the discrepancy or what accessibility information needs correction...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_errorMessage != null)
                    setState(() => _errorMessage = null);
                },
              ),

              // Privacy Notice
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your report is confidential and sent to administrators for moderation review. Place information remains unchanged until verified.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitReport,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      _isSubmitting ? 'Submitting...' : 'Submit Report',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
