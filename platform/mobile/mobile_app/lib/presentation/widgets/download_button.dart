import 'package:flutter/material.dart';

class DownloadButton extends StatelessWidget {
  final bool isDownloading;
  final bool isDownloaded;
  final double downloadProgress;
  final VoidCallback? onDownload;
  final VoidCallback? onPlay;
  final bool showLabel;
  
  const DownloadButton({
    super.key,
    required this.isDownloading,
    required this.isDownloaded,
    this.downloadProgress = 0.0,
    this.onDownload,
    this.onPlay,
    this.showLabel = true,
  });
  
  @override
  Widget build(BuildContext context) {
    if (isDownloading) {
      return _buildDownloadingButton(context);
    }
    
    if (isDownloaded) {
      return _buildPlayButton(context);
    }
    
    return _buildDownloadButton(context);
  }
  
  Widget _buildDownloadingButton(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                value: downloadProgress,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
                strokeWidth: 2,
              ),
            ),
            Text(
              '${(downloadProgress * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            'Downloading',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
  
  Widget _buildPlayButton(BuildContext context) {
    return InkWell(
      onTap: onPlay,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_arrow,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 20,
            ),
          ),
          if (showLabel) ...[
            const SizedBox(height: 4),
            Text(
              'Play',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: Theme.of(context).colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildDownloadButton(BuildContext context) {
    return InkWell(
      onTap: onDownload,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.download,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          if (showLabel) ...[
            const SizedBox(height: 4),
            Text(
              'Download',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: Theme.of(context).colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}