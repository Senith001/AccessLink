import 'package:flutter/material.dart';

class PlaceActionButtons extends StatelessWidget {
  final VoidCallback onGetRoute;
  final VoidCallback onReadReviews;

  const PlaceActionButtons({
    super.key,
    required this.onGetRoute,
    required this.onReadReviews,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Get Accessible Route - Primary button
        Semantics(
          button: true,
          label: 'Get accessible route to this place',
          child: ElevatedButton.icon(
            onPressed: onGetRoute,
            icon: const Icon(Icons.directions),
            label: const Text('Get Accessible Route'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Read Reviews - Secondary button
        Semantics(
          button: true,
          label: 'Read reviews for this place',
          child: OutlinedButton.icon(
            onPressed: onReadReviews,
            icon: const Icon(Icons.rate_review),
            label: const Text('Read Reviews'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.primary),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}