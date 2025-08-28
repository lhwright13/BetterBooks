import 'package:flutter/material.dart';
import '../services/cover_image_service.dart';
import '../services/log_service.dart';

/// Smart cover image widget that uses CoverImageService for intelligent fallbacks
/// 
/// This widget provides a unified way to display book covers throughout the app,
/// with intelligent fallback handling when backend images fail.
class SmartCoverImage extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final String? author;
  final String? backendCoverUrl;
  final String? isbn;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const SmartCoverImage({
    super.key,
    required this.bookId,
    required this.bookTitle,
    this.author,
    this.backendCoverUrl,
    this.isbn,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<SmartCoverImage> createState() => _SmartCoverImageState();
}

class _SmartCoverImageState extends State<SmartCoverImage> {
  String? _coverUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadCoverImage();
  }

  @override
  void didUpdateWidget(SmartCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Reload if key properties changed
    if (oldWidget.bookId != widget.bookId ||
        oldWidget.backendCoverUrl != widget.backendCoverUrl) {
      _loadCoverImage();
    }
  }

  Future<void> _loadCoverImage() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final coverUrl = await CoverImageService.getCoverImageUrl(
        bookId: widget.bookId,
        bookTitle: widget.bookTitle,
        author: widget.author,
        backendCoverUrl: widget.backendCoverUrl,
        isbn: widget.isbn,
      );

      if (mounted) {
        setState(() {
          _coverUrl = coverUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      LogService.error('Failed to load cover image: $e', 'SmartCoverImage');
      
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildFallbackIcon() {
    return widget.errorWidget ?? Icon(
      Icons.book,
      size: (widget.width ?? widget.height ?? 80) * 0.4,
      color: Colors.grey.shade400,
    );
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ?? Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Colors.grey.shade400,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (_isLoading) {
      child = _buildPlaceholder();
    } else if (_hasError || _coverUrl == null) {
      child = _buildFallbackIcon();
    } else {
      child = Image.network(
        _coverUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          LogService.debug('Image.network failed for URL: $_coverUrl', 'SmartCoverImage');
          return _buildFallbackIcon();
        },
      );
    }

    // Apply container styling if dimensions or border radius specified
    if (widget.width != null || widget.height != null || widget.borderRadius != null) {
      child = Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
        ),
        clipBehavior: widget.borderRadius != null ? Clip.antiAlias : Clip.none,
        child: child,
      );
    }

    return child;
  }
}

/// Extension to make SmartCoverImage easier to use with different book model types
extension SmartCoverImageHelpers on SmartCoverImage {
  /// Create a SmartCoverImage from a BookCatalog model
  static SmartCoverImage fromBookCatalog({
    required dynamic book,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return SmartCoverImage(
      bookId: book.id ?? book.title ?? 'unknown',
      bookTitle: book.title ?? 'Unknown Title',
      author: book.author,
      backendCoverUrl: book.coverImageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }

  /// Create a SmartCoverImage from a Book model  
  static SmartCoverImage fromBook({
    required dynamic book,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return SmartCoverImage(
      bookId: book.id ?? book.title ?? 'unknown',
      bookTitle: book.title ?? 'Unknown Title',
      author: book.author,
      backendCoverUrl: book.coverUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}