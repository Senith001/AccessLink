import 'package:flutter/material.dart';
import '../../models/place_detail.dart';

class AccessibilityFeatureTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final AccessibilityFeature feature;

  const AccessibilityFeatureTile({
    super.key,
    required this.icon,
    required this.label,
    required this.feature,
  });

  Color _getStatusColor(BuildContext context, bool isHighContrast) {
    if (feature.available) {
      return isHighContrast 
        ? const Color(0xFF1B5E20) // Darker green for high contrast
        : Colors.green;
    } else {
      return isHighContrast 
        ? const Color(0xFFE65100) // Darker amber for high contrast
        : Colors.amber;
    }
  }

  String _getStatusText() {
    if (feature.available) {
      return feature.verified ? 'Available' : 'Available (unverified)';
    } else {
      return 'Not available';
    }
  }

  IconData _getStatusIcon() {
    if (feature.available) {
      return Icons.check_circle;
    } else {
      return Icons.warning_amber_rounded;
    }
  }

  String _getSemanticLabel() {
    final baseText = '$label: ${feature.available ? "Available" : "Not available"}';
    final unverifiedText = (feature.available && !feature.verified) ? ', unverified' : '';
    final notesText = feature.notes.isNotEmpty ? '. ${feature.notes}' : '';
    
    return '$baseText$unverifiedText$notesText';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isHighContrast = MediaQuery.highContrastOf(context);
    final statusColor = _getStatusColor(context, isHighContrast);
    
    if (feature.notes.isNotEmpty) {
      // Expandable tile for features with notes
      return Semantics(
        label: _getSemanticLabel(),
        child: ExpansionTile(
          leading: Icon(
            icon,
            color: colorScheme.onSurface,
          ),
          title: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getStatusIcon(),
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                _getStatusText(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.expand_more),
            ],
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                feature.notes,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Static tile for features without notes
      return Semantics(
        label: _getSemanticLabel(),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: colorScheme.onSurface,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _getStatusIcon(),
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                _getStatusText(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}