import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_logo_placeholder.dart';
import '../../core/widgets/content_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../settings/language_settings_tile.dart';

class SellerDashboardScreen extends ConsumerWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final businessName = session?.businessName ?? l10n.yourBusiness;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenHorizontal, AppSpacing.md, AppSpacing.screenHorizontal, 0),
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
                              Text(l10n.sellerDashboard, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                              Text(businessName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
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
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(l10n.manageStoreSubtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
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
                  childAspectRatio: 1.3,
                ),
                delegate: SliverChildListDelegate([
                  StatCard(label: l10n.profileViews, value: '1.2k', icon: Icons.visibility_outlined, trend: l10n.profileViewsTrend),
                  StatCard(label: l10n.products, value: '8', icon: Icons.inventory_2_outlined),
                  StatCard(label: l10n.reviews, value: '47', icon: Icons.star_outline_rounded, trend: '4.8 avg'),
                  StatCard(label: l10n.inquiries, value: '23', icon: Icons.chat_bubble_outline),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenHorizontal, AppSpacing.lg, AppSpacing.screenHorizontal, 0),
                child: Text(l10n.manage, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
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
                    onTap: () {},
                  ),
                  DashboardMenuTile(
                    title: l10n.reviews,
                    subtitle: l10n.reviewsSub,
                    icon: Icons.rate_review_outlined,
                    badge: '3',
                    onTap: () {},
                  ),
                  DashboardMenuTile(
                    title: l10n.profileManagement,
                    subtitle: l10n.profileManagementSub,
                    icon: Icons.business_outlined,
                    onTap: () {},
                  ),
                  DashboardMenuTile(
                    title: l10n.orders,
                    subtitle: l10n.ordersSub,
                    icon: Icons.receipt_long_outlined,
                    comingSoon: true,
                  ),
                  DashboardMenuTile(
                    title: l10n.messages,
                    subtitle: l10n.messagesSub,
                    icon: Icons.message_outlined,
                    comingSoon: true,
                  ),
                  const LanguageSettingsTile(),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton(
                    onPressed: () async {
                      final prefs = await ref.read(sharedPreferencesProvider.future);
                      await ref.read(authServiceProvider).logout(prefs);
                      await ref.read(appStorageProvider)?.logout();
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
      ),
    );
  }
}
