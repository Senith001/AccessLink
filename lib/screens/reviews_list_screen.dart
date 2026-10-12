import 'package:flutter/material.dart';

import '../models/review.dart';
import '../repositories/review_repository.dart';
import '../widgets/place/write_review_dialog.dart';

class ReviewsListScreen extends StatefulWidget {
  final String placeId;
  final String? placeName;

  const ReviewsListScreen({super.key, required this.placeId, this.placeName});

  static Route<void> route({required String placeId, String? placeName}) {
    return MaterialPageRoute(
      builder: (_) => ReviewsListScreen(placeId: placeId, placeName: placeName),
    );
  }

  @override
  State<ReviewsListScreen> createState() => _ReviewsListScreenState();
}

class _ReviewsListScreenState extends State<ReviewsListScreen> {
  final ReviewRepository _reviewRepository = ReviewRepository();
  List<Review> _reviews = [];
  Review? _userReview;
  bool _isLoading = false;
  String? _errorMessage;
  final Set<String> _expandedReviews = {};

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reviews = await _reviewRepository.getReviewsForPlace(
        widget.placeId,
      );
      final userRev = await _reviewRepository.getUserReviewForPlace(
        widget.placeId,
      );
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _userReview = userRev;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load reviews. Please try again.';
      });
    }
  }

  Future<void> _handleWriteReview() async {
    final saved = await WriteReviewDialog.show(
      context,
      placeId: widget.placeId,
      placeName: widget.placeName ?? 'Place',
      existingReview: _userReview,
    );

    if (saved != null && mounted) {
      _loadReviews();
    }
  }

  String _formatRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildStarRow(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber.shade700,
          size: 18,
        );
      }),
    );
  }

  Widget _buildReviewCard(Review review) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isExpanded = _expandedReviews.contains(review.id);
    final isLong = review.text.length > 200;
    final displayText = (isLong && !isExpanded)
        ? '${review.text.substring(0, 200)}...'
        : review.text;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User name and star rating
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    review.userName.isNotEmpty
                        ? review.userName[0].toUpperCase()
                        : 'A',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName.isNotEmpty
                            ? review.userName
                            : 'Anonymous Contributor',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (review.createdAt != null)
                        Text(
                          _formatRelativeTime(review.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStarRow(review.rating),
              ],
            ),

            // Review text
            if (review.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                displayText,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              if (isLong)
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedReviews.remove(review.id);
                      } else {
                        _expandedReviews.add(review.id);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      isExpanded ? 'Read less' : 'Read more',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No reviews yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to share detailed feedback on ramps, doorways, restrooms, or auditory support!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _handleWriteReview,
              icon: const Icon(Icons.edit_note),
              label: const Text('Write First Review'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadReviews, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.placeName != null
        ? '${widget.placeName} Reviews'
        : 'Accessibility Reviews';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        toolbarHeight: MediaQuery.textScalerOf(context).scale(22) + 32,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Write a review',
            onPressed: _handleWriteReview,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleWriteReview,
        icon: const Icon(Icons.rate_review),
        label: Text(_userReview != null ? 'Edit Review' : 'Write Review'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorState()
          : _reviews.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadReviews,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: _reviews.length,
                itemBuilder: (context, index) {
                  return _buildReviewCard(_reviews[index]);
                },
              ),
            ),
    );
  }
}
