import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../app.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_logo_placeholder.dart';
import '../../core/widgets/content_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../map/map_screen.dart';
import '../search/search_screen.dart';
import '../settings/language_settings_tile.dart';

final buyerCityProvider = StateProvider<String>((ref) {
  final session = ref.watch(userSessionProvider);
  return session?.city ?? AppConfig.moroccanCities.first;
});

final buyerSellersProvider = FutureProvider.autoDispose<List<SellerModel>>((ref) {
  final city = ref.watch(buyerCityProvider);
  return apiServiceProvider.fetchSellers(city: city);
});

final buyerCategoriesProvider = FutureProvider.autoDispose((ref) => apiServiceProvider.fetchCategories());

class BuyerHomeShell extends ConsumerStatefulWidget {
  const BuyerHomeShell({super.key});

  @override
  ConsumerState<BuyerHomeShell> createState() => _BuyerHomeShellState();
}

class _BuyerHomeShellState extends ConsumerState<BuyerHomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = [
      const BuyerHomeScreen(),
      const SearchScreen(),
      const MapScreen(),
      const _BuyerProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: l10n.navHome),
          NavigationDestination(icon: const Icon(Icons.search), label: l10n.navSearch),
          NavigationDestination(icon: const Icon(Icons.map_outlined), selectedIcon: const Icon(Icons.map_rounded), label: l10n.navMap),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person_rounded), label: l10n.navProfile),
        ],
      ),
    );
  }
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
                            Text(
                              l10n.goodMorning(session?.name.split(' ').first ?? ''),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            ),
                            GestureDetector(
                              onTap: () => _pickCity(context, ref, city),
                              child: Row(
                                children: [
                                  Text(city, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                  const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    readOnly: true,
                    onTap: () {},
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          categoriesAsync.when(
            data: (categories) => SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(title: l10n.categories),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final cat = categories[i];
                        return FilterChip(
                          label: Text(cat.nameEn),
                          selected: i == 0,
                          onSelected: (_) {},
                          showCheckmark: false,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenHorizontal, AppSpacing.lg, AppSpacing.screenHorizontal, AppSpacing.sm),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                child: SizedBox(
                  height: 160,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: AppColors.primary.withValues(alpha: 0.12)),
                      const Center(child: Icon(Icons.map_rounded, size: 48, color: AppColors.primary)),
                      Positioned(
                        left: AppSpacing.md,
                        bottom: AppSpacing.md,
                        right: AppSpacing.md,
                        child: Card(
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.near_me, color: AppColors.primary),
                            title: Text(l10n.exploreOnMap, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(l10n.exploreOnMapSubtitle(city)),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {},
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
              final topRated = [...sellers]..sort((a, b) => b.averageRating.compareTo(a.averageRating));

              return SliverList(
                delegate: SliverChildListDelegate([
                  SectionHeader(title: l10n.featuredBusinesses, actionLabel: l10n.seeAll),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
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
                          achievementStars: featured[i].achievementStars,
                          onTap: () => context.push('/seller/${featured[i].id}'),
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
                          achievementStars: s.achievementStars,
                          onTap: () => context.push('/seller/${s.id}'),
                        ),
                      ),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(title: l10n.topRatedSellers),
                  const SizedBox(height: AppSpacing.sm),
                  ...topRated.take(3).map(
                        (s) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal, vertical: 4),
                          child: ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            tileColor: Theme.of(context).cardTheme.color,
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Text(s.businessName[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                            ),
                            title: Text(s.businessName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${s.averageRating} ★ · ${l10n.reviewsCount(s.reviewCount)}'),
                            trailing: s.achievementStars > 0
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(
                                      s.achievementStars.clamp(0, 3),
                                      (_) => const Icon(Icons.star, size: 14, color: AppColors.star),
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
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(child: Center(child: Text('${l10n.couldNotLoadBusinesses}\n$e', textAlign: TextAlign.center))),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCity(BuildContext context, WidgetRef ref, String current) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => ListView(
        children: AppConfig.moroccanCities
            .map((c) => ListTile(title: Text(c), trailing: c == current ? const Icon(Icons.check, color: AppColors.primary) : null, onTap: () => Navigator.pop(ctx, c)))
            .toList(),
      ),
    );
    if (selected != null) ref.read(buyerCityProvider.notifier).state = selected;
  }
}

class _BuyerProfileTab extends ConsumerWidget {
  const _BuyerProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.lg),
            const AppBrandLogo(variant: AppBrandLogoVariant.icon, iconSize: 56),
            const SizedBox(height: AppSpacing.md),
            Text(session?.name ?? l10n.buyerLabel, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            Text(session?.email ?? '', style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xl),
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
                      current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                },
              ),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () async {
                await ref.read(appStorageProvider)?.logout();
                ref.read(userSessionProvider.notifier).state = null;
                if (context.mounted) context.go('/login');
              },
              child: Text(l10n.logOut),
            ),
          ],
        ),
      ),
    );
  }
}
