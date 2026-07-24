import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/product_carousel_card.dart';
import '../../l10n/app_localizations.dart';

enum _CatalogSort { newest, popular, priceLow, priceHigh }

class SellerCatalogScreen extends ConsumerStatefulWidget {
  const SellerCatalogScreen({
    super.key,
    required this.sellerId,
    this.initialSeller,
  });

  final String sellerId;
  final SellerModel? initialSeller;

  @override
  ConsumerState<SellerCatalogScreen> createState() => _SellerCatalogScreenState();
}

class _SellerCatalogScreenState extends ConsumerState<SellerCatalogScreen> {
  late Future<SellerModel> _future;
  final _search = TextEditingController();
  _CatalogSort _sort = _CatalogSort.popular;

  @override
  void initState() {
    super.initState();
    _future = widget.initialSeller != null
        ? Future.value(widget.initialSeller)
        : apiServiceProvider.fetchSeller(widget.sellerId);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ProductModel> _filter(SellerModel seller) {
    final q = _search.text.trim().toLowerCase();
    var items = seller.products
        .where((p) => p.isAvailable && !p.isPaused)
        .where((p) =>
            q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q))
        .toList();

    switch (_sort) {
      case _CatalogSort.newest:
        // API list order is already newest-first for created products in most cases.
        break;
      case _CatalogSort.popular:
        items.sort((a, b) {
          if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
          return a.name.compareTo(b.name);
        });
      case _CatalogSort.priceLow:
        items.sort((a, b) =>
            (a.priceMad ?? double.infinity).compareTo(b.priceMad ?? double.infinity));
      case _CatalogSort.priceHigh:
        items.sort((a, b) =>
            (b.priceMad ?? -1).compareTo(a.priceMad ?? -1));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.allProducts)),
      body: FutureBuilder<SellerModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return AsyncErrorView.fromError(
              snapshot.error ?? Exception(l10n.somethingWentWrong),
              onRetry: () => setState(() {
                _future = apiServiceProvider.fetchSeller(widget.sellerId);
              }),
            );
          }
          final seller = snapshot.data!;
          final products = _filter(seller);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.sm,
                  AppSpacing.screenHorizontal,
                  AppSpacing.sm,
                ),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: l10n.searchProductsHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear_rounded),
                          ),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                child: Row(
                  children: [
                    _SortChip(
                      label: l10n.sortPopular,
                      selected: _sort == _CatalogSort.popular,
                      onTap: () => setState(() => _sort = _CatalogSort.popular),
                    ),
                    _SortChip(
                      label: l10n.sortNewest,
                      selected: _sort == _CatalogSort.newest,
                      onTap: () => setState(() => _sort = _CatalogSort.newest),
                    ),
                    _SortChip(
                      label: l10n.sortPriceLow,
                      selected: _sort == _CatalogSort.priceLow,
                      onTap: () => setState(() => _sort = _CatalogSort.priceLow),
                    ),
                    _SortChip(
                      label: l10n.sortPriceHigh,
                      selected: _sort == _CatalogSort.priceHigh,
                      onTap: () =>
                          setState(() => _sort = _CatalogSort.priceHigh),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: products.isEmpty
                    ? Center(child: Text(l10n.noProductsListed))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenHorizontal,
                          AppSpacing.sm,
                          AppSpacing.screenHorizontal,
                          AppSpacing.xxl,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.68,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return ProductCarouselCard(
                            product: product,
                            expand: true,
                            rating: seller.averageRating > 0
                                ? seller.averageRating
                                : null,
                            verified:
                                seller.verificationStatus == 'verified',
                            onTap: () => context.push(
                              '/product/${seller.id}/${product.id}',
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withValues(alpha: 0.14),
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
