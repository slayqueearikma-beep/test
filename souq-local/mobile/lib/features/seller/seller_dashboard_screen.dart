import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
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
    final analyticsAsync = ref.watch(sellerAnalyticsProvider);

    return Scaffold(
      body: SafeArea(
        child: accountAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            message:
                error is ApiException ? error.message : l10n.somethingWentWrong,
            onRetry: () => ref.invalidate(sellerAccountProvider),
          ),
          data: (account) {
            final businessName = account.profile.businessName;
            final stats = account.stats;
            final analytics = analyticsAsync.valueOrNull;
            final recentBadge = stats.recentReviewCount > 0
                ? '${stats.recentReviewCount}'
                : null;

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(sellerAccountProvider);
                ref.invalidate(sellerAnalyticsProvider);
                await ref.read(sellerAccountProvider.future);
                await ref.read(sellerAnalyticsProvider.future);
              },
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
                              const AppBrandLogo(
                                  variant: AppBrandLogoVariant.icon,
                                  iconSize: 32),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.sellerDashboard,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    Text(
                                      businessName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: l10n.notifications,
                                onPressed: () =>
                                    context.push('/seller/notifications'),
                                icon: Badge(
                                  isLabelVisible: stats.recentReviewCount > 0,
                                  label: Text('${stats.recentReviewCount}'),
                                  child: const Icon(
                                      Icons.notifications_none_rounded),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryLight
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.cardRadius),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _welcomeGreeting(
                                    l10n,
                                    businessName: businessName,
                                    sessionName: session?.name,
                                    authDisplayName:
                                        ref.watch(authSessionProvider)?.user.displayName,
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.manageStoreSubtitle,
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.85)),
                                ),
                                if (!stats.isActive) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.storeInactiveHint,
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.95)),
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
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.md,
                      AppSpacing.screenHorizontal,
                      AppSpacing.sm,
                    ),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.crossAxisExtent;
                        final crossAxisCount = width >= 720 ? 4 : 2;
                        final isRtl =
                            Directionality.of(context) == TextDirection.rtl;
                        final textScale =
                            MediaQuery.textScalerOf(context).scale(1.0);
                        // Arabic labels need more vertical room; scale with text size.
                        final cardHeight =
                            (isRtl ? 136.0 : 128.0) * textScale.clamp(1.0, 1.35);
                        final profileViews =
                            analytics?.profileViewCount ?? stats.profileViewCount;
                        final productCount =
                            analytics?.productCount ?? stats.productCount;
                        final availableCount = analytics?.availableProductCount ??
                            stats.availableProductCount;
                        final inquiryCount =
                            analytics?.inquiryCount ?? stats.inquiryCount;
                        final favoriteCount =
                            analytics?.favoriteCount ?? stats.favoriteCount;
                        final contactClicks =
                            analytics?.contactClickCount ?? stats.contactClickCount;
                        final avgResponse = analytics?.avgResponseMinutes ??
                            stats.avgResponseMinutes;

                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: cardHeight,
                          ),
                          delegate: SliverChildListDelegate([
                            StatCard(
                              label: l10n.profileViews,
                              value: '$profileViews',
                              icon: Icons.visibility_outlined,
                              trend: profileViews > 0 ? null : l10n.noViewsYet,
                            ),
                            StatCard(
                              label: l10n.products,
                              value: '$productCount',
                              icon: Icons.inventory_2_outlined,
                              trend: productCount > 0
                                  ? l10n.availableCount(availableCount)
                                  : l10n.noProductsYet.split('.').first,
                            ),
                            StatCard(
                              label: l10n.inquiries,
                              value: '$inquiryCount',
                              icon: Icons.chat_bubble_outline,
                              trend: inquiryCount > 0
                                  ? l10n.avgResponseMinutes(avgResponse)
                                  : l10n.noInquiriesYet,
                            ),
                            StatCard(
                              label: l10n.favorites,
                              value: '$favoriteCount',
                              icon: Icons.favorite_border,
                              trend: favoriteCount > 0 || contactClicks > 0
                                  ? l10n.contactClicks(contactClicks)
                                  : l10n.noFavoritesYet,
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenHorizontal,
                        AppSpacing.md,
                        AppSpacing.screenHorizontal,
                        0,
                      ),
                      child: Text(
                        l10n.manage,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.sm,
                      AppSpacing.screenHorizontal,
                      AppSpacing.lg,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        DashboardMenuTile(
                          title: l10n.inquiries,
                          subtitle: l10n.inquiriesSub,
                          icon: Icons.chat_bubble_outline,
                          badge: (analytics?.inquiryCount ?? stats.inquiryCount) > 0
                              ? '${analytics?.inquiryCount ?? stats.inquiryCount}'
                              : null,
                          onTap: () => context.push('/seller/messages'),
                        ),
                        DashboardMenuTile(
                          title: l10n.discoverBusinesses,
                          subtitle: l10n.discoverBusinessesSub,
                          icon: Icons.travel_explore_outlined,
                          onTap: () async {
                            final storage = ref.read(appStorageProvider);
                            await storage?.saveAppMode(AppMode.buyer);
                            if (context.mounted) context.push('/buyer/home');
                          },
                        ),
                        DashboardMenuTile(
                          title: l10n.switchToBuyerMode,
                          subtitle: l10n.switchToBuyerModeSub,
                          icon: Icons.shopping_bag_outlined,
                          onTap: () async {
                            final storage = ref.read(appStorageProvider);
                            await storage?.saveAppMode(AppMode.buyer);
                            if (context.mounted) context.go('/buyer/home');
                          },
                        ),
                        DashboardMenuTile(
                          title: l10n.analytics,
                          subtitle: l10n.analyticsSummary(
                            analytics?.profileViewCount ?? stats.profileViewCount,
                            analytics?.contactClickCount ?? stats.contactClickCount,
                          ),
                          icon: Icons.query_stats_outlined,
                          onTap: () => _showAnalytics(context, analytics, stats),
                        ),
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
                          onTap: () =>
                              context.push('/seller/${account.profile.id}'),
                        ),
                        DashboardMenuTile(
                          title: l10n.premium,
                          subtitle: analytics?.isPremium == true
                              ? l10n.premiumActiveSub
                              : l10n.premiumUpgradeSub,
                          icon: Icons.workspace_premium_outlined,
                          onTap: () => context.push('/premium'),
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
                            final prefs = await ref
                                .read(sharedPreferencesProvider.future);
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

  void _showAnalytics(
    BuildContext context,
    SellerAnalyticsModel? analytics,
    SellerDashboardStats stats,
  ) {
    final l10n = context.l10n;
    final profileViews = analytics?.profileViewCount ?? stats.profileViewCount;
    final inquiryCount = analytics?.inquiryCount ?? stats.inquiryCount;
    final favoriteCount = analytics?.favoriteCount ?? stats.favoriteCount;
    final contactClicks = analytics?.contactClickCount ?? stats.contactClickCount;
    final avgResponse = analytics?.avgResponseMinutes ?? stats.avgResponseMinutes;
    final followers = analytics?.followerEstimate ?? 0;
    final reviewCount = analytics?.reviewCount ?? stats.reviewCount;
    final verification =
        analytics?.verificationStatus ?? stats.verificationStatus;

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.analytics,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.md),
              _AnalyticsRow(
                  label: l10n.profileViews, value: '$profileViews'),
              _AnalyticsRow(label: l10n.inquiries, value: '$inquiryCount'),
              _AnalyticsRow(label: l10n.favorites, value: '$favoriteCount'),
              _AnalyticsRow(
                  label: l10n.contactClicksLabel, value: '$contactClicks'),
              _AnalyticsRow(
                  label: l10n.averageResponse,
                  value: l10n.avgResponseMinutes(avgResponse)),
              _AnalyticsRow(label: l10n.followers, value: '$followers'),
              _AnalyticsRow(label: l10n.reviews, value: '$reviewCount'),
              _AnalyticsRow(label: l10n.verification, value: verification),
            ],
          ),
        ),
      ),
    );
  }
}

String _welcomeGreeting(
  AppStrings l10n, {
  required String businessName,
  String? sessionName,
  String? authDisplayName,
}) {
  // Prefer storefront / auth identity over short registration typos.
  for (final candidate in [
    businessName,
    authDisplayName ?? '',
    sessionName ?? '',
  ]) {
    final cleaned = candidate.trim();
    if (_isUsableDisplayName(cleaned)) {
      final first = cleaned.split(RegExp(r'\s+')).first;
      return l10n.welcomeSeller(first);
    }
  }
  return l10n.welcomeExclamation;
}

bool _isUsableDisplayName(String value) {
  if (value.length < 2) return false;
  final compact = value.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ0-9]'), '');
  if (compact.length < 3) return false;
  // Reject keyboard-mash / placeholder tokens like "ooo", "aaa", "xxx".
  if (RegExp(r'^(.)\1+$', caseSensitive: false).hasMatch(compact)) return false;
  return true;
}

class _AnalyticsRow extends StatelessWidget {
  const _AnalyticsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
