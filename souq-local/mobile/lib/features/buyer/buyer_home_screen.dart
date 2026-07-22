import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/data/city_coordinates.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/theme_mode_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_brand_logo.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/content_widgets.dart';
import '../../core/widgets/error_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../messages/messages_inbox_screen.dart';
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

final buyerFavoriteSellerIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final session = ref.watch(userSessionProvider);
  if (session == null || session.isGuest) {
    final local =
        ref.read(appStorageProvider)?.getGuestFavoriteItems() ?? const [];
    return local
        .where((item) => item.sellerId.isNotEmpty && item.productId.isEmpty)
        .map((item) => item.sellerId)
        .toSet();
  }
  try {
    final favorites = await apiServiceProvider.fetchFavorites();
    return favorites
        .where((item) => item.sellerId.isNotEmpty && item.productId.isEmpty)
        .map((item) => item.sellerId)
        .toSet();
  } catch (error) {
    // Surface as provider error instead of looking like an empty favorites list.
    rethrow;
  }
});

class BuyerHomeShell extends ConsumerWidget {
  const BuyerHomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final index = ref.watch(buyerTabIndexProvider).clamp(0, 2);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          const BuyerHomeScreen(),
          SearchScreen(autofocusSearch: index == 1),
          const MessagesInboxScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        height: 68,
        onDestinationSelected: (i) =>
            ref.read(buyerTabIndexProvider.notifier).state = i,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_rounded),
            selectedIcon: const Icon(Icons.search_rounded),
            label: l10n.navSearch,
          ),
          NavigationDestination(
            icon: const _MessagesNavIcon(selected: false),
            selectedIcon: const _MessagesNavIcon(selected: true),
            label: l10n.navMessages,
          ),
        ],
      ),
    );
  }
}

class _MessagesNavIcon extends ConsumerWidget {
  const _MessagesNavIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(conversationsUnreadCountProvider).valueOrNull ?? 0;
    final icon = selected
        ? const Icon(Icons.chat_bubble_rounded)
        : const Icon(Icons.chat_bubble_outline_rounded);
    return Badge(
      isLabelVisible: unread > 0,
      label: Text(unread > 99 ? '99+' : '$unread'),
      child: icon,
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
    final favoriteIds = ref.watch(buyerFavoriteSellerIdsProvider).valueOrNull ??
        const <String>{};
    final isGuest = session == null || session.isGuest;

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.sm,
                AppSpacing.screenHorizontal,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeTopBar(
                    greeting: l10n.goodMorning(
                      session?.name.split(' ').first ?? l10n.guestMode,
                    ),
                    city: city,
                    isGuest: isGuest,
                    onCityTap: () => _pickCity(context, ref, city),
                    onNotifications: () {
                      if (isGuest) {
                        context.push('/login');
                        return;
                      }
                      if (session.accountType == AccountType.seller) {
                        context.push('/seller/notifications');
                        return;
                      }
                      // Buyer notifications surface is the messages inbox.
                      ref.read(buyerTabIndexProvider.notifier).state = 2;
                    },
                    onPremium: () => context.push('/premium'),
                    onProfile: () => context.push('/profile'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _HomeSearchField(
                    hint: l10n.searchHint,
                    onTap: () =>
                        ref.read(buyerTabIndexProvider.notifier).state = 1,
                  ),
                  if (isGuest) ...[
                    const SizedBox(height: AppSpacing.md),
                    _GuestModeBanner(
                      title: l10n.guestMode,
                      subtitle: l10n.guestModeSubtitle,
                      loginLabel: l10n.logIn,
                      onLogin: () => context.push('/login'),
                    ),
                  ],
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
                    SectionHeader(
                      title: l10n.categories,
                      actionLabel: l10n.seeAll,
                      onAction: () =>
                          ref.read(buyerTabIndexProvider.notifier).state = 1,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenHorizontal,
                        ),
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length + 1,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (_, i) {
                          final isAll = i == 0;
                          final selectedChip =
                              isAll ? selected == null : selected == categories[i - 1].slug;
                          final label =
                              isAll
                                  ? l10n.allCategories
                                  : categories[i - 1].localizedName(
                                      Localizations.localeOf(context).languageCode,
                                    );
                          final icon = isAll
                              ? Icons.apps_rounded
                              : _categoryIcon(categories[i - 1].icon);
                          return _CategoryChip(
                            label: label,
                            icon: icon,
                            selected: selectedChip,
                            onTap: () {
                              ref.read(buyerCategorySlugProvider.notifier).state =
                                  isAll ? null : categories[i - 1].slug;
                            },
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
                child: AsyncErrorView.fromError(
                  e,
                  onRetry: () => ref.invalidate(buyerCategoriesProvider),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.lg,
                AppSpacing.screenHorizontal,
                AppSpacing.sm,
              ),
              child: _ExploreMapCard(
                title: l10n.exploreOnMap,
                subtitle: l10n.exploreOnMapSubtitle(city),
                onTap: () => context.push('/map'),
              ),
            ),
          ),
          sellersAsync.when(
            data: (sellers) {
              if (sellers.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(l10n.noBusinessesInCity)),
                );
              }

              final featured = sellers.take(8).toList();
              final cityCenter = CityCoordinates.centerFor(city);

              return SliverList(
                delegate: SliverChildListDelegate([
                  SectionHeader(
                    title: l10n.featuredBusinesses,
                    actionLabel: l10n.seeAll,
                    onAction: () =>
                        ref.read(buyerTabIndexProvider.notifier).state = 1,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenHorizontal,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: featured.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.sm + 4),
                      itemBuilder: (_, i) {
                        final seller = featured[i];
                        final category = seller.categories.isNotEmpty
                            ? seller.categories.first.localizedName(
                                Localizations.localeOf(context).languageCode,
                              )
                            : l10n.localBusiness;
                        return FeaturedBusinessCard(
                          businessName: seller.businessName,
                          category: category,
                          rating: seller.averageRating,
                          reviewCount: seller.reviewCount,
                          distanceLabel: _distanceLabel(
                            cityCenter,
                            LatLng(seller.latitude, seller.longitude),
                          ),
                          imageUrl: seller.coverImageUrl.isNotEmpty
                              ? seller.coverImageUrl
                              : seller.logoImageUrl,
                          isFavorite: favoriteIds.contains(seller.id),
                          onTap: () => context.push('/seller/${seller.id}'),
                          onFavorite: () =>
                              _toggleFavoriteSeller(context, ref, seller),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(title: l10n.nearbyBusinesses),
                  const SizedBox(height: AppSpacing.sm),
                  ...sellers.take(4).map(
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
                  const SizedBox(height: AppSpacing.xxl),
                ]),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
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

  static IconData _categoryIcon(String icon) {
    return switch (icon) {
      'beauty' || 'spa' => Icons.spa_outlined,
      'clothing' || 'fashion' => Icons.checkroom_outlined,
      'electronics' => Icons.smartphone_outlined,
      'food' || 'restaurant' => Icons.restaurant_outlined,
      'services' => Icons.handyman_outlined,
      _ => Icons.storefront_outlined,
    };
  }

  static String _distanceLabel(LatLng from, LatLng to) {
    const earthKm = 6371.0;
    final dLat = _rad(to.latitude - from.latitude);
    final dLng = _rad(to.longitude - from.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(from.latitude)) *
            math.cos(_rad(to.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final km = earthKm * c;
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  static double _rad(double deg) => deg * math.pi / 180;

  Future<void> _toggleFavoriteSeller(
    BuildContext context,
    WidgetRef ref,
    SellerModel seller,
  ) async {
    final l10n = context.l10n;
    final session = ref.read(userSessionProvider);
    final storage = ref.read(appStorageProvider);
    final ids = ref.read(buyerFavoriteSellerIdsProvider).valueOrNull ?? {};
    final isFav = ids.contains(seller.id);

    try {
      if (session == null || session.isGuest) {
        if (storage == null) return;
        if (isFav) {
          await storage.removeGuestFavoriteSeller(seller.id);
        } else {
          await storage.addGuestFavoriteItem(
            GuestFavoriteItem(
              productId: '',
              sellerId: seller.id,
              name: seller.businessName,
              price: 0,
              imageUrl: seller.logoImageUrl.isNotEmpty
                  ? seller.logoImageUrl
                  : seller.coverImageUrl,
              sellerName: seller.businessName,
            ),
          );
        }
      } else if (isFav) {
        await apiServiceProvider.removeFavoriteSeller(seller.id);
      } else {
        await apiServiceProvider.addFavoriteSeller(seller.id);
      }
      ref.invalidate(buyerFavoriteSellerIdsProvider);
    } catch (e) {
      if (context.mounted) {
        await showAppErrorDialog(
          context,
          title: l10n.somethingWentWrong,
          message: e.toString(),
        );
      }
    }
  }

  Future<void> _pickCity(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        children: AppConfig.moroccanCities
            .map(
              (c) => ListTile(
                title: Text(c),
                trailing: c == current
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, c),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null) {
      ref.read(buyerCityProvider.notifier).state = selected;
    }
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.greeting,
    required this.city,
    required this.isGuest,
    required this.onCityTap,
    required this.onNotifications,
    required this.onPremium,
    required this.onProfile,
  });

  final String greeting;
  final String city;
  final bool isGuest;
  final VoidCallback onCityTap;
  final VoidCallback onNotifications;
  final VoidCallback onPremium;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppBrandLogo(variant: AppBrandLogoVariant.icon, iconSize: 30),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              InkWell(
                onTap: onCityTap,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        city,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: onNotifications,
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        IconButton(
          tooltip: 'Premium',
          onPressed: onPremium,
          icon: const Icon(
            Icons.workspace_premium_rounded,
            color: AppColors.star,
          ),
        ),
        const SizedBox(width: 2),
        InkWell(
          onTap: onProfile,
          customBorder: const CircleBorder(),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Icon(
              isGuest ? Icons.person_outline_rounded : Icons.person_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeSearchField extends StatelessWidget {
  const _HomeSearchField({required this.hint, required this.onTap});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkCard : Colors.white,
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded,
                  color: AppColors.textSecondary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestModeBanner extends StatelessWidget {
  const _GuestModeBanner({
    required this.title,
    required this.subtitle,
    required this.loginLabel,
    required this.onLogin,
  });

  final String title;
  final String subtitle;
  final String loginLabel;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardSelected,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        onTap: onLogin,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.person_add_alt_1_rounded,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                loginLabel,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected
          ? AppColors.primary
          : (isDark ? AppColors.darkCard : Colors.white),
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkBorder : AppColors.border),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white : AppColors.textPrimary),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExploreMapCard extends StatelessWidget {
  const _ExploreMapCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkCard : AppColors.cardSelected,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: SizedBox(
          height: 92,
          child: Stack(
            children: [
              Positioned(
                right: -8,
                top: -8,
                bottom: -8,
                width: 140,
                child: Opacity(
                  opacity: 0.35,
                  child: CustomPaint(painter: _MiniMapPainter()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.18)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final block = Paint()..color = AppColors.primary.withValues(alpha: 0.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(16, 18, size.width - 40, size.height - 36),
        const Radius.circular(12),
      ),
      block,
    );
    canvas.drawLine(Offset(20, size.height * 0.35),
        Offset(size.width - 20, size.height * 0.45), road);
    canvas.drawLine(Offset(size.width * 0.4, 12),
        Offset(size.width * 0.55, size.height - 12), road);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Calm, centered profile identity — Apple / Airbnb / Notion inspired.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.subtitle,
    required this.isGuest,
    this.membershipLabel,
  });

  final String displayName;
  final String subtitle;
  final bool isGuest;
  final String? membershipLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : '?';

    return Column(
      children: [
        const SizedBox(height: AppSpacing.lg),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? AppColors.darkCard
                    : AppColors.primary.withValues(alpha: 0.08),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : AppColors.primary,
                ),
              ),
            ),
            if (!isGuest)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md + 4),
        Text(
          displayName,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                height: 1.15,
              ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
          ),
        ],
        if (membershipLabel != null && membershipLabel!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            membershipLabel!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Divider(
          height: 1,
          thickness: 1,
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ],
    );
  }
}

/// Full-screen profile accessed from the home avatar.
class BuyerProfileScreen extends ConsumerWidget {
  const BuyerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final isGuest = session == null || session.isGuest;
    final displayName = (session?.name.trim().isNotEmpty ?? false)
        ? session!.name.trim()
        : l10n.buyerLabel;
    final email = session?.email ?? '';
    final subtitle = isGuest ? l10n.guestMode : email;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navProfile)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            _ProfileHeader(
              displayName: displayName,
              subtitle: subtitle,
              isGuest: isGuest,
              membershipLabel: isGuest ? null : l10n.margemMember,
            ),
            const SizedBox(height: AppSpacing.lg),
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
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(l10n.navMessages),
              onTap: () {
                context.pop();
                ref.read(buyerTabIndexProvider.notifier).state = 2;
              },
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
                  ref.read(themeModeProvider.notifier).toggleLightDark();
                },
              ),
            ),
            if (!isGuest)
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined,
                    color: AppColors.danger),
                title: Text(
                  l10n.deleteAccount,
                  style: const TextStyle(color: AppColors.danger),
                ),
                onTap: () => _confirmDeleteAccount(context, ref),
              ),
            const SizedBox(height: AppSpacing.xl),
            if (isGuest)
              FilledButton(
                onPressed: () => context.go('/login'),
                child: Text(l10n.logIn),
              )
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
    BuildContext context,
    WidgetRef ref,
  ) async {
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
            child: Text(l10n.cancel),
          ),
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
        await showAppErrorDialog(
          context,
          title: l10n.somethingWentWrong,
          message: e.toString(),
        );
      }
    }
  }
}
