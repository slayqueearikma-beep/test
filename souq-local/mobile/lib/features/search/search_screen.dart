import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/network_image_view.dart';
import '../../l10n/app_localizations.dart';
import '../buyer/buyer_home_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.autofocusSearch = false});

  final bool autofocusSearch;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _debounced = '';
  Timer? _timer;
  Future<MarketplaceSearchPage>? _future;
  final _focusNode = FocusNode();
  var _mode = 'products';

  @override
  void dispose() {
    _timer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autofocusSearch && !oldWidget.autofocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    } else if (!widget.autofocusSearch && oldWidget.autofocusSearch) {
      _focusNode.unfocus();
    }
  }

  Future<MarketplaceSearchPage> _load() {
    final city = ref.read(buyerCityProvider);
    return apiServiceProvider.searchMarketplace(
      query: _debounced,
      mode: _mode,
      city: city,
    );
  }

  void _onQueryChanged(String value) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _debounced = value.trim();
        _future = _load();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final city = ref.watch(buyerCityProvider);
    ref.listen(buyerCityProvider, (previous, next) {
      if (previous != next) {
        setState(() => _future = _load());
      }
    });
    _future ??= _load();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.search,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  city,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  focusNode: _focusNode,
                  autofocus: widget.autofocusSearch,
                  decoration: InputDecoration(
                    hintText: l10n.businessKeyword,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: _onQueryChanged,
                ),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'products',
                      label: Text(l10n.products),
                      icon: const Icon(Icons.inventory_2_outlined),
                    ),
                    ButtonSegment(
                      value: 'sellers',
                      label: Text(l10n.seller),
                      icon: const Icon(Icons.storefront_outlined),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (values) {
                    setState(() {
                      _mode = values.first;
                      _future = _load();
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<MarketplaceSearchPage>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return AsyncErrorView.fromError(
                    snapshot.error!,
                    onRetry: () {
                      setState(() {
                        _future = _load();
                      });
                    },
                  );
                }
                final page = snapshot.data;
                final isProducts = _mode == 'products';
                final count = isProducts
                    ? (page?.products.length ?? 0)
                    : (page?.sellers.length ?? 0);
                if (count == 0) {
                  return Center(child: Text(l10n.noBusinessesFound));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal),
                  itemCount: count,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) {
                    if (isProducts) {
                      final product = page!.products[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        tileColor: Theme.of(context).cardTheme.color,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: NetworkImageView(
                              url: product.imageUrl,
                              placeholderIcon: Icons.inventory_2_outlined,
                            ),
                          ),
                        ),
                        title: Text(product.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${product.sellerName} · ${product.sellerCity}'),
                        trailing: Text(
                          product.priceMad == null
                              ? '—'
                              : '${product.priceMad!.toStringAsFixed(0)} MAD',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800),
                        ),
                        onTap: () => context
                            .push('/product/${product.sellerId}/${product.id}'),
                      );
                    }
                    final seller = page!.sellers[index];
                    return ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      tileColor: Theme.of(context).cardTheme.color,
                      leading: ClipOval(
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: NetworkImageView(
                            url: seller.coverImageUrl,
                            placeholderIcon: Icons.storefront_rounded,
                          ),
                        ),
                      ),
                      title: Text(seller.businessName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle:
                          Text('${seller.city} · ${seller.averageRating} ★'),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondary),
                      onTap: () => context.push('/seller/${seller.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
