import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'network_image_view.dart';

class ProductCarouselCard extends StatelessWidget {
  const ProductCarouselCard({
    super.key,
    required this.product,
    required this.onTap,
    this.rating,
    this.verified = false,
    this.width,
    this.expand = false,
    this.onFavorite,
    this.isFavorite = false,
  });

  final ProductModel product;
  final VoidCallback onTap;
  final double? rating;
  final bool verified;
  final double? width;
  final bool expand;
  final VoidCallback? onFavorite;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.sizeOf(context).width;
    // ~3 cards visible with gutters (marketplace carousel standard).
    final cardWidth = width ?? ((screenW - 48) / 3).clamp(118.0, 168.0);

    final card = Material(
      color: isDark ? AppColors.darkCard : Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetworkImageView(
                      url: product.imageUrl,
                      placeholderIcon: Icons.shopping_bag_outlined,
                    ),
                    if (onFavorite != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.92),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onFavorite,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: Icon(
                                  isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  key: ValueKey(isFavorite),
                                  size: 18,
                                  color: isFavorite
                                      ? AppColors.danger
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (verified)
                      const Positioned(
                        top: 8,
                        left: 8,
                        child: Icon(
                          Icons.verified_rounded,
                          color: Colors.blue,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.priceMad == null
                          ? '—'
                          : '${product.priceMad!.toStringAsFixed(0)} MAD',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (rating != null && rating! > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          RatingBarIndicator(
                            rating: rating!,
                            itemBuilder: (_, __) => const Icon(
                              Icons.star_rounded,
                              color: AppColors.star,
                            ),
                            itemCount: 5,
                            itemSize: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (expand) return card;
    return SizedBox(width: cardWidth, child: card);
  }
}

/// Top products for seller profile preview carousels (max 7).
List<ProductModel> sortProductsForCarousel(List<ProductModel> products) {
  final sorted = [...products.where((p) => p.isAvailable && !p.isPaused)];
  sorted.sort((a, b) {
    if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
    final ap = a.priceMad ?? -1;
    final bp = b.priceMad ?? -1;
    final byPrice = bp.compareTo(ap);
    if (byPrice != 0) return byPrice;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return sorted.take(7).toList();
}

/// Snaps horizontal scroll to card boundaries.
class CarouselSnapPhysics extends ScrollPhysics {
  const CarouselSnapPhysics({required this.itemExtent, super.parent});

  final double itemExtent;

  @override
  CarouselSnapPhysics applyTo(ScrollPhysics? ancestor) {
    return CarouselSnapPhysics(
      itemExtent: itemExtent,
      parent: buildParent(ancestor),
    );
  }

  double _getTargetPixels(ScrollMetrics position, double velocity) {
    final page = position.pixels / itemExtent;
    final targetPage = velocity < -200
        ? page.floorToDouble()
        : velocity > 200
            ? page.ceilToDouble()
            : page.roundToDouble();
    return (targetPage * itemExtent)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    final target = _getTargetPixels(position, velocity);
    if ((target - position.pixels).abs() < 0.5) {
      return super.createBallisticSimulation(position, velocity);
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }
}

/// Horizontal product strip with card snapping (~⅓ screen width).
class ProductCarouselStrip extends StatelessWidget {
  const ProductCarouselStrip({
    super.key,
    required this.products,
    required this.onProductTap,
    this.rating,
    this.verified = false,
    this.height = 268,
  });

  final List<ProductModel> products;
  final void Function(ProductModel product) onProductTap;
  final double? rating;
  final bool verified;
  final double height;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final cardW = ((screenW - 48) / 3).clamp(118.0, 168.0);
    const gap = 12.0;

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: CarouselSnapPhysics(
          itemExtent: cardW + gap,
          parent: const BouncingScrollPhysics(),
        ),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: gap),
        itemBuilder: (context, index) {
          final product = products[index];
          return ProductCarouselCard(
            product: product,
            width: cardW,
            rating: rating,
            verified: verified,
            onTap: () => onProductTap(product),
          );
        },
      ),
    );
  }
}
