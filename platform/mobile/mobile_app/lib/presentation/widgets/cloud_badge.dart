import 'package:flutter/material.dart';

class CloudBadge extends StatelessWidget {
  final bool isVisible;
  
  const CloudBadge({
    super.key,
    required this.isVisible,
  });
  
  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.cloud_download,
          color: Theme.of(context).colorScheme.onPrimary,
          size: 16,
        ),
      ),
    );
  }
}