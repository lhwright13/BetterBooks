/// Enhanced book details screen with full purchase and preview functionality

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/bookstore_models.dart';
import '../models/persona.dart';
import '../providers/auth_provider.dart';
import '../services/bookstore_adapter.dart';
import '../services/api_service.dart';
import '../theme/echowright_theme.dart';
import '../widgets/smart_cover_image.dart';

class BookDetailsScreen extends StatefulWidget {
  final BookCatalog book;

  const BookDetailsScreen({Key? key, required this.book}) : super(key: key);

  @override
  _BookDetailsScreenState createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  bool _isLoading = false;
  bool _isPurchased = false;
  bool _isPlayingPreview = false;
  List<Persona> _personas = [];
  CreditBalanceResponse? _creditBalance;
  final AudioPlayer _previewPlayer = AudioPlayer();
  
  @override
  void initState() {
    super.initState();
    _loadBookData();
    _setupPreviewPlayer();
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  void _setupPreviewPlayer() {
    _previewPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlayingPreview = state == PlayerState.playing;
      });
    });
  }

  Future<void> _loadBookData() async {
    setState(() => _isLoading = true);
    
    try {
      final bookstoreAdapter = BookstoreAdapter();
      
      // Load personas for this book
      try {
        _personas = await ApiService.getPersonas();
      } catch (e) {
        // If API fails, use empty list for now
        _personas = [];
      }
      
      // Load credit balance
      _creditBalance = await bookstoreAdapter.getCreditBalance();
      
      // Check if book is already purchased
      final userLibrary = await bookstoreAdapter.getUserLibrary('mock-user-id');
      _isPurchased = userLibrary.any((book) => book.id == widget.book.id);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading book data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _playPreview() async {
    if (_isPlayingPreview) {
      await _previewPlayer.pause();
    } else {
      // For mock, play a sample audio or show a mock preview
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎧 Playing preview... (Mock audio preview)'),
          duration: Duration(seconds: 3),
        ),
      );
      
      // Simulate preview playback
      setState(() => _isPlayingPreview = true);
      await Future.delayed(const Duration(seconds: 3));
      setState(() => _isPlayingPreview = false);
    }
  }

  Future<void> _purchaseBook() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to purchase books')),
      );
      return;
    }

    // Show purchase confirmation dialog
    final confirm = await _showPurchaseDialog();
    if (!confirm) return;

    setState(() => _isLoading = true);
    
    try {
      final bookstoreAdapter = BookstoreAdapter();
      final response = await bookstoreAdapter.purchaseBook(
        bookId: widget.book.id,
        paymentMethod: PurchaseType.credit,
        creditsToUse: widget.book.creditPrice,
      );

      if (response.success) {
        setState(() => _isPurchased = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully purchased "${widget.book.title}"!'),
            backgroundColor: EchoWrightTheme.successColor,
          ),
        );
        
        // Reload credit balance
        _creditBalance = await bookstoreAdapter.getCreditBalance();
      } else {
        throw Exception('Purchase failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchase failed: $e'),
          backgroundColor: EchoWrightTheme.errorColor,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showPurchaseDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EchoWrightTheme.surfaceDark,
        title: Text(
          'Purchase Book',
          style: TextStyle(color: EchoWrightTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Purchase "${widget.book.title}" for ${widget.book.creditPrice} credit?',
              style: TextStyle(color: EchoWrightTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            if (_creditBalance != null)
              Text(
                'Available Credits: ${_creditBalance!.availableCredits}',
                style: TextStyle(
                  color: _creditBalance!.availableCredits >= widget.book.creditPrice
                      ? EchoWrightTheme.successColor
                      : EchoWrightTheme.errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: EchoWrightTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: (_creditBalance?.availableCredits ?? 0) >= widget.book.creditPrice
                ? () => Navigator.of(context).pop(true)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: EchoWrightTheme.primaryCoral,
            ),
            child: const Text('Purchase', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EchoWrightTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: EchoWrightTheme.backgroundDark,
        foregroundColor: EchoWrightTheme.textPrimary,
        title: const Text('Book Details'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBookHeader(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                  const SizedBox(height: 32),
                  _buildDescription(),
                  const SizedBox(height: 32),
                  _buildBookInfo(),
                  const SizedBox(height: 32),
                  _buildPersonasSection(),
                  const SizedBox(height: 32),
                  _buildReviewsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildBookHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Book cover
        Container(
          width: 120,
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: EchoWrightTheme.surfaceDark,
          ),
          child: SmartCoverImageHelpers.fromBookCatalog(
            book: widget.book,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(8),
            errorWidget: Icon(
              Icons.book,
              size: 48,
              color: EchoWrightTheme.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 16),
        
        // Book details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.book.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: EchoWrightTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              if (widget.book.author != null)
                Text(
                  'by ${widget.book.author}',
                  style: TextStyle(
                    fontSize: 16,
                    color: EchoWrightTheme.textSecondary,
                  ),
                ),
              const SizedBox(height: 8),
              if (widget.book.narrator != null)
                Text(
                  'Narrated by ${widget.book.narrator}',
                  style: TextStyle(
                    fontSize: 14,
                    color: EchoWrightTheme.textMuted,
                  ),
                ),
              const SizedBox(height: 12),
              
              // Rating and duration
              Row(
                children: [
                  if (widget.book.averageRating != null) ...[
                    Icon(
                      Icons.star,
                      size: 16,
                      color: EchoWrightTheme.primaryCoral,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.book.averageRating!.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 14,
                        color: EchoWrightTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      ' (${widget.book.reviewCount})',
                      style: TextStyle(
                        fontSize: 14,
                        color: EchoWrightTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Text(
                    widget.book.formattedDuration,
                    style: TextStyle(
                      fontSize: 14,
                      color: EchoWrightTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Preview and Purchase buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _playPreview,
                icon: Icon(
                  _isPlayingPreview ? Icons.pause : Icons.play_arrow,
                  color: EchoWrightTheme.primaryTurquoise,
                ),
                label: Text(
                  _isPlayingPreview ? 'Pause Preview' : 'Preview',
                  style: TextStyle(color: EchoWrightTheme.primaryTurquoise),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: EchoWrightTheme.primaryTurquoise),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _isPurchased
                  ? ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to player screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Opening player...')),
                        );
                      },
                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                      label: const Text('Play', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EchoWrightTheme.successColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _purchaseBook,
                      icon: const Icon(Icons.shopping_cart, color: Colors.white),
                      label: Text(
                        '${widget.book.creditPrice} Credit${widget.book.creditPrice != 1 ? 's' : ''}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EchoWrightTheme.primaryCoral,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
            ),
          ],
        ),
        
        // Credit balance display
        if (_creditBalance != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: EchoWrightTheme.surfaceDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Credits:',
                  style: TextStyle(
                    color: EchoWrightTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${_creditBalance!.availableCredits} available',
                  style: TextStyle(
                    color: EchoWrightTheme.primaryTurquoise,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: EchoWrightTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.book.description ?? 'No description available.',
          style: TextStyle(
            fontSize: 16,
            color: EchoWrightTheme.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildBookInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Book Info',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: EchoWrightTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoRow('Price', widget.book.formattedPrice),
        _buildInfoRow('Duration', widget.book.formattedDuration),
        _buildInfoRow('Language', widget.book.language.toUpperCase()),
        if (widget.book.publisher != null)
          _buildInfoRow('Publisher', widget.book.publisher!),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: EchoWrightTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: EchoWrightTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonasSection() {
    if (_personas.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Personas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: EchoWrightTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chat with these AI characters about the book',
          style: TextStyle(
            fontSize: 14,
            color: EchoWrightTheme.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        
        ...(_personas.map((persona) => _buildPersonaCard(persona)).toList()),
      ],
    );
  }

  Widget _buildPersonaCard(Persona persona) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EchoWrightTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: EchoWrightTheme.primaryTurquoise.withOpacity(0.2),
                child: Icon(
                  Icons.person,
                  color: EchoWrightTheme.primaryTurquoise,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      persona.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: EchoWrightTheme.textPrimary,
                      ),
                    ),
                    Text(
                      persona.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: EchoWrightTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reviews',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: EchoWrightTheme.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Write review feature coming soon!')),
                );
              },
              child: Text(
                'Write Review',
                style: TextStyle(color: EchoWrightTheme.primaryTurquoise),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Mock review placeholder
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: EchoWrightTheme.surfaceDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ...List.generate(5, (index) => Icon(
                    Icons.star,
                    size: 16,
                    color: index < 4 ? EchoWrightTheme.primaryCoral : EchoWrightTheme.textMuted,
                  )),
                  const SizedBox(width: 8),
                  Text(
                    'BookLover123',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: EchoWrightTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Great narration and fascinating characters. The AI personas really helped me understand the deeper themes.',
                style: TextStyle(
                  fontSize: 14,
                  color: EchoWrightTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}