import 'package:flutter/material.dart';
import '../../../data/models/book_models.dart';

class BookInfoSection extends StatelessWidget {
  final DetailedBook book;
  final bool isPurchased;
  final VoidCallback? onAuthorTap;

  const BookInfoSection({
    super.key,
    required this.book,
    required this.isPurchased,
    this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            book.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Author
          InkWell(
            onTap: onAuthorTap,
            child: Text(
              'by ${book.author}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Rating and reviews
          if (book.reviews.isNotEmpty) ...[
            Row(
              children: [
                _buildRatingStars(_calculateAverageRating()),
                const SizedBox(width: 8),
                Text(
                  '${_calculateAverageRating().toStringAsFixed(1)} (${book.reviews.length} reviews)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          
          // Metadata chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (book.totalDuration != null)
                _buildMetadataChip(context, 'Duration', _formatDuration(book.totalDuration!)),
              _buildMetadataChip(context, 'Chapters', '${book.chapters.length}'),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Price info
          if (!isPurchased) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '1 Credit', // Default to 1 credit since DetailedBook doesn't have creditPrice
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'or \$${book.priceUsd.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'In Your Library',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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

  Widget _buildMetadataChip(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  double _calculateAverageRating() {
    if (book.reviews.isEmpty) return 0.0;
    
    double totalRating = 0.0;
    for (final review in book.reviews) {
      // Assuming Review has a rating property
      totalRating += review.rating ?? 5.0;
    }
    return totalRating / book.reviews.length;
  }

  String _formatDuration(int durationInSeconds) {
    final hours = durationInSeconds ~/ 3600;
    final minutes = (durationInSeconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}