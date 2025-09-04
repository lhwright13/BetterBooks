/**
 * download_progress_widget.dart - Visual download progress indicators
 * 
 * This widget provides visual feedback for book downloads including:
 * - Circular progress indicators for individual downloads
 * - Multi-chapter progress breakdown
 * - Pause/resume/cancel controls
 * - Error state handling
 */

import 'package:flutter/material.dart';
import '../services/download_service.dart';
import '../theme/echowright_theme.dart';

/// Circular progress widget for book downloads
class DownloadProgressCircle extends StatelessWidget {
  final BookDownloadProgress progress;
  final double size;
  final bool showText;
  final VoidCallback? onTap;

  const DownloadProgressCircle({
    super.key,
    required this.progress,
    this.size = 48.0,
    this.showText = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background circle
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 3.0,
                backgroundColor: EchoWrightTheme.dividerDark,
                valueColor: AlwaysStoppedAnimation<Color>(
                  EchoWrightTheme.dividerDark,
                ),
              ),
            ),
            
            // Progress circle
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: progress.overallProgress,
                strokeWidth: 3.0,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getProgressColor(progress.overallStatus),
                ),
              ),
            ),
            
            // Center content
            _buildCenterContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterContent() {
    switch (progress.overallStatus) {
      case DownloadStatus.downloading:
        return showText
            ? Text(
                '${(progress.overallProgress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.w600,
                  color: EchoWrightTheme.textPrimary,
                ),
              )
            : Icon(
                Icons.download,
                size: size * 0.4,
                color: EchoWrightTheme.primaryTurquoise,
              );
      
      case DownloadStatus.completed:
        return Icon(
          Icons.check,
          size: size * 0.5,
          color: EchoWrightTheme.successColor,
        );
      
      case DownloadStatus.failed:
        return Icon(
          Icons.error,
          size: size * 0.4,
          color: EchoWrightTheme.errorColor,
        );
      
      case DownloadStatus.paused:
        return Icon(
          Icons.pause,
          size: size * 0.4,
          color: EchoWrightTheme.textSecondary,
        );
      
      case DownloadStatus.canceled:
        return Icon(
          Icons.close,
          size: size * 0.4,
          color: EchoWrightTheme.textSecondary,
        );
      
      default:
        return Icon(
          Icons.download,
          size: size * 0.4,
          color: EchoWrightTheme.textSecondary,
        );
    }
  }

  Color _getProgressColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return EchoWrightTheme.primaryTurquoise;
      case DownloadStatus.completed:
        return EchoWrightTheme.successColor;
      case DownloadStatus.failed:
        return EchoWrightTheme.errorColor;
      case DownloadStatus.paused:
        return EchoWrightTheme.textSecondary;
      case DownloadStatus.canceled:
        return EchoWrightTheme.textSecondary;
      default:
        return EchoWrightTheme.primaryTurquoise;
    }
  }
}

/// Detailed download progress view with chapter breakdown
class DetailedDownloadProgress extends StatelessWidget {
  final BookDownloadProgress progress;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;

  const DetailedDownloadProgress({
    super.key,
    required this.progress,
    this.onPause,
    this.onResume,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EchoWrightTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: EchoWrightTheme.dividerDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with book title and overall progress
          Row(
            children: [
              DownloadProgressCircle(
                progress: progress,
                size: 40,
                showText: false,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.bookTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: EchoWrightTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      _getStatusText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: EchoWrightTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildControlButtons(),
            ],
          ),
          
          if (progress.totalChapters > 1) ...[
            SizedBox(height: 16),
            
            // Chapter breakdown
            Text(
              'Chapters (${progress.completedChapters}/${progress.totalChapters})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: EchoWrightTheme.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            
            // Chapter progress list
            ...progress.chapterProgresses.take(5).map((chapter) => 
              Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      _getChapterStatusIcon(chapter.status),
                      size: 16,
                      color: _getProgressColor(chapter.status),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chapter.chapterTitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: EchoWrightTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (chapter.status == DownloadStatus.downloading)
                      Text(
                        '${(chapter.progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: EchoWrightTheme.primaryTurquoise,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            if (progress.chapterProgresses.length > 5)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '... and ${progress.chapterProgresses.length - 5} more chapters',
                  style: TextStyle(
                    fontSize: 11,
                    color: EchoWrightTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (progress.isDownloading && onPause != null)
          IconButton(
            onPressed: onPause,
            icon: Icon(Icons.pause, size: 20),
            color: EchoWrightTheme.textSecondary,
            padding: EdgeInsets.all(4),
            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        
        if (progress.isPaused && onResume != null)
          IconButton(
            onPressed: onResume,
            icon: Icon(Icons.play_arrow, size: 20),
            color: EchoWrightTheme.primaryTurquoise,
            padding: EdgeInsets.all(4),
            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        
        if (!progress.isCompleted && onCancel != null)
          IconButton(
            onPressed: onCancel,
            icon: Icon(Icons.close, size: 20),
            color: EchoWrightTheme.errorColor,
            padding: EdgeInsets.all(4),
            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
          ),
      ],
    );
  }

  String _getStatusText() {
    switch (progress.overallStatus) {
      case DownloadStatus.downloading:
        return 'Downloading... ${(progress.overallProgress * 100).toInt()}%';
      case DownloadStatus.completed:
        return 'Downloaded';
      case DownloadStatus.failed:
        return 'Download failed';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.canceled:
        return 'Canceled';
      default:
        return 'Pending';
    }
  }

  IconData _getChapterStatusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.completed:
        return Icons.check_circle;
      case DownloadStatus.downloading:
        return Icons.download;
      case DownloadStatus.failed:
        return Icons.error;
      case DownloadStatus.paused:
        return Icons.pause_circle;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  Color _getProgressColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return EchoWrightTheme.primaryTurquoise;
      case DownloadStatus.completed:
        return EchoWrightTheme.successColor;
      case DownloadStatus.failed:
        return EchoWrightTheme.errorColor;
      case DownloadStatus.paused:
        return EchoWrightTheme.textSecondary;
      case DownloadStatus.canceled:
        return EchoWrightTheme.textSecondary;
      default:
        return EchoWrightTheme.primaryTurquoise;
    }
  }
}

/// Simple download button that transforms to progress indicator
class DownloadButton extends StatelessWidget {
  final String bookId;
  final VoidCallback onDownload;
  final DownloadService downloadService;

  const DownloadButton({
    super.key,
    required this.bookId,
    required this.onDownload,
    required this.downloadService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: downloadService,
      builder: (context, child) {
        final progress = downloadService.getBookProgress(bookId);
        
        if (progress == null) {
          // Show download button
          return IconButton(
            onPressed: onDownload,
            icon: Icon(Icons.download),
            color: EchoWrightTheme.primaryTurquoise,
            tooltip: 'Download for offline listening',
          );
        } else {
          // Show progress
          return DownloadProgressCircle(
            progress: progress,
            size: 36,
            showText: false,
            onTap: () => _showDownloadDetails(context, progress),
          );
        }
      },
    );
  }

  void _showDownloadDetails(BuildContext context, BookDownloadProgress progress) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: EdgeInsets.all(16),
        child: DetailedDownloadProgress(
          progress: progress,
          onPause: () async {
            await downloadService.pauseDownload(progress.bookId);
            Navigator.pop(context);
          },
          onResume: () async {
            // Restart download
            Navigator.pop(context);
          },
          onCancel: () async {
            await downloadService.cancelDownload(progress.bookId);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}