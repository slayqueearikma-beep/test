import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/network_image_view.dart';
import '../../l10n/app_localizations.dart';
import '../cart/cart_provider.dart';
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
  bool _addingCart = false;
  bool _addingWishlist = false;

  @override
  void initState() {
    super.initState();
    _future = apiServiceProvider.fetchSeller(widget.sellerId);
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
            body: Center(child: Text(context.l10n.somethingWentWrong)),
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

        return Scaffold(
          appBar: AppBar(title: Text(product.name)),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: NetworkImageView(url: product.imageUrl),
                ),
              ),
              const SizedBox(height: 20),
              if (product.priceMad != null)
                Text(
                  '${product.priceMad!.toStringAsFixed(2)} MAD',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  RatingBarIndicator(
                    rating: seller.averageRating,
                    itemBuilder: (_, __) =>
                        const Icon(Icons.star, color: AppColors.star),
                    itemCount: 5,
                    itemSize: 18,
                  ),
                  const SizedBox(width: 8),
                  Text('${seller.averageRating} · ${seller.businessName}'),
                ],
              ),
              const SizedBox(height: 16),
              Text(product.description.isEmpty
                  ? context.l10n.noDescription
                  : product.description),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: product.isAvailable &&
                        product.priceMad != null &&
                        !_addingCart
                    ? () => _addToCart(product, seller)
                    : null,
                icon: _addingCart
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_shopping_cart_rounded),
                label: Text(product.priceMad == null
                    ? context.l10n.priceOnRequest
                    : context.l10n.addToCart),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed:
                    _addingWishlist ? null : () => _addToWishlist(product),
                icon: _addingWishlist
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.favorite_border),
                label: Text(context.l10n.addToWishlist),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addToCart(ProductModel product, SellerModel seller) async {
    final l10n = context.l10n;
    setState(() => _addingCart = true);
    try {
      await ref.read(cartProvider.notifier).addProduct(
            product: product,
            sellerId: seller.id,
            sellerName: seller.businessName,
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.addedToCart)));
      }
    } on ApiException catch (error) {
      if (mounted) {
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: error.message);
      }
    } finally {
      if (mounted) setState(() => _addingCart = false);
    }
  }

  Future<void> _addToWishlist(ProductModel product) async {
    final l10n = context.l10n;
    final session = ref.read(userSessionProvider);
    if (session == null || session.isGuest) {
      context.push('/login');
      return;
    }
    setState(() => _addingWishlist = true);
    try {
      await apiServiceProvider.addWishlistProduct(product.id);
      ref.invalidate(wishlistProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.addedToWishlist)));
      }
    } on ApiException catch (error) {
      if (mounted) {
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: error.message);
      }
    } finally {
      if (mounted) setState(() => _addingWishlist = false);
    }
  }
}
