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
  Future<List<SellerModel>>? _future;
  final _focusNode = FocusNode();

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

  Future<List<SellerModel>> _load() {
    final city = ref.read(buyerCityProvider);
    return apiServiceProvider.fetchSellers(city: city, query: _debounced);
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
                Text(l10n.search, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
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
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<SellerModel>>(
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
                final sellers = snapshot.data ?? [];
                if (sellers.isEmpty) {
                  return Center(child: Text(l10n.noBusinessesFound));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
                  itemCount: sellers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) {
                    final seller = sellers[index];
                    return ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      title: Text(seller.businessName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${seller.city} · ${seller.averageRating} ★'),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
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
