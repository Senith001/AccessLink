import 'package:flutter/material.dart';

import '../../models/review.dart';
import '../../services/rating_review_service.dart';
import 'rating_selector.dart';

class WriteReviewDialog extends StatefulWidget {
  final String placeId;
  final String placeName;
  final Review? existingReview;

  const WriteReviewDialog({
    super.key,
    required this.placeId,
    required this.placeName,
    this.existingReview,
  });

  static Future<Review?> show(
    BuildContext context, {
    required String placeId,
    required String placeName,
    Review? existingReview,
  }) {
    return showDialog<Review>(
      context: context,
      builder: (_) => WriteReviewDialog(
        placeId: placeId,
        placeName: placeName,
        existingReview: existingReview,
      ),
    );
  }

  @override
  State<WriteReviewDialog> createState() => _WriteReviewDialogState();
}

class _WriteReviewDialogState extends State<WriteReviewDialog> {
  final RatingReviewService _service = RatingReviewService();
  final TextEditingController _controller = TextEditingController();
  late int _rating;
  bool _isSubmitting = false;
  String? _errorMessage;

  static const int _maxCharacters = 2000;

  @override
  void initState() {
    super.initState();
    _rating = widget.existingReview?.rating ?? 5;
    if (widget.existingReview != null) {
      _controller.text = widget.existingReview!.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final trimmedText = _controller.text.trim();

    if (_rating < 1 || _rating > 5) {
      setState(() => _errorMessage = 'Please select a star rating (1 to 5).');
      return;
    }

    if (trimmedText.isEmpty) {
      setState(
        () => _errorMessage = 'Please write a review before submitting.',
      );
      return;
    }

    if (trimmedText.length > _maxCharacters) {
      setState(
        () =>
            _errorMessage = 'Review cannot exceed $_maxCharacters characters.',
      );
      return;
    }

    if (_service.currentUser == null) {
      setState(
        () =>
            _errorMessage = 'Please sign in to write an accessibility review.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final savedReview = await _service.submitReview(
        placeId: widget.placeId,
        rating: _rating,
        text: trimmedText,
      );

      if (!mounted) return;

      Navigator.of(context).pop(savedReview);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingReview != null
                ? 'Your review has been updated!'
                : 'Thank you for sharing your accessibility feedback!',
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
    final colorScheme = theme.colorScheme;
    final isEditing = widget.existingReview != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Row(
                children: [
                  Icon(
                    isEditing ? Icons.rate_review : Icons.edit_note,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Review' : 'Write Accessibility Review',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.placeName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              // Rating selector
              Text(
                'Accessibility Rating',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 16),

              // Guidance Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Helpful details to include: step-free entrances, door width, ramps, elevators, accessible restrooms, tactile paving, sensory conditions, or staff helpfulness.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.85),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Review Input
              Text(
                'Your Accessibility Feedback',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                maxLines: 5,
                maxLength: _maxCharacters,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Share your personal experience regarding the accessibility of this location...',
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReview,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEditing ? 'Update Review' : 'Submit Review'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
