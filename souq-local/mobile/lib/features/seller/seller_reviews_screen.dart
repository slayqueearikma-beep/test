import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../l10n/app_localizations.dart';
import 'seller_account_provider.dart';

class SellerReviewsScreen extends ConsumerWidget {
  const SellerReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final accountAsync = ref.watch(sellerAccountProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviews)),
      body: accountAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(sellerAccountProvider),
        ),
        data: (account) =>
            _ReviewsBody(sellerId: account.profile.id, stats: account.stats),
      ),
    );
  }
}

class _ReviewsBody extends ConsumerStatefulWidget {
  const _ReviewsBody({required this.sellerId, required this.stats});

  final String sellerId;
  final SellerDashboardStats stats;

  @override
  ConsumerState<_ReviewsBody> createState() => _ReviewsBodyState();
}

class _ReviewsBodyState extends ConsumerState<_ReviewsBody> {
  late Future<List<ReviewModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = apiServiceProvider.fetchReviews(widget.sellerId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = apiServiceProvider.fetchReviews(widget.sellerId);
    });
    await _future;
    ref.invalidate(sellerAccountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<List<ReviewModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AsyncErrorView.fromError(
            snapshot.error!,
            onRetry: () => _reload(),
          );
        }

        final reviews = snapshot.data ?? [];
        if (reviews.isEmpty) {
          return Center(child: Text(l10n.noReviewsYet));
        }

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: AppColors.star, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        widget.stats.averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Text(l10n.reviewsCount(widget.stats.reviewCount)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...reviews.map((review) {
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            review.buyerDisplayName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          review.overallRating.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 4),
                        ...List.generate(
                          review.rating.clamp(0, 5),
                          (_) => const Icon(Icons.star_rounded,
                              size: 14, color: AppColors.star),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '${l10n.ratingProductQuality} ${review.productQuality}/5 · '
                          '${l10n.ratingCustomerService} ${review.customerService}/5 · '
                          '${l10n.ratingCommunication} ${review.communication}/5 · '
                          '${l10n.ratingTrustworthiness} ${review.trustworthiness}/5',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        if (review.comment.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(review.comment),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          review.createdAt.length >= 10
                              ? review.createdAt.substring(0, 10)
                              : review.createdAt,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotificationModel>>((ref) {
  return apiServiceProvider.fetchNotifications();
});

class SellerNotificationsScreen extends ConsumerWidget {
  const SellerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications),
        actions: [
          TextButton(
            onPressed: () async {
              await apiServiceProvider.markAllNotificationsRead();
              ref.invalidate(notificationsProvider);
            },
            child: Text(l10n.markAllRead),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.noNotifications,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.notificationsSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    onTap: item.isRead
                        ? null
                        : () async {
                            await apiServiceProvider
                                .markNotificationRead(item.id);
                            ref.invalidate(notificationsProvider);
                          },
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                      child: Icon(_notificationIcon(item.kind),
                          color: AppColors.primary),
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                          fontWeight:
                              item.isRead ? FontWeight.w500 : FontWeight.w800),
                    ),
                    subtitle: Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: item.isRead
                        ? null
                        : const Icon(Icons.circle,
                            size: 10, color: AppColors.primary),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _notificationIcon(String kind) {
    return switch (kind) {
      'order' => Icons.receipt_long_outlined,
      'message' => Icons.chat_bubble_outline,
      'premium' => Icons.workspace_premium_outlined,
      'verification' => Icons.verified_outlined,
      _ => Icons.notifications_none_rounded,
    };
  }
}
