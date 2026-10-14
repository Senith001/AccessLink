import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/place_detail.dart';
import '../repositories/place_repository.dart';
import '../services/report_moderation_service.dart';

class AdminEditPlaceScreen extends StatefulWidget {
  final String placeId;
  final String placeName;
  final String? relatedReportId;
  final String? reportedTargetField;

  const AdminEditPlaceScreen({
    super.key,
    required this.placeId,
    required this.placeName,
    this.relatedReportId,
    this.reportedTargetField,
  });

  static Route<bool?> route({
    required String placeId,
    required String placeName,
    String? relatedReportId,
    String? reportedTargetField,
  }) {
    return MaterialPageRoute(
      builder: (_) => AdminEditPlaceScreen(
        placeId: placeId,
        placeName: placeName,
        relatedReportId: relatedReportId,
        reportedTargetField: reportedTargetField,
      ),
    );
  }

  @override
  State<AdminEditPlaceScreen> createState() => _AdminEditPlaceScreenState();
}

class _AdminEditPlaceScreenState extends State<AdminEditPlaceScreen> {
  final PlaceRepository _placeRepository = PlaceRepository();
  final ReportModerationService _reportService = ReportModerationService();

  PlaceDetail? _place;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Editable feature states
  final Map<String, bool> _availableMap = {};
  final Map<String, bool> _verifiedMap = {};
  final Map<String, TextEditingController> _notesControllers = {};
  final TextEditingController _adminNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPlace();
  }

  @override
  void dispose() {
    for (final c in _notesControllers.values) {
      c.dispose();
    }
    _adminNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadPlace() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!await _reportService.isUserStaff()) throw StateError('Staff access is required.');
      final place = await _placeRepository.getPlaceDetail(widget.placeId);
      if (place == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Place not found.';
        });
        return;
      }

      for (final key in PlaceDetail.featureOrder) {
        final feat = place.features[key];
        _availableMap[key] = feat?.available ?? false;
        _verifiedMap[key] = feat?.verified ?? false;
        _notesControllers[key] = TextEditingController(text: feat?.notes ?? '');
      }

      setState(() {
        _place = place;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load place: $e';
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_place == null) return;

    final adminNote = _adminNoteController.text.trim();
    if (widget.relatedReportId != null && adminNote.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an administrative resolution note.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (!await _reportService.isUserStaff()) throw StateError('Staff access is required.');
      // Recompute accessibility map and accessibility score
      final accessibilityMap = <String, dynamic>{};
      int availableCount = 0;
      bool anyVerified = false;

      for (final key in PlaceDetail.featureOrder) {
        final isAvailable = _availableMap[key] ?? false;
        final notes = _notesControllers[key]?.text.trim() ?? '';

        // If availability or notes changed from original and verified was true,
        // rule requires invalidating verification unless admin explicitly kept verified.
        final originalFeat = _place!.features[key];
        final changed =
            originalFeat == null ||
            originalFeat.available != isAvailable ||
            originalFeat.notes != notes;

        bool isVerified = _verifiedMap[key] ?? false;
        if (changed) {
          // Explicitly invalidated
          isVerified = false;
        }

        if (isAvailable) availableCount++;
        if (isVerified) anyVerified = true;

        accessibilityMap[key] = {
          'available': isAvailable,
          'notes': notes,
          'verified': isVerified,
          'lastUpdated': FieldValue.serverTimestamp(),
        };
      }

      final score = (availableCount / PlaceDetail.featureOrder.length * 100)
          .round();

      final updatedFields = <String, dynamic>{
        'accessibility': accessibilityMap,
        'accessibilityScore': score,
        'isVerified': anyVerified,
        'hasWheelchairAccess': _availableMap['wheelchairAccessible'] ?? false,
        'hasAccessibleToilet': _availableMap['accessibleToilet'] ?? false,
        'hasElevator': _availableMap['elevator'] ?? false,
        'hasAccessibleParking': _availableMap['accessibleParking'] ?? false,
        'hasTactilePaving': _availableMap['tactilePaving'] ?? false,
        'hasAudioSupport': _availableMap['audioSupport'] ?? false,
        'hasHearingSupport': _availableMap['hearingSupport'] ?? false,
      };

      if (widget.relatedReportId != null) {
        await _reportService.resolveReportWithPlaceUpdate(
          reportId: widget.relatedReportId!,
          placeId: widget.placeId,
          updatedPlaceFields: updatedFields,
          adminNotes: adminNote.isNotEmpty
              ? adminNote
              : 'Resolved with accessibility information update.',
        );
      } else {
        await _reportService.updatePlaceInformation(placeId: widget.placeId, updatedPlaceFields: updatedFields);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Place information saved.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save update: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Correct Place Information')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Place Title
                  Text(
                    _place!.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _place!.address,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (widget.reportedTargetField != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade800),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.flag, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Reported item: "${widget.reportedTargetField}". Please review and correct the corresponding feature below.',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  Text(
                    'Accessibility Features',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Changed details lose previous verification. Verify unchanged details only after checking evidence.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // List of 7 features
                  ...PlaceDetail.featureOrder.map((key) {
                    final label = PlaceDetail.featureLabels[key] ?? key;
                    final isAvailable = _availableMap[key] ?? false;
                    final isVerified = _verifiedMap[key] ?? false;
                    final controller = _notesControllers[key]!;

                    final isTarget =
                        widget.reportedTargetField != null &&
                        (widget.reportedTargetField!.toLowerCase().contains(
                              key.toLowerCase(),
                            ) ||
                            label.toLowerCase() ==
                                widget.reportedTargetField!.toLowerCase());

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isTarget
                              ? colorScheme.primary
                              : colorScheme.outline,
                          width: isTarget ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: isAvailable,
                                  onChanged: (val) {
                                    setState(() {
                                      _availableMap[key] = val;
                                      if (!val) {
                                        _verifiedMap[key] = false;
                                      }
                                    });
                                  },
                                ),
                                Text(
                                  isAvailable ? 'Available' : 'Unavailable',
                                  style: TextStyle(
                                    color: isAvailable
                                        ? Colors.green.shade800
                                        : Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                labelText: 'Notes for $label',
                                hintText:
                                    'e.g. Ramp slope, doorway width, location',
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Verified Accessibility',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: const Text(
                                'Check only if officially audited by staff inspection',
                                style: TextStyle(fontSize: 11),
                              ),
                              value: isVerified,
                              onChanged: (val) {
                                setState(
                                  () => _verifiedMap[key] = val ?? false,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  Text(
                    'Administrative Decision & Resolution Note',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _adminNoteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText:
                          'Explain the corrections made for audit history...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveChanges,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        _isSaving
                            ? 'Saving Corrections...'
                            : 'Save Corrections & Resolve Report',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
