import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/network_image_view.dart';
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
              if (product.priceNegotiable)
                Chip(
                  avatar: const Icon(Icons.handshake_outlined, size: 18),
                  label: Text(context.l10n.priceNegotiable),
                ),
              if (product.acceptedPaymentMethods.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${context.l10n.acceptedPaymentMethods}: ${product.acceptedPaymentMethods.join(', ')}',
                ),
              ] else if (seller.paymentMethods.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${context.l10n.acceptedPaymentMethods}: ${seller.paymentMethods.join(', ')}',
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _contacting
                    ? null
                    : () => _recordContact(seller, 'message'),
                icon: _contacting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chat_bubble_outline),
                label: Text(context.l10n.contactSeller),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed:
                    seller.phone.isEmpty ? null : () => _callSeller(seller),
                icon: const Icon(Icons.call_outlined),
                label: Text(context.l10n.callSeller),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _addingFavorite
                    ? null
                    : () => _addToFavorites(product, seller),
                icon: _addingFavorite
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.favorite_border),
                label: Text(context.l10n.addToFavorites),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _recordContact(SellerModel seller, String channel) async {
    final l10n = context.l10n;
    setState(() => _contacting = true);
    try {
      await apiServiceProvider.createContactEvent(
          sellerId: seller.id, channel: channel);
      if (channel == 'message') {
        final session = ref.read(userSessionProvider);
        if (session == null || session.isGuest) {
          if (mounted) await context.push('/login');
          return;
        }
        final message = await apiServiceProvider.startConversationWithSeller(
          seller.id,
          l10n.inquiryAboutListing(_productName(seller)),
        );
        if (!mounted) return;
        context.push('/messages/${message.conversationId}');
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.contactRecorded(seller.businessName))),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: error.message);
      }
    } finally {
      if (mounted) setState(() => _contacting = false);
    }
  }

  String _productName(SellerModel seller) {
    final match = seller.products.where((p) => p.id == widget.productId);
    if (match.isEmpty) return seller.businessName;
    return match.first.name;
  }

  Future<void> _callSeller(SellerModel seller) async {
    await _recordContact(seller, 'call');
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.addedToFavorites)));
        setState(() => _addingFavorite = false);
      }
      return;
    }
    try {
      await apiServiceProvider.addFavoriteProduct(product.id);
      ref.invalidate(favoritesProvider);
      if (mounted) {
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
