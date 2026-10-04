import 'package:flutter/material.dart';
import '../../models/place_detail.dart';

class OpeningHoursTile extends StatelessWidget {
  final Map<String, DayHours> openingHours;

  const OpeningHoursTile({
    super.key,
    required this.openingHours,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentWeekday = DateTime.now().weekday;
    
    // Map Flutter's weekday to our day names
    final dayNames = [
      'monday',    // 1
      'tuesday',   // 2
      'wednesday', // 3
      'thursday',  // 4
      'friday',    // 5
      'saturday',  // 6
      'sunday',    // 7
    ];

    if (openingHours.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 20,
                  color: colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Text(
                  'Opening hours',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Opening hours not available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 20,
                color: colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Text(
                'Opening hours',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Days list
          Column(
            children: dayNames.asMap().entries.map((entry) {
              final index = entry.key;
              final dayKey = entry.value;
              final isToday = (index + 1) == currentWeekday;
              final dayHours = openingHours[dayKey] ?? const DayHours(
                open: '',
                close: '',
                closed: true,
              );
              
              // Capitalize first letter of day name
              final displayDay = dayKey[0].toUpperCase() + dayKey.substring(1);
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      displayDay,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday 
                          ? colorScheme.primary 
                          : colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      dayHours.display,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday 
                          ? colorScheme.primary 
                          : colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}