import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final double average;
  final int count;

  const RatingStars({
    super.key,
    required this.average,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return Semantics(
        label: 'No ratings yet',
        child: Text(
          'No ratings yet',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    return Semantics(
      label: 'Rated ${average.toStringAsFixed(1)} out of 5, $count reviews',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Star rating display
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              final difference = average - index;
              
              IconData starIcon;
              if (difference >= 1) {
                starIcon = Icons.star;
              } else if (difference >= 0.5) {
                starIcon = Icons.star_half;
              } else {
                starIcon = Icons.star_border;
              }
              
              return Icon(
                starIcon,
                color: Colors.amber,
                size: 20,
              );
            }),
          ),
          const SizedBox(width: 8),
          // Rating text
          Text(
            '${average.toStringAsFixed(1)} ($count)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}