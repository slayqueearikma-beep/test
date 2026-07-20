import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/network_image_view.dart';
import '../../l10n/app_localizations.dart';
import 'cart_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cart)),
      body: cartAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView.fromError(
          error,
          onRetry: () => ref.read(cartProvider.notifier).reload(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return _EmptyCart(
              onBrowse: () => context.go('/buyer/home'),
            );
          }
          final summary = CartSummary(items);
          return Column(
            children: [
              if (session == null || session.isGuest)
                MaterialBanner(
                  content: Text(l10n.guestCartSignInHint),
                  leading: const Icon(Icons.person_add_alt_1_outlined),
                  actions: [
                    TextButton(
                        onPressed: () => context.push('/login'),
                        child: Text(l10n.logIn)),
                  ],
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.read(cartProvider.notifier).reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) =>
                        _CartItemTile(item: items[index]),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(l10n.subtotal,
                              style: Theme.of(context).textTheme.titleMedium),
                          const Spacer(),
                          Text(
                            '${summary.subtotalMad.toStringAsFixed(2)} MAD',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: session == null || session.isGuest
                            ? () => context.push('/login')
                            : () => context.push('/checkout'),
                        icon: const Icon(Icons.lock_open_rounded),
                        label: Text(session == null || session.isGuest
                            ? l10n.signInToCheckout
                            : l10n.checkout),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item});

  final CartLineItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 78,
                height: 78,
                child: NetworkImageView(
                    url: item.imageUrl,
                    placeholderIcon: Icons.shopping_bag_outlined),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (item.sellerName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(item.sellerName,
                        style: TextStyle(color: muted, fontSize: 12)),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text('${item.unitPriceMad.toStringAsFixed(2)} MAD',
                      style: const TextStyle(color: AppColors.primary)),
                  if (!item.isAvailable)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(l10n.unavailable,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 12)),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _QtyButton(
                        icon: Icons.remove,
                        onTap: item.quantity <= 1
                            ? null
                            : () => _update(context, ref, item.quantity - 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm),
                        child: Text('${item.quantity}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      _QtyButton(
                        icon: Icons.add,
                        onTap: item.quantity >= item.stockQuantity
                            ? null
                            : () => _update(context, ref, item.quantity + 1),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: l10n.remove,
                        onPressed: () => _remove(context, ref),
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.danger),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _update(
      BuildContext context, WidgetRef ref, int quantity) async {
    final l10n = context.l10n;
    try {
      await ref.read(cartProvider.notifier).updateQuantity(item, quantity);
    } on ApiException catch (error) {
      if (context.mounted) {
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: error.message);
      }
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      await ref.read(cartProvider.notifier).remove(item);
    } on ApiException catch (error) {
      if (context.mounted) {
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: error.message);
      }
    }
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.emptyCart,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.emptyCartSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
                onPressed: onBrowse,
                icon: const Icon(Icons.storefront),
                label: Text(l10n.browseProducts)),
          ],
        ),
      ),
    );
  }
}
