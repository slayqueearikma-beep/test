import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Safe network image with placeholder for empty/failed URLs.
class NetworkImageView extends StatelessWidget {
  const NetworkImageView({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.image_outlined,
  });

  final String url;
  final BoxFit fit;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return ColoredBox(
        color: AppColors.primary.withValues(alpha: 0.08),
        child: Icon(placeholderIcon, color: AppColors.primary, size: 40),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      errorWidget: (_, __, ___) => ColoredBox(
        color: AppColors.primary.withValues(alpha: 0.08),
        child: Icon(placeholderIcon, color: AppColors.primary, size: 40),
      ),
    );
  }
}
