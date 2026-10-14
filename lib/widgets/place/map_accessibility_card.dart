import 'package:flutter/material.dart';

import '../../models/osm_accessibility.dart';

class MapAccessibilityCard extends StatelessWidget {
  const MapAccessibilityCard({super.key, required this.tags});
  final Map<String, String> tags;

  @override
  Widget build(BuildContext context) {
    final data = OsmAccessibility(tags);
    final colors = Theme.of(context).colorScheme;
    final features = [
      ('Wheelchair access', Icons.accessible, data.wheelchair),
      ('Lift / elevator', Icons.elevator_outlined, data.elevator),
      ('Accessible toilet', Icons.wc, data.toilet),
      ('Accessible parking', Icons.local_parking, data.parking),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Accessibility features',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              for (var i = 0; i < features.length; i++) ...[
                if (i > 0) Divider(height: 1, color: colors.outlineVariant),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: colors.surfaceContainerLow,
                        child: Icon(
                          features[i].$2,
                          color: colors.primary,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(features[i].$1)),
                      const SizedBox(width: 8),
                      Flexible(child: _badge(context, features[i].$3)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (data.description?.trim().isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          Text(data.description!),
        ],
        const SizedBox(height: 8),
        Text(
          'Source: OpenStreetMap contributors. Reported details may be incomplete. '
          'Not confirmed means no clear information is recorded for this place.',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _badge(BuildContext context, OsmAccessStatus status) {
    final colors = Theme.of(context).colorScheme;
    final Color color;
    final IconData icon;
    switch (status) {
      case OsmAccessStatus.available:
        color = Colors.teal.shade800;
        icon = Icons.check_circle_outline;
      case OsmAccessStatus.limited:
        color = Colors.brown.shade700;
        icon = Icons.info_outline;
      case OsmAccessStatus.unavailable:
        color = colors.error;
        icon = Icons.cancel_outlined;
      case OsmAccessStatus.unknown:
        color = colors.onSurfaceVariant;
        icon = Icons.help_outline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              status.label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}