import 'package:flutter/material.dart';

class RatingSelector extends StatelessWidget {
  final int currentRating;
  final ValueChanged<int> onRatingChanged;
  final bool enabled;

  const RatingSelector({
    super.key,
    required this.currentRating,
    required this.onRatingChanged,
    this.enabled = true,
  });

  static const List<String> _ratingDescriptions = [
    'Not selected',
    '1 - Very Poor Accessibility',
    '2 - Poor Accessibility',
    '3 - Average Accessibility',
    '4 - Good Accessibility',
    '5 - Excellent Accessibility',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isHighContrast = MediaQuery.highContrastOf(context);

    final description = currentRating >= 1 && currentRating <= 5
        ? _ratingDescriptions[currentRating]
        : 'Select an accessibility rating from 1 to 5 stars';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starNumber = index + 1;
            final isSelected = starNumber <= currentRating;

            return Semantics(
              button: true,
              enabled: enabled,
              label: 'Rate $starNumber out of 5 stars',
              selected: isSelected,
              child: InkWell(
                onTap: enabled ? () => onRatingChanged(starNumber) : null,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Icon(
                    isSelected ? Icons.star : Icons.star_border,
                    size: 40,
                    color: isSelected
                        ? (isHighContrast
                              ? const Color(0xFFB78103)
                              : Colors.amber.shade700)
                        : (isHighContrast
                              ? Colors.black
                              : Colors.grey.shade400),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: currentRating > 0
                  ? colorScheme.onSurface
                  : colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
