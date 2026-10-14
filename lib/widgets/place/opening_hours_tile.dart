import 'package:flutter/material.dart';
import '../../models/place_detail.dart';

class OpeningHoursTile extends StatefulWidget {
  final Map<String, DayHours> openingHours;

  const OpeningHoursTile({
    super.key,
    required this.openingHours,
  });

  @override
  State<OpeningHoursTile> createState() => _OpeningHoursTileState();
}

class _OpeningHoursTileState extends State<OpeningHoursTile> {
  bool _isExpanded = false;

  // Map Flutter's weekday to our day names
  static const dayNames = [
    'monday',    // 1
    'tuesday',   // 2
    'wednesday', // 3
    'thursday',  // 4
    'friday',    // 5
    'saturday',  // 6
    'sunday',    // 7
  ];

  String _getCurrentStatus() {
    if (widget.openingHours.isEmpty) return 'Closed';

    final now = DateTime.now();
    final currentWeekday = now.weekday;
    final todayKey = dayNames[currentWeekday - 1];
    final todayHours = widget.openingHours[todayKey];

    if (todayHours == null || todayHours.closed || todayHours.open.isEmpty || todayHours.close.isEmpty) {
      return 'Closed';
    }

    try {
      // Handle special case for 24/7 operations
      if (todayHours.open == '00:00' && todayHours.close == '23:59') {
        return 'Open';
      }

      // Parse open and close times
      final openParts = todayHours.open.split(':');
      final closeParts = todayHours.close.split(':');
      
      if (openParts.length != 2 || closeParts.length != 2) {
        return 'Closed'; // Invalid format
      }

      final openMinutes = int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
      final closeMinutes = int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);
      final nowMinutes = now.hour * 60 + now.minute;

      // Check if currently open
      if (openMinutes <= closeMinutes) {
        // Same day hours (e.g., 09:00 - 17:00)
        return (nowMinutes >= openMinutes && nowMinutes <= closeMinutes) ? 'Open' : 'Closed';
      } else {
        // Overnight hours (e.g., 22:00 - 02:00)
        return (nowMinutes >= openMinutes || nowMinutes <= closeMinutes) ? 'Open' : 'Closed';
      }
    } catch (e) {
      // Parsing error, default to closed
      return 'Closed';
    }
  }

  Color _getStatusColor(BuildContext context, String status) {
    final colorScheme = Theme.of(context).colorScheme;
    final isHighContrast = MediaQuery.highContrastOf(context);
    
    if (status == 'Open') {
      return isHighContrast 
          ? const Color(0xFF1B5E20) // Dark green for high contrast
          : Colors.green;
    } else {
      return isHighContrast 
          ? colorScheme.onSurface.withValues(alpha: 0.8)
          : Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentWeekday = DateTime.now().weekday;

    if (widget.openingHours.isEmpty) {
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

    final status = _getCurrentStatus();
    final statusColor = _getStatusColor(context, status);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with tap area
          Semantics(
            button: true,
            label: 'Opening hours, currently $status, tap to ${_isExpanded ? 'collapse' : 'expand'}',
            child: InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.all(16),
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
                        Expanded(
                          child: Text(
                            'Opening hours',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Status line
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          status,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Expandable content
          if (_isExpanded) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: dayNames.asMap().entries.map((entry) {
                  final index = entry.key;
                  final dayKey = entry.value;
                  final isToday = (index + 1) == currentWeekday;
                  final dayHours = widget.openingHours[dayKey] ?? const DayHours(
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
            ),
          ],
        ],
      ),
    );
  }
}