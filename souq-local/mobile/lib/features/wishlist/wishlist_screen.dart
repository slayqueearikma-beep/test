import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/network_image_view.dart';
import '../../l10n/app_localizations.dart';

final favoritesProvider =
    FutureProvider.autoDispose<List<FavoriteItemModel>>((ref) {
  final session = ref.watch(userSessionProvider);
  if (session == null || session.isGuest) {
    final storage = ref.watch(appStorageProvider);
    return Future.value(
      storage
              ?.getGuestFavoriteItems()
              .map(
                (item) => FavoriteItemModel(
                  id: item.productId,
                  productId: item.productId,
                  productName: item.name,
                  imageUrl: item.imageUrl,
                  priceMad: item.price == 0 ? null : item.price,
                  sellerId: item.sellerId,
                  sellerName: item.sellerName,
                ),
              )
              .toList() ??
          const [],
    );
  }
  return apiServiceProvider.fetchFavorites();
});

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.favorites)),
      body: favoritesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView.fromError(error,
            onRetry: () => ref.invalidate(favoritesProvider)),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border,
                        size: 56,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.emptyFavorites,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.emptyFavoritesSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                        onPressed: () => context.go('/buyer/home'),
                        child: Text(l10n.browseProducts)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(favoritesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  _FavoriteTile(item: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _FavoriteTile extends ConsumerWidget {
  const _FavoriteTile({required this.item});

  final FavoriteItemModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Card(
      child: ListTile(
        onTap: () =>
            context.push('/product/${item.sellerId}/${item.productId}'),
        contentPadding: const EdgeInsets.all(AppSpacing.sm),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 64,
            height: 64,
            child: NetworkImageView(
                url: item.imageUrl,
                placeholderIcon: Icons.shopping_bag_outlined),
          ),
        ),
        title: Text(item.productName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.sellerName.isNotEmpty) Text(item.sellerName),
            Text(item.priceMad == null
                ? l10n.priceOnRequest
                : '${item.priceMad!.toStringAsFixed(2)} MAD'),
          ],
        ),
        trailing: IconButton(
          tooltip: l10n.remove,
          icon: const Icon(Icons.favorite, color: AppColors.danger),
          onPressed: () => _remove(context, ref),
        ),
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      final session = ref.read(userSessionProvider);
      if (session == null || session.isGuest) {
        await ref
            .read(appStorageProvider)
            ?.removeGuestFavoriteItem(item.productId);
      } else {
        await apiServiceProvider.removeFavoriteProduct(item.productId);
      }
      ref.invalidate(favoritesProvider);
    } on ApiException catch (error) {
      if (context.mounted) {
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: error.message);
      }
    }
  }
}
