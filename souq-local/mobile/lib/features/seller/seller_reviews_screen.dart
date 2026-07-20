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
        data: (account) => _ReviewsBody(sellerId: account.profile.id, stats: account.stats),
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
                      const Icon(Icons.star_rounded, color: AppColors.star, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        widget.stats.averageRating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
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
                        ...List.generate(
                          review.rating.clamp(0, 5),
                          (_) => const Icon(Icons.star_rounded, size: 14, color: AppColors.star),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class SellerNotificationsScreen extends ConsumerWidget {
  const SellerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final accountAsync = ref.watch(sellerAccountProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notifications)),
      body: accountAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(sellerAccountProvider),
        ),
        data: (account) => FutureBuilder<List<ReviewModel>>(
          future: apiServiceProvider.fetchReviews(account.profile.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return AsyncErrorView.fromError(
                snapshot.error!,
                onRetry: () => ref.invalidate(sellerAccountProvider),
              );
            }

            final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 7));
            final recent = (snapshot.data ?? []).where((review) {
              final parsed = DateTime.tryParse(review.createdAt);
              if (parsed == null) return false;
              return parsed.toUtc().isAfter(cutoff);
            }).toList();

            if (recent.isEmpty) {
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
                      Text(l10n.noNotifications, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.notificationsSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              itemCount: recent.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final review = recent[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: const Icon(Icons.rate_review_outlined, color: AppColors.primary),
                    ),
                    title: Text('${review.buyerDisplayName} · ${review.rating}/5'),
                    subtitle: Text(
                      review.comment.isEmpty ? l10n.recentReviews : review.comment,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
