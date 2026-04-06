import 'package:flutter/material.dart';

/// Reusable bookmark icon button — theme-aware
class BookmarkButton extends StatelessWidget {
  final bool isBookmarked;
  final VoidCallback onPressed;

  const BookmarkButton({
    super.key,
    required this.isBookmarked,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return IconButton(
      icon: Icon(
        isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        color: isBookmarked ? cs.secondary : cs.onSurfaceVariant,
      ),
      onPressed: onPressed,
      tooltip: isBookmarked ? 'Remove bookmark' : 'Add bookmark',
    );
  }
}
