import 'package:flutter/material.dart';
import '../../../data/models/book_models.dart';

class BookReviewsSection extends StatelessWidget {
  final List<Review> reviews;
  final VoidCallback? onWriteReview;
  final double averageRating;
  final int totalReviews;

  const BookReviewsSection({
    super.key,
    required this.reviews,
    this.onWriteReview,
    this.averageRating = 0.0,
    this.totalReviews = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall rating header
          Row(
            children: [
              Text(
                averageRating.toStringAsFixed(1),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRatingStars(averageRating),
                    const SizedBox(height: 4),
                    Text(
                      '$totalReviews reviews',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (onWriteReview != null)
                ElevatedButton(
                  onPressed: onWriteReview,
                  child: const Text('Write Review'),
                ),
            ],
          ),
          const SizedBox(height: 32),

          // Reviews list
          if (reviews.isNotEmpty) ...[
            Text(
              'Recent Reviews',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ...reviews.map((review) => ReviewCard(review: review)),
          ] else
            _buildEmptyReviewsState(context),
        ],
      ),
    );
  }

  Widget _buildEmptyReviewsState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No reviews yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to review this audiobook',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final fillValue = (rating - index).clamp(0.0, 1.0);
        if (fillValue >= 1.0) {
          return const Icon(
            Icons.star,
            size: 16,
            color: Colors.amber,
          );
        } else if (fillValue > 0.0) {
          return const Icon(
            Icons.star_half,
            size: 16,
            color: Colors.amber,
          );
        } else {
          return Icon(
            Icons.star_border,
            size: 16,
            color: Colors.grey.shade400,
          );
        }
      }),
    );
  }
}

class ReviewCard extends StatelessWidget {
  final Review review;

  const ReviewCard({
    super.key,
    required this.review,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  review.userName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _buildRatingStars(review.rating),
                const SizedBox(width: 8),
                Text(
                  _formatDate(review.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (review.comment?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                review.comment!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final fillValue = (rating - index).clamp(0.0, 1.0);
        if (fillValue >= 1.0) {
          return const Icon(
            Icons.star,
            size: 16,
            color: Colors.amber,
          );
        } else if (fillValue > 0.0) {
          return const Icon(
            Icons.star_half,
            size: 16,
            color: Colors.amber,
          );
        } else {
          return Icon(
            Icons.star_border,
            size: 16,
            color: Colors.grey.shade400,
          );
        }
      }),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return '${date.month}/${date.day}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else {
      return 'Just now';
    }
  }
}
