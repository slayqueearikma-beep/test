import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../app.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_logo_placeholder.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/content_widgets.dart';
import '../../core/widgets/error_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../map/map_screen.dart';
import '../search/search_screen.dart';
import '../settings/language_settings_tile.dart';

final buyerCityProvider = StateProvider<String>((ref) {
  final session = ref.watch(userSessionProvider);
  return session?.city ?? AppConfig.moroccanCities.first;
});

final buyerCategorySlugProvider = StateProvider<String?>((ref) => null);

final buyerTabIndexProvider = StateProvider<int>((ref) => 0);

final buyerSellersProvider =
    FutureProvider.autoDispose<List<SellerModel>>((ref) {
  final city = ref.watch(buyerCityProvider);
  final category = ref.watch(buyerCategorySlugProvider);
  return apiServiceProvider.fetchSellers(city: city, category: category);
});

final buyerCategoriesProvider =
    FutureProvider.autoDispose((ref) => apiServiceProvider.fetchCategories());

class BuyerHomeShell extends ConsumerWidget {
  const BuyerHomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mapsEnabled = AppConfig.hasGoogleMapsApiKey;
    final index = ref.watch(buyerTabIndexProvider);

    return Scaffold(
      body: _pageForIndex(index, mapsEnabled: mapsEnabled),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(buyerTabIndexProvider.notifier).state = i,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: l10n.navHome),
          NavigationDestination(
              icon: const Icon(Icons.search), label: l10n.navSearch),
          if (mapsEnabled)
            NavigationDestination(
                icon: const Icon(Icons.map_outlined),
                selectedIcon: const Icon(Icons.map_rounded),
                label: l10n.navMap),
          NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person_rounded),
              label: l10n.navProfile),
        ],
      ),
    );
  }
}

Widget _pageForIndex(int index, {required bool mapsEnabled}) {
  if (mapsEnabled) {
    return switch (index) {
      0 => const BuyerHomeScreen(),
      1 => const SearchScreen(),
      2 => const MapScreen(),
      _ => const _BuyerProfileTab(),
    };
  }

  return switch (index) {
    0 => const BuyerHomeScreen(),
    1 => const SearchScreen(),
    _ => const _BuyerProfileTab(),
  };
}

class BuyerHomeScreen extends ConsumerWidget {
  const BuyerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final city = ref.watch(buyerCityProvider);
    final sellersAsync = ref.watch(buyerSellersProvider);
    final categoriesAsync = ref.watch(buyerCategoriesProvider);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenHorizontal,
                  AppSpacing.md, AppSpacing.screenHorizontal, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppBrandLogo(
                          variant: AppBrandLogoVariant.icon, iconSize: 32),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.goodMorning(
                                  session?.name.split(' ').first ?? ''),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            GestureDetector(
                              onTap: () => _pickCity(context, ref, city),
                              child: Row(
                                children: [
                                  Text(city,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                  const Icon(Icons.keyboard_arrow_down_rounded,
                                      size: 20),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.notifications_none_rounded)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    readOnly: true,
                    onTap: () =>
                        ref.read(buyerTabIndexProvider.notifier).state = 1,
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor:
                          Theme.of(context).inputDecorationTheme.fillColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (session == null || session.isGuest) ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_add_alt_1_outlined,
                            color: AppColors.primary),
                        title: Text(l10n.guestMode),
                        subtitle: Text(l10n.guestModeSubtitle),
                        trailing: TextButton(
                            onPressed: () => context.push('/login'),
                            child: Text(l10n.logIn)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const _BuyerActionsRow(),
                ],
              ),
            ),
          ),
          categoriesAsync.when(
            data: (categories) {
              final selected = ref.watch(buyerCategorySlugProvider);
              return SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    SectionHeader(title: l10n.categories),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenHorizontal),
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            return FilterChip(
                              label: Text(l10n.seeAll),
                              selected: selected == null,
                              onSelected: (_) => ref
                                  .read(buyerCategorySlugProvider.notifier)
                                  .state = null,
                              showCheckmark: false,
                            );
                          }
                          final cat = categories[i - 1];
                          return FilterChip(
                            label: Text(cat.nameEn),
                            selected: selected == cat.slug,
                            onSelected: (_) => ref
                                .read(buyerCategorySlugProvider.notifier)
                                .state = cat.slug,
                            showCheckmark: false,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AsyncErrorView.fromError(e,
                    onRetry: () => ref.invalidate(buyerCategoriesProvider)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenHorizontal,
                  AppSpacing.lg, AppSpacing.screenHorizontal, AppSpacing.sm),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                child: SizedBox(
                  height: 160,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                          color: AppColors.primary.withValues(alpha: 0.12)),
                      const Center(
                          child: Icon(Icons.map_rounded,
                              size: 48, color: AppColors.primary)),
                      Positioned(
                        left: AppSpacing.md,
                        bottom: AppSpacing.md,
                        right: AppSpacing.md,
                        child: Card(
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.near_me,
                                color: AppColors.primary),
                            title: Text(l10n.exploreOnMap,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(l10n.exploreOnMapSubtitle(city)),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              final mapsEnabled = AppConfig.hasGoogleMapsApiKey;
                              ref.read(buyerTabIndexProvider.notifier).state =
                                  mapsEnabled ? 2 : 1;
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          sellersAsync.when(
            data: (sellers) {
              if (sellers.isEmpty) {
                return SliverFillRemaining(
                  child: Center(child: Text(l10n.noBusinessesInCity)),
                );
              }

              final featured = sellers.take(3).toList();
              final nearby = sellers;
              final topRated = [...sellers]
                ..sort((a, b) => b.averageRating.compareTo(a.averageRating));

              return SliverList(
                delegate: SliverChildListDelegate([
                  SectionHeader(
                      title: l10n.featuredBusinesses, actionLabel: l10n.seeAll),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenHorizontal),
                      scrollDirection: Axis.horizontal,
                      itemCount: featured.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => SizedBox(
                        width: 260,
                        child: SellerCard(
                          compact: true,
                          businessName: featured[i].businessName,
                          description: featured[i].description,
                          rating: featured[i].averageRating,
                          reviewCount: featured[i].reviewCount,
                          city: featured[i].city,
                          imageUrl: featured[i].coverImageUrl,
                          achievementStars: featured[i].achievementStars,
                          onTap: () =>
                              context.push('/seller/${featured[i].id}'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(title: l10n.nearbyBusinesses),
                  const SizedBox(height: AppSpacing.sm),
                  ...nearby.take(3).map(
                        (s) => SellerCard(
                          businessName: s.businessName,
                          description: s.description,
                          rating: s.averageRating,
                          reviewCount: s.reviewCount,
                          city: s.city,
                          imageUrl: s.coverImageUrl,
                          achievementStars: s.achievementStars,
                          onTap: () => context.push('/seller/${s.id}'),
                        ),
                      ),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(title: l10n.topRatedSellers),
                  const SizedBox(height: AppSpacing.sm),
                  ...topRated.take(3).map(
                        (s) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.screenHorizontal,
                              vertical: 4),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            tileColor: Theme.of(context).cardTheme.color,
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.1),
                              child: Text(s.businessName[0],
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700)),
                            ),
                            title: Text(s.businessName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${s.averageRating} ★ · ${l10n.reviewsCount(s.reviewCount)}'),
                            trailing: s.achievementStars > 0
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(
                                      s.achievementStars.clamp(0, 3),
                                      (_) => const Icon(Icons.star,
                                          size: 14, color: AppColors.star),
                                    ),
                                  )
                                : null,
                            onTap: () => context.push('/seller/${s.id}'),
                          ),
                        ),
                      ),
                  const SizedBox(height: AppSpacing.xxl),
                ]),
              );
            },
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(
              child: AsyncErrorView.fromError(
                e,
                onRetry: () => ref.invalidate(buyerSellersProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCity(
      BuildContext context, WidgetRef ref, String current) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => ListView(
        children: AppConfig.moroccanCities
            .map((c) => ListTile(
                title: Text(c),
                trailing: c == current
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, c)))
            .toList(),
      ),
    );
    if (selected != null) ref.read(buyerCityProvider.notifier).state = selected;
  }
}

class _BuyerActionsRow extends ConsumerWidget {
  const _BuyerActionsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _ActionChipCard(
            icon: Icons.favorite_border,
            label: l10n.favorites,
            onTap: () => context.push('/favorites'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ActionChipCard(
            icon: Icons.map_outlined,
            label: l10n.navMap,
            onTap: () {
              final mapsEnabled = AppConfig.hasGoogleMapsApiKey;
              ref.read(buyerTabIndexProvider.notifier).state =
                  mapsEnabled ? 2 : 1;
            },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ActionChipCard(
            icon: Icons.workspace_premium_outlined,
            label: l10n.premium,
            onTap: () => context.push('/premium'),
          ),
        ),
      ],
    );
  }
}

class _ActionChipCard extends StatelessWidget {
  const _ActionChipCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuyerProfileTab extends ConsumerWidget {
  const _BuyerProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final isGuest = session == null || session.isGuest;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.lg),
            const AppBrandLogo(variant: AppBrandLogoVariant.icon, iconSize: 56),
            const SizedBox(height: AppSpacing.md),
            Text(session?.name ?? l10n.buyerLabel,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text(isGuest ? l10n.guestMode : session.email,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xl),
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: Text(l10n.favorites),
              onTap: () => context.push('/favorites'),
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: Text(l10n.premium),
              onTap: () => context.push('/premium'),
            ),
            ListTile(
              leading: const Icon(Icons.location_city_outlined),
              title: Text(l10n.city),
              subtitle: Text(session?.city ?? '—'),
            ),
            const LanguageSettingsTile(),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: Text(l10n.darkMode),
              trailing: Switch(
                value: Theme.of(context).brightness == Brightness.dark,
                onChanged: (_) {
                  final current = ref.read(themeModeProvider);
                  ref.read(themeModeProvider.notifier).state =
                      current == ThemeMode.dark
                          ? ThemeMode.light
                          : ThemeMode.dark;
                },
              ),
            ),
            if (!isGuest)
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined,
                    color: AppColors.danger),
                title: Text(l10n.deleteAccount,
                    style: const TextStyle(color: AppColors.danger)),
                onTap: () => _confirmDeleteAccount(context, ref),
              ),
            const Spacer(),
            if (isGuest)
              FilledButton(
                  onPressed: () => context.go('/login'),
                  child: Text(l10n.logIn))
            else
              OutlinedButton(
                onPressed: () async {
                  final prefs =
                      await ref.read(sharedPreferencesProvider.future);
                  await ref.read(authServiceProvider).logout(prefs);
                  await ref.read(appStorageProvider)?.logout();
                  ref.read(userSessionProvider.notifier).state = null;
                  ref.read(authSessionProvider.notifier).state = null;
                  if (context.mounted) context.go('/login');
                },
                child: Text(l10n.logOut),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAccount),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.deleteAccountConfirm),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.password),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.deleteAccount),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(authServiceProvider)
          .deleteAccount(password: controller.text);
      await ref.read(appStorageProvider)?.logout();
      ref.read(userSessionProvider.notifier).state = null;
      ref.read(authSessionProvider.notifier).state = null;
      if (context.mounted) context.go('/language');
    } on Object catch (e) {
      if (context.mounted) {
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: e.toString());
      }
    }
  }
}
