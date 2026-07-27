import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/achievement_badges.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/marketplace_actions.dart';
import '../../core/widgets/network_image_view.dart';
import '../../core/widgets/product_carousel_card.dart';
import '../../l10n/app_localizations.dart';
import 'rate_seller_sheet.dart';

class SellerDetailScreen extends ConsumerStatefulWidget {
  const SellerDetailScreen({super.key, required this.sellerId});

  final String sellerId;

  @override
  ConsumerState<SellerDetailScreen> createState() => _SellerDetailScreenState();
}

class _SellerDetailScreenState extends ConsumerState<SellerDetailScreen> {
  late Future<SellerModel> _sellerFuture;
  late Future<List<ReviewModel>> _reviewsFuture;
  var _following = false;
  var _messaging = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(userSessionProvider);
    final asOwner = session?.accountType == AccountType.seller;
    _sellerFuture =
        apiServiceProvider.fetchSeller(widget.sellerId, auth: asOwner);
    _reviewsFuture = apiServiceProvider.fetchReviews(widget.sellerId);
  }

  void _reload() {
    final session = ref.read(userSessionProvider);
    final asOwner = session?.accountType == AccountType.seller;
    setState(() {
      _sellerFuture =
          apiServiceProvider.fetchSeller(widget.sellerId, auth: asOwner);
      _reviewsFuture = apiServiceProvider.fetchReviews(widget.sellerId);
    });
  }

  Future<void> _openDirections(SellerModel seller) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${seller.latitude},${seller.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _messageSeller(SellerModel seller) async {
    final l10n = context.l10n;
    final session = ref.read(userSessionProvider);
    if (session == null || session.isGuest) {
      if (!mounted) return;
      await context.push('/login');
      return;
    }
    final mySellerId = session.sellerId;
    if (mySellerId != null &&
        mySellerId.isNotEmpty &&
        mySellerId == seller.id) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cannotMessageOwnStore)),
      );
      return;
    }
    setState(() => _messaging = true);
    try {
      await apiServiceProvider.createContactEvent(
        sellerId: seller.id,
        channel: 'message',
      );
      final conversation =
          await apiServiceProvider.openSellerConversation(seller.id);
      if (!mounted) return;
      context.push('/messages/${conversation.id}', extra: conversation);
    } catch (_) {
      if (!mounted) return;
      await showAppErrorDialog(context,
          title: l10n.somethingWentWrong, message: l10n.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _messaging = false);
    }
  }

  Future<void> _recordContact(SellerModel seller, String channel) async {
    try {
      await apiServiceProvider.createContactEvent(
        sellerId: seller.id,
        channel: channel,
      );
    } catch (_) {}
  }

  Future<void> _callSeller(SellerModel seller) async {
    final phone = seller.phone.trim();
    if (phone.isEmpty) return;
    await _recordContact(seller, 'call');
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _followSeller(SellerModel seller) async {
    final l10n = context.l10n;
    final session = ref.read(userSessionProvider);
    if (session == null || session.isGuest) {
      if (!mounted) return;
      await context.push('/login');
      return;
    }
    setState(() => _following = true);
    try {
      await apiServiceProvider.followSeller(seller.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.nowFollowing(seller.businessName))),
      );
      _reload();
    } catch (_) {
      if (!mounted) return;
      await showAppErrorDialog(context,
          title: l10n.somethingWentWrong, message: l10n.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _following = false);
    }
  }

  Future<void> _openRateSeller(SellerModel seller) async {
    final l10n = context.l10n;
    final session = ref.read(userSessionProvider);
    if (session == null || session.isGuest) {
      if (!mounted) return;
      await context.push('/login');
      return;
    }
    if (session.sellerId != null &&
        session.sellerId!.isNotEmpty &&
        session.sellerId == seller.id) {
      if (!mounted) return;
      await showAppErrorDialog(context,
          title: l10n.somethingWentWrong, message: l10n.cannotReviewOwnStore);
      return;
    }

    try {
      final eligibility =
          await apiServiceProvider.fetchReviewEligibility(seller.id);
      if (!mounted) return;
      if (!eligibility.canReview) {
        final message = switch (eligibility.reason) {
          'own_store' => l10n.cannotReviewOwnStore,
          'email_unverified' => l10n.verifyEmailToContinue,
          'no_completed_transaction' => l10n.reviewRequiresCompletedTransaction,
          _ => l10n.somethingWentWrong,
        };
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: message);
        return;
      }

      final submitted = await showRateSellerSheet(
        context: context,
        seller: seller,
      );
      if (!mounted) return;
      if (submitted) {
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.reviewSubmittedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on Object catch (_) {
      if (!mounted) return;
      await showAppErrorDialog(context,
          title: l10n.somethingWentWrong, message: l10n.somethingWentWrong);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<SellerModel>(
        future: _sellerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AsyncErrorView.fromError(snapshot.error!, onRetry: _reload);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final seller = snapshot.data!;
          final l10n = context.l10n;
          final session = ref.watch(userSessionProvider);
          final isOwnStore = session?.sellerId != null &&
              session!.sellerId!.isNotEmpty &&
              session.sellerId == seller.id;
          final carouselProducts = sortProductsForCarousel(seller.products);
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                stretch: true,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.fadeTitle,
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      NetworkImageView(
                        url: seller.coverImageUrl.isNotEmpty
                            ? seller.coverImageUrl
                            : seller.logoImageUrl,
                        placeholderIcon: Icons.storefront_rounded,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.05),
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              sliverPadding(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SellerHeader(seller: seller, l10n: l10n),
                    const SizedBox(height: AppSpacing.lg),
                    if (seller.description.trim().isNotEmpty) ...[
                      Text(
                        seller.description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.45,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    MarketSectionCard(
                      title: l10n.businessInformation,
                      child: Column(
                        children: [
                          _InfoTile(
                            icon: Icons.location_on_outlined,
                            label: seller.address.isEmpty
                                ? seller.city
                                : seller.address,
                          ),
                          if (seller.phone.isNotEmpty)
                            _InfoTile(
                              icon: Icons.phone_outlined,
                              label: seller.phone,
                            ),
                          if (seller.whatsappNumber.isNotEmpty)
                            _InfoTile(
                              icon: Icons.chat_outlined,
                              label: seller.whatsappNumber,
                            ),
                          if (!seller.openingHours.isEmpty)
                            _InfoTile(
                              icon: Icons.schedule_outlined,
                              label:
                                  '${l10n.opens} ${seller.openingHours.open} · ${l10n.closes} ${seller.openingHours.close}',
                            ),
                        ],
                      ),
                    ),
                    if (seller.paymentMethods.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      MarketSectionCard(
                        title: l10n.acceptedPaymentMethods,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: seller.paymentMethods
                              .map(
                                (m) => MarketInfoChip(
                                  icon: Icons.payments_outlined,
                                  label: m.replaceAll('_', ' '),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                    if (seller.deliveryMethods.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      MarketSectionCard(
                        title: l10n.deliveryOptionsLabel,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: seller.deliveryMethods
                              .map(
                                (m) => MarketInfoChip(
                                  icon: Icons.local_shipping_outlined,
                                  label: m.replaceAll('_', ' '),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: MarketPrimaryButton(
                            label: l10n.directions,
                            icon: Icons.directions_rounded,
                            onPressed: () => _openDirections(seller),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MarketPrimaryButton(
                            label: l10n.callSeller,
                            icon: Icons.call_rounded,
                            onPressed: seller.phone.trim().isEmpty
                                ? null
                                : () => _callSeller(seller),
                          ),
                        ),
                      ],
                    ),
                    if (!isOwnStore) ...[
                      const SizedBox(height: 10),
                      MarketPrimaryButton(
                        label: l10n.messageBusiness,
                        icon: Icons.chat_bubble_rounded,
                        loading: _messaging,
                        onPressed: () => _messageSeller(seller),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: MarketSecondaryButton(
                              label: l10n.followBusiness,
                              icon: Icons.person_add_alt_1_rounded,
                              loading: _following,
                              onPressed: () => _followSeller(seller),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: MarketSecondaryButton(
                              label: l10n.rateSeller,
                              icon: Icons.star_outline_rounded,
                              onPressed: () => _openRateSeller(seller),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.products,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (seller.products.isNotEmpty)
                          TextButton(
                            onPressed: () => context.push(
                              '/seller/${seller.id}/products',
                              extra: seller,
                            ),
                            child: Text(l10n.viewAllProducts),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (carouselProducts.isEmpty)
                      Text(l10n.noProductsListed)
                    else
                      ProductCarouselStrip(
                        products: carouselProducts,
                        rating: seller.averageRating > 0
                            ? seller.averageRating
                            : null,
                        verified: seller.verificationStatus == 'verified',
                        onProductTap: (product) => context.push(
                          '/product/${seller.id}/${product.id}',
                        ),
                      ),
                    if (seller.products.length > carouselProducts.length) ...[
                      const SizedBox(height: AppSpacing.md),
                      MarketSecondaryButton(
                        label: l10n.viewAllProducts,
                        icon: Icons.grid_view_rounded,
                        onPressed: () => context.push(
                          '/seller/${seller.id}/products',
                          extra: seller,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      l10n.services,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (seller.services.isEmpty)
                      Text(l10n.noServicesListed)
                    else
                      ...seller.services.map(
                        (service) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(service.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(service.description),
                          trailing: service.priceMad != null
                              ? Text(
                                  '${service.priceMad!.toStringAsFixed(0)} MAD',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      l10n.reviews,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FutureBuilder<List<ReviewModel>>(
                      future: _reviewsFuture,
                      builder: (context, reviewSnapshot) {
                        if (reviewSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        if (reviewSnapshot.hasError) {
                          return Text(l10n.somethingWentWrong);
                        }
                        final reviews = reviewSnapshot.data ?? [];
                        return _ReviewsPreview(
                          seller: seller,
                          reviews: reviews,
                          l10n: l10n,
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Widget sliverPadding({required Widget child}) {
  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.lg,
        AppSpacing.screenHorizontal,
        0,
      ),
      child: child,
    ),
  );
}

class _SellerHeader extends StatelessWidget {
  const _SellerHeader({required this.seller, required this.l10n});

  final SellerModel seller;
  final AppStrings l10n;

  @override
  Widget build(BuildContext context) {
    final avatar = seller.logoImageUrl.isNotEmpty
        ? seller.logoImageUrl
        : seller.coverImageUrl;
    final memberYear = seller.createdAt?.year;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: NetworkImageView(
            url: avatar,
            placeholderIcon: Icons.storefront_rounded,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      seller.businessName,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                    ),
                  ),
                  if (seller.verificationStatus == 'verified')
                    const Icon(Icons.verified_rounded,
                        color: Colors.blue, size: 22),
                  if (seller.isPremium)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.workspace_premium_rounded,
                          color: AppColors.goldenCrown, size: 22),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  RatingBarIndicator(
                    rating: seller.averageRating,
                    itemBuilder: (_, __) =>
                        const Icon(Icons.star_rounded, color: AppColors.star),
                    itemCount: 5,
                    itemSize: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${seller.averageRating.toStringAsFixed(1)} · ${l10n.reviewsCount(seller.reviewCount)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _MetaPill(
                    icon: Icons.group_outlined,
                    label: l10n.followersCount(seller.followerCount),
                  ),
                  if (seller.favoriteCount > 0)
                    _MetaPill(
                      icon: Icons.favorite_rounded,
                      label: l10n.favoritesCount(seller.favoriteCount),
                    ),
                  if (memberYear != null)
                    _MetaPill(
                      icon: Icons.calendar_month_outlined,
                      label: l10n.memberSince(memberYear),
                    ),
                  if (seller.avgResponseMinutes > 0)
                    _MetaPill(
                      icon: Icons.timer_outlined,
                      label: l10n.responseTimeLabel(seller.avgResponseMinutes),
                    ),
                  AchievementBadges(
                    goldenCrowns: seller.goldenCrowns,
                    achievementStars: seller.achievementStars,
                    iconSize: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(height: 1.35, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsPreview extends StatelessWidget {
  const _ReviewsPreview({
    required this.seller,
    required this.reviews,
    required this.l10n,
  });

  final SellerModel seller;
  final List<ReviewModel> reviews;
  final AppStrings l10n;

  Map<int, int> _distribution() {
    final counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final r in reviews) {
      final star = r.overallRating.round().clamp(1, 5);
      counts[star] = (counts[star] ?? 0) + 1;
    }
    return counts;
  }

  void _showAllReviews(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return ListView.separated(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: reviews.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 24),
              itemBuilder: (_, index) {
                if (index == 0) {
                  return Text(
                    l10n.reviews,
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  );
                }
                final r = reviews[index - 1];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.buyerDisplayName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        RatingBarIndicator(
                          rating: r.overallRating,
                          itemBuilder: (_, __) => const Icon(
                            Icons.star_rounded,
                            color: AppColors.star,
                          ),
                          itemCount: 5,
                          itemSize: 14,
                        ),
                      ],
                    ),
                    if (r.comment.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(r.comment, style: const TextStyle(height: 1.4)),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Column(
          children: [
            Icon(
              Icons.reviews_outlined,
              size: 48,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.beFirstToReview,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    final preview = reviews.take(2).toList();
    final dist = _distribution();
    final maxCount = dist.values.fold<int>(1, (a, b) => a > b ? a : b);

    return MarketSectionCard(
      title: l10n.recentReviews,
      trailing: Text(
        seller.averageRating.toStringAsFixed(1),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(
                    seller.averageRating.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                  ),
                  RatingBarIndicator(
                    rating: seller.averageRating,
                    itemBuilder: (_, __) =>
                        const Icon(Icons.star_rounded, color: AppColors.star),
                    itemCount: 5,
                    itemSize: 16,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.reviewsCount(seller.reviewCount),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: List.generate(5, (i) {
                    final star = 5 - i;
                    final count = dist[star] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 12,
                            child: Text(
                              '$star',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: count / maxCount,
                                minHeight: 7,
                                backgroundColor: AppColors.surfaceMuted,
                                color: AppColors.star,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...preview.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.buyerDisplayName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      RatingBarIndicator(
                        rating: r.overallRating,
                        itemBuilder: (_, __) => const Icon(
                          Icons.star_rounded,
                          color: AppColors.star,
                        ),
                        itemCount: 5,
                        itemSize: 14,
                      ),
                    ],
                  ),
                  if (r.comment.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      r.comment,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (reviews.length > 2)
            MarketSecondaryButton(
              label: l10n.seeAllReviews,
              icon: Icons.rate_review_outlined,
              onPressed: () => _showAllReviews(context),
            ),
        ],
      ),
    );
  }
}
