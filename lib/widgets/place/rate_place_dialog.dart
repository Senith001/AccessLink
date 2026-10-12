import 'package:flutter/material.dart';

import '../../models/review.dart';
import '../../services/rating_review_service.dart';
import 'rating_selector.dart';

class RatePlaceDialog extends StatefulWidget {
  final String placeId;
  final String placeName;
  final Review? existingReview;

  const RatePlaceDialog({
    super.key,
    required this.placeId,
    required this.placeName,
    this.existingReview,
  });

  static Future<RatingCalculationResult?> show(
    BuildContext context, {
    required String placeId,
    required String placeName,
    Review? existingReview,
  }) {
    return showDialog<RatingCalculationResult>(
      context: context,
      builder: (_) => RatePlaceDialog(
        placeId: placeId,
        placeName: placeName,
        existingReview: existingReview,
      ),
    );
  }

  @override
  State<RatePlaceDialog> createState() => _RatePlaceDialogState();
}

class _RatePlaceDialogState extends State<RatePlaceDialog> {
  final RatingReviewService _service = RatingReviewService();
  late int _rating;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _rating = widget.existingReview?.rating ?? 0;
  }

  Future<void> _submitRating() async {
    if (_rating < 1 || _rating > 5) {
      setState(() {
        _errorMessage = 'Please select a rating between 1 and 5 stars.';
      });
      return;
    }

    if (_service.currentUser == null) {
      setState(() {
        _errorMessage = 'Please sign in to rate this place.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.submitOrUpdateRating(
        placeId: widget.placeId,
        rating: _rating,
      );

      if (!mounted) return;

      Navigator.of(context).pop(result);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingReview != null
                ? 'Your rating has been updated!'
                : 'Thank you for your accessibility rating!',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUpdating = widget.existingReview != null;

    return AlertDialog(
      title: Text(
        isUpdating ? 'Update Accessibility Rating' : 'Rate Accessibility',
        style: theme.textTheme.titleLarge,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.placeName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'How accessible was your experience at this place? Your community rating helps others travel with confidence.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            RatingSelector(
              currentRating: _rating,
              onRatingChanged: (val) {
                setState(() {
                  _rating = val;
                  _errorMessage = null;
                });
              },
              enabled: !_isSubmitting,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting || _rating == 0 ? null : _submitRating,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isUpdating ? 'Update' : 'Submit Rating'),
        ),
      ],
    );
  }
}
