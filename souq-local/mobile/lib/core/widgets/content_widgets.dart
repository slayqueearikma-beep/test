import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'network_image_view.dart';

class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({
    super.key,
    required this.backgroundColor,
    required this.icon,
    this.secondaryIcon,
  });

  final Color backgroundColor;
  final IconData icon;
  final IconData? secondaryIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.illustrationRadius),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 40,
            right: 40,
            child: Icon(
              secondaryIcon ?? Icons.auto_awesome_rounded,
              size: 36,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
          Positioned(
            bottom: 36,
            left: 36,
            child: Icon(
              Icons.location_on_rounded,
              size: 28,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class SellerCard extends StatelessWidget {
  const SellerCard({
    super.key,
    required this.businessName,
    required this.description,
    required this.rating,
    required this.reviewCount,
    required this.city,
    this.imageUrl = '',
    this.achievementStars = 0,
    this.onTap,
    this.compact = false,
  });

  final String businessName;
  final String description;
  final double rating;
  final int reviewCount;
  final String city;
  final String imageUrl;
  final int achievementStars;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.symmetric(
        horizontal: compact ? 0 : AppSpacing.screenHorizontal,
        vertical: compact ? 0 : 6,
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: compact ? 100 : 140,
              width: double.infinity,
              child: NetworkImageView(url: imageUrl, placeholderIcon: Icons.storefront_rounded),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          businessName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (achievementStars > 0)
                        ...List.generate(
                          achievementStars.clamp(0, 3),
                          (_) => const Padding(
                            padding: EdgeInsets.only(left: 2),
                            child: Icon(Icons.star_rounded, size: 14, color: AppColors.star),
                          ),
                        ),
                    ],
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: AppColors.star),
                      const SizedBox(width: 4),
                      Text('$rating ($reviewCount)', style: const TextStyle(fontSize: 13)),
                      const Spacer(),
                      Text(city, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.trend,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? trend;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            Text(label, style: TextStyle(color: secondary, fontSize: 13)),
            if (trend != null) ...[
              const SizedBox(height: 4),
              Text(trend!, style: const TextStyle(color: AppColors.success, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class DashboardMenuTile extends StatelessWidget {
  const DashboardMenuTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.badge,
    this.comingSoon = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final String? badge;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: comingSoon ? null : onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (comingSoon) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(context.l10n.soon, style: const TextStyle(fontSize: 10, color: AppColors.warning)),
              ),
            ],
          ],
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        trailing: badge != null
            ? CircleAvatar(radius: 12, backgroundColor: AppColors.primary, child: Text(badge!, style: const TextStyle(fontSize: 10, color: Colors.white)))
            : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
