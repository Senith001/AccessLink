import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/place_detail.dart';
import '../models/submission.dart';
import '../repositories/submission_repository.dart';

class ProposeAccessibilityScreen extends StatefulWidget {
  final PlaceDetail place;

  const ProposeAccessibilityScreen({
    super.key,
    required this.place,
  });

  static Route<void> route({required PlaceDetail place}) {
    return MaterialPageRoute(
      builder: (_) => ProposeAccessibilityScreen(place: place),
    );
  }

  @override
  State<ProposeAccessibilityScreen> createState() => _ProposeAccessibilityScreenState();
}

class _ProposeAccessibilityScreenState extends State<ProposeAccessibilityScreen> {
  final SubmissionRepository _submissionRepository = SubmissionRepository();
  bool _isSubmitting = false;
  
  // Track changes to accessibility features
  final Map<String, bool> _changedAvailability = {};
  final Map<String, String> _changedNotes = {};
  final Map<String, TextEditingController> _notesControllers = {};

  static const Map<String, IconData> _iconMap = {
    'wheelchairAccessible': Icons.accessible,
    'accessibleToilet': Icons.wc,
    'elevator': Icons.elevator,
    'accessibleParking': Icons.local_parking,
    'tactilePaving': Icons.texture,
    'audioSupport': Icons.volume_up,
    'hearingSupport': Icons.hearing,
  };

  @override
  void initState() {
    super.initState();
    // Initialize controllers for all features
    for (final featureKey in PlaceDetail.featureOrder) {
      _notesControllers[featureKey] = TextEditingController(
        text: widget.place.features[featureKey]?.notes ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _notesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateAvailability(String featureKey, bool? available) {
    if (available == null) return;
    
    setState(() {
      final currentFeature = widget.place.features[featureKey];
      final currentAvailable = currentFeature?.available ?? false;
      
      if (available != currentAvailable) {
        _changedAvailability[featureKey] = available;
      } else {
        _changedAvailability.remove(featureKey);
      }
    });
  }

  void _updateNotes(String featureKey, String notes) {
    setState(() {
      final currentFeature = widget.place.features[featureKey];
      final currentNotes = currentFeature?.notes ?? '';
      
      if (notes.trim() != currentNotes.trim()) {
        _changedNotes[featureKey] = notes.trim();
      } else {
        _changedNotes.remove(featureKey);
      }
    });
  }

  bool get _hasChanges => _changedAvailability.isNotEmpty || _changedNotes.isNotEmpty;

  void _submitChanges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to submit accessibility updates')),
        );
      }
      return;
    }

    if (!_hasChanges) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No changes to submit')),
        );
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Build payload with changed features only
      final Map<String, Map<String, dynamic>> payload = {};
      
      // Collect all changed features
      final allChangedKeys = {..._changedAvailability.keys, ..._changedNotes.keys};
      
      for (final featureKey in allChangedKeys) {
        final currentFeature = widget.place.features[featureKey];
        final currentAvailable = currentFeature?.available ?? false;
        final currentNotes = currentFeature?.notes ?? '';
        
        payload[featureKey] = {
          'available': _changedAvailability[featureKey] ?? currentAvailable,
          'notes': _changedNotes[featureKey] ?? currentNotes,
        };
      }

      await _submissionRepository.createAccessibilitySubmission(
        placeId: widget.place.id,
        placeName: widget.place.name,
        kind: AccessibilityKind.update,
        payload: payload,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accessibility update submitted for review! Thank you for contributing.'),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to submit accessibility update';
        if (e is StateError) {
          errorMessage = e.toString().replaceFirst('StateError: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildFeatureTile(String featureKey) {
    final label = PlaceDetail.featureLabels[featureKey] ?? featureKey;
    final icon = _iconMap[featureKey] ?? Icons.help_outline;
    final currentFeature = widget.place.features[featureKey];
    final currentAvailable = currentFeature?.available ?? false;
    final isAvailabilityChanged = _changedAvailability.containsKey(featureKey);
    final isNotesChanged = _changedNotes.containsKey(featureKey);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Feature header with icon and label
            Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (isAvailabilityChanged || isNotesChanged)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Changed',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Current status
            Text(
              'Current: ${currentAvailable ? "Available" : "Not available"}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            
            // Availability toggle
            Row(
              children: [
                Text('Availability:', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 12),
                ToggleButtons(
                  isSelected: [
                    _changedAvailability[featureKey] == true || 
                    (!isAvailabilityChanged && currentAvailable),
                    _changedAvailability[featureKey] == false ||
                    (!isAvailabilityChanged && !currentAvailable),
                  ],
                  onPressed: (index) {
                    _updateAvailability(featureKey, index == 0);
                  },
                  borderRadius: BorderRadius.circular(8),
                  constraints: const BoxConstraints(minWidth: 70, minHeight: 36),
                  children: [
                    Text('Yes', style: Theme.of(context).textTheme.bodyMedium),
                    Text('No', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Notes field
            TextFormField(
              controller: _notesControllers[featureKey],
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Add details about this accessibility feature',
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (value) => _updateNotes(featureKey, value),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suggest Accessibility Update'),
        toolbarHeight: MediaQuery.textScalerOf(context).scale(22) + 32,
        actions: [
          TextButton(
            onPressed: _hasChanges && !_isSubmitting ? _submitChanges : null,
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              widget.place.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Help improve accessibility information for this place. Only submit changes that you are confident about.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            
            // Accessibility features
            ...PlaceDetail.featureOrder.map((featureKey) => _buildFeatureTile(featureKey)),
            
            const SizedBox(height: 24),
            
            // Submit button (also available at bottom)
            if (_hasChanges)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitChanges,
                  child: _isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Submitting...'),
                          ],
                        )
                      : const Text('Submit Changes'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}