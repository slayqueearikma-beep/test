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
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/marketplace_actions.dart';
import '../../core/widgets/network_image_view.dart';
import '../../core/widgets/product_carousel_card.dart';
import '../../l10n/app_localizations.dart';
import '../wishlist/wishlist_screen.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.sellerId,
    required this.productId,
  });

  final String sellerId;
  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  late Future<SellerModel> _future;
  bool _contacting = false;
  bool _addingFavorite = false;
  bool _isFavorite = false;
  final _galleryController = PageController();
  var _galleryIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = apiServiceProvider.fetchSeller(widget.sellerId);
    final session = ref.read(userSessionProvider);
    if (session != null && !session.isGuest) {
      apiServiceProvider
          .trackRecentlyViewed(
              sellerId: widget.sellerId, productId: widget.productId)
          .catchError((_) {});
    }
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  List<String> _galleryUrls(ProductModel product) {
    final urls = <String>[
      if (product.imageUrl.trim().isNotEmpty) product.imageUrl.trim(),
      ...product.mediaUrls.where((u) => u.trim().isNotEmpty),
    ];
    return urls.toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SellerModel>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: AsyncErrorView.fromError(
              snapshot.error ?? Exception(context.l10n.somethingWentWrong),
              onRetry: () => setState(() {
                _future = apiServiceProvider.fetchSeller(widget.sellerId);
              }),
            ),
          );
        }

        final seller = snapshot.data!;
        final matches =
            seller.products.where((p) => p.id == widget.productId).toList();
        if (matches.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.products)),
            body: Center(child: Text(context.l10n.noProductsListed)),
          );
        }
        final product = matches.first;
        final l10n = context.l10n;
        final gallery = _galleryUrls(product);
        final related = sortProductsForCarousel(
          seller.products.where((p) => p.id != product.id).toList(),
        );

        return Scaffold(
          body: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      expandedHeight: MediaQuery.sizeOf(context).width * 0.95,
                      flexibleSpace: FlexibleSpaceBar(
                        background: gallery.isEmpty
                            ? const ColoredBox(
                                color: AppColors.surfaceMuted,
                                child: Center(
                                  child: Icon(Icons.image_outlined, size: 48),
                                ),
                              )
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  PageView.builder(
                                    controller: _galleryController,
                                    itemCount: gallery.length,
                                    onPageChanged: (i) =>
                                        setState(() => _galleryIndex = i),
                                    itemBuilder: (_, index) => Hero(
                                      tag: 'product-${product.id}',
                                      child: NetworkImageView(
                                        url: gallery[index],
                                        placeholderIcon:
                                            Icons.shopping_bag_outlined,
                                      ),
                                    ),
                                  ),
                                  if (gallery.length > 1)
                                    Positioned(
                                      bottom: 16,
                                      left: 0,
                                      right: 0,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: List.generate(
                                          gallery.length,
                                          (i) => AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 200),
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 3),
                                            width: i == _galleryIndex ? 18 : 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              color: i == _galleryIndex
                                                  ? Colors.white
                                                  : Colors.white54,
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenHorizontal,
                          AppSpacing.lg,
                          AppSpacing.screenHorizontal,
                          AppSpacing.xxl,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.priceMad == null
                                  ? l10n.priceOnRequest
                                  : '${product.priceMad!.toStringAsFixed(2)} MAD',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                RatingBarIndicator(
                                  rating: seller.averageRating,
                                  itemBuilder: (_, __) => const Icon(
                                    Icons.star_rounded,
                                    color: AppColors.star,
                                  ),
                                  itemCount: 5,
                                  itemSize: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  seller.averageRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            InkWell(
                              onTap: () =>
                                  context.push('/seller/${seller.id}'),
                              borderRadius: BorderRadius.circular(16),
                              child: MarketSectionCard(
                                title: l10n.seller,
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textSecondary,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: AppColors.cardSelected,
                                      child: ClipOval(
                                        child: SizedBox(
                                          width: 48,
                                          height: 48,
                                          child: NetworkImageView(
                                            url: seller.logoImageUrl.isNotEmpty
                                                ? seller.logoImageUrl
                                                : seller.coverImageUrl,
                                            placeholderIcon:
                                                Icons.storefront_rounded,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  seller.businessName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              if (seller.verificationStatus ==
                                                  'verified')
                                                const Padding(
                                                  padding:
                                                      EdgeInsets.only(left: 4),
                                                  child: Icon(
                                                    Icons.verified_rounded,
                                                    color: Colors.blue,
                                                    size: 18,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            l10n.reviewsCount(
                                                seller.reviewCount),
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              l10n.description,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.description.isEmpty
                                  ? l10n.noDescription
                                  : product.description,
                              style: const TextStyle(height: 1.45),
                            ),
                            if (product.priceNegotiable) ...[
                              const SizedBox(height: AppSpacing.md),
                              MarketInfoChip(
                                icon: Icons.handshake_outlined,
                                label: l10n.priceNegotiable,
                              ),
                            ],
                            if ((product.acceptedPaymentMethods.isNotEmpty
                                    ? product.acceptedPaymentMethods
                                    : seller.paymentMethods)
                                .isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                l10n.acceptedPaymentMethods,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: (product.acceptedPaymentMethods
                                            .isNotEmpty
                                        ? product.acceptedPaymentMethods
                                        : seller.paymentMethods)
                                    .map(
                                      (m) => MarketInfoChip(
                                        icon: Icons.payments_outlined,
                                        label: m.replaceAll('_', ' '),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                            if (related.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xl),
                              Text(
                                l10n.moreFromSeller,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              ProductCarouselStrip(
                                products: related,
                                rating: seller.averageRating > 0
                                    ? seller.averageRating
                                    : null,
                                verified:
                                    seller.verificationStatus == 'verified',
                                onProductTap: (item) => context.push(
                                  '/product/${seller.id}/${item.id}',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    10,
                    AppSpacing.screenHorizontal,
                    10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: MarketPrimaryButton(
                          label: l10n.contactSeller,
                          icon: Icons.chat_bubble_rounded,
                          loading: _contacting,
                          onPressed: () => _openChat(seller),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MarketPrimaryButton(
                          label: l10n.callSeller,
                          icon: Icons.call_rounded,
                          onPressed: seller.phone.isEmpty
                              ? null
                              : () => _callSeller(seller),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: AppColors.surfaceMuted,
                        borderRadius:
                            BorderRadius.circular(MarketButtonMetrics.radius),
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(MarketButtonMetrics.radius),
                          onTap: _addingFavorite
                              ? null
                              : () => _addToFavorites(product, seller),
                          child: SizedBox(
                            width: MarketButtonMetrics.height,
                            height: MarketButtonMetrics.height,
                            child: _addingFavorite
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: Icon(
                                      _isFavorite
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      key: ValueKey(_isFavorite),
                                      color: _isFavorite
                                          ? AppColors.danger
                                          : AppColors.primary,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openChat(SellerModel seller) async {
    final l10n = context.l10n;
    setState(() => _contacting = true);
    try {
      await apiServiceProvider.createContactEvent(
          sellerId: seller.id, channel: 'message');
      final session = ref.read(userSessionProvider);
      if (session == null || session.isGuest) {
        if (mounted) await context.push('/login');
        return;
      }
      final conversation =
          await apiServiceProvider.openSellerConversation(seller.id);
      if (!mounted) return;
      context.push('/messages/${conversation.id}', extra: conversation);
    } on ApiException catch (error) {
      if (mounted) {
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: error.message);
      }
    } finally {
      if (mounted) setState(() => _contacting = false);
    }
  }

  Future<void> _callSeller(SellerModel seller) async {
    try {
      await apiServiceProvider.createContactEvent(
          sellerId: seller.id, channel: 'call');
    } catch (_) {}
    final uri = Uri(scheme: 'tel', path: seller.phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.phoneNumber}: ${seller.phone}')),
      );
    }
  }

  Future<void> _addToFavorites(ProductModel product, SellerModel seller) async {
    final l10n = context.l10n;
    final session = ref.read(userSessionProvider);
    setState(() => _addingFavorite = true);
    if (session == null || session.isGuest) {
      final storage = ref.read(appStorageProvider);
      await storage?.addGuestFavoriteItem(
        GuestFavoriteItem(
          productId: product.id,
          sellerId: seller.id,
          name: product.name,
          price: product.priceMad ?? 0,
          imageUrl: product.imageUrl,
          sellerName: seller.businessName,
        ),
      );
      if (mounted) {
        setState(() {
          _isFavorite = true;
          _addingFavorite = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.addedToFavorites)));
      }
      return;
    }
    try {
      await apiServiceProvider.addFavoriteProduct(product.id);
      ref.invalidate(favoritesProvider);
      if (mounted) {
        setState(() => _isFavorite = true);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.addedToFavorites)));
      }
    } on ApiException catch (error) {
      if (mounted) {
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: error.message);
      }
    } finally {
      if (mounted) setState(() => _addingFavorite = false);
    }
  }
}
