import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_brand_logo.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/content_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../settings/language_settings_tile.dart';
import 'seller_account_provider.dart';

class SellerDashboardScreen extends ConsumerWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final accountAsync = ref.watch(sellerAccountProvider);

    return Scaffold(
      body: SafeArea(
        child: accountAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            message: error is ApiException ? error.message : l10n.somethingWentWrong,
            onRetry: () => ref.invalidate(sellerAccountProvider),
          ),
          data: (account) {
            final businessName = account.profile.businessName;
            final stats = account.stats;
            final recentBadge = stats.recentReviewCount > 0 ? '${stats.recentReviewCount}' : null;

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(sellerAccountProvider),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenHorizontal,
                        AppSpacing.md,
                        AppSpacing.screenHorizontal,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const AppBrandLogo(variant: AppBrandLogoVariant.icon, iconSize: 32),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.sellerDashboard,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    Text(
                                      businessName,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: l10n.notifications,
                                onPressed: () => context.push('/seller/notifications'),
                                icon: Badge(
                                  isLabelVisible: stats.recentReviewCount > 0,
                                  label: Text('${stats.recentReviewCount}'),
                                  child: const Icon(Icons.notifications_none_rounded),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryLight],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.welcomeSeller(session?.name.split(' ').first ?? l10n.sellerDefault),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.manageStoreSubtitle,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                                ),
                                if (!stats.isActive) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.storeInactiveHint,
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.95)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.25,
                      ),
                      delegate: SliverChildListDelegate([
                        StatCard(
                          label: l10n.profileViews,
                          value: stats.formattedViews,
                          icon: Icons.visibility_outlined,
                        ),
                        StatCard(
                          label: l10n.products,
                          value: '${stats.productCount}',
                          icon: Icons.inventory_2_outlined,
                          trend: l10n.availableCount(stats.availableProductCount),
                        ),
                        StatCard(
                          label: l10n.reviews,
                          value: '${stats.reviewCount}',
                          icon: Icons.star_outline_rounded,
                          trend: stats.ratingTrend,
                        ),
                        StatCard(
                          label: l10n.services,
                          value: '${stats.serviceCount}',
                          icon: Icons.handyman_outlined,
                          trend: stats.achievementStars > 0
                              ? l10n.achievementStars(stats.achievementStars)
                              : null,
                        ),
                      ]),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenHorizontal,
                        AppSpacing.lg,
                        AppSpacing.screenHorizontal,
                        0,
                      ),
                      child: Text(
                        l10n.manage,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        DashboardMenuTile(
                          title: l10n.productManagement,
                          subtitle: l10n.productManagementSub,
                          icon: Icons.storefront_outlined,
                          onTap: () => context.push('/seller/products'),
                        ),
                        DashboardMenuTile(
                          title: l10n.reviews,
                          subtitle: l10n.reviewsSub,
                          icon: Icons.rate_review_outlined,
                          badge: recentBadge,
                          onTap: () => context.push('/seller/reviews'),
                        ),
                        DashboardMenuTile(
                          title: l10n.profileManagement,
                          subtitle: l10n.profileManagementSub,
                          icon: Icons.business_outlined,
                          onTap: () => context.push('/seller/profile'),
                        ),
                        DashboardMenuTile(
                          title: l10n.previewStorefront,
                          subtitle: l10n.previewStorefrontSub,
                          icon: Icons.visibility_outlined,
                          onTap: () => context.push('/seller/${account.profile.id}'),
                        ),
                        DashboardMenuTile(
                          title: l10n.accountSecurity,
                          subtitle: l10n.accountSecuritySub,
                          icon: Icons.security_outlined,
                          onTap: () => context.push('/seller/settings'),
                        ),
                        const LanguageSettingsTile(),
                        const SizedBox(height: AppSpacing.lg),
                        OutlinedButton(
                          onPressed: () async {
                            final prefs = await ref.read(sharedPreferencesProvider.future);
                            await ref.read(authServiceProvider).logout(prefs);
                            await ref.read(appStorageProvider)?.logout();
                            ref.invalidate(sellerAccountProvider);
                            ref.read(userSessionProvider.notifier).state = null;
                            ref.read(authSessionProvider.notifier).state = null;
                            if (context.mounted) context.go('/login');
                          },
                          child: Text(l10n.logOut),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
