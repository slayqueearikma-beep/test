import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/network_image_view.dart';
import '../../l10n/app_localizations.dart';
import 'buyer_orders_screen.dart';

final orderDetailProvider =
    FutureProvider.autoDispose.family<OrderModel, String>((ref, id) {
  return apiServiceProvider.fetchOrder(id);
});

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _cancelling = false;

  Future<void> _cancelOrder() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelOrder),
        content: Text(l10n.cancelOrderConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.back)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.cancelOrder)),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _cancelling = true);
    try {
      await apiServiceProvider.cancelOrder(widget.orderId);
      ref.invalidate(orderDetailProvider(widget.orderId));
      ref.invalidate(buyerOrdersProvider);
    } on ApiException catch (error) {
      if (mounted) {
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: error.message);
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      appBar:
          AppBar(title: Text(l10n.orderNumber(shortOrderId(widget.orderId)))),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(orderDetailProvider(widget.orderId)),
        ),
        data: (order) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.sellerName.isEmpty
                                  ? l10n.orderDetails
                                  : order.sellerName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          OrderStatusChip(status: order.status),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(formatDate(order.createdAt),
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      const Divider(height: AppSpacing.lg),
                      _InfoRow(
                          label: l10n.subtotal,
                          value:
                              '${order.subtotalMad.toStringAsFixed(2)} ${order.currency}'),
                      _InfoRow(
                          label: l10n.deliveryFee,
                          value:
                              '${order.deliveryFeeMad.toStringAsFixed(2)} ${order.currency}'),
                      _InfoRow(
                        label: l10n.total,
                        value:
                            '${order.totalMad.toStringAsFixed(2)} ${order.currency}',
                        strong: true,
                      ),
                      _InfoRow(
                          label: l10n.paymentMethod,
                          value: order.paymentMethod.toUpperCase()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.items,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              ...order.items.map((item) =>
                  _OrderItemTile(item: item, currency: order.currency)),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.deliveryDetails,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      _InfoRow(
                          label: l10n.recipientName, value: order.deliveryName),
                      _InfoRow(
                          label: l10n.phoneNumber, value: order.deliveryPhone),
                      _InfoRow(
                          label: l10n.deliveryAddress,
                          value: order.deliveryAddress),
                      _InfoRow(label: l10n.city, value: order.deliveryCity),
                      if (order.buyerNote.isNotEmpty)
                        _InfoRow(label: l10n.orderNote, value: order.buyerNote),
                      if (order.sellerNote.isNotEmpty)
                        _InfoRow(
                            label: l10n.sellerNote, value: order.sellerNote),
                    ],
                  ),
                ),
              ),
              if (session?.accountType == AccountType.buyer &&
                  order.canBuyerCancel) ...[
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: _cancelling ? null : _cancelOrder,
                  icon: _cancelling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cancel_outlined,
                          color: AppColors.danger),
                  label: Text(l10n.cancelOrder,
                      style: const TextStyle(color: AppColors.danger)),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  const _OrderItemTile({required this.item, required this.currency});

  final OrderItemModel item;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 52,
            height: 52,
            child: NetworkImageView(
                url: item.imageUrl,
                placeholderIcon: Icons.shopping_bag_outlined),
          ),
        ),
        title: Text(item.productName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${item.quantity} x ${item.unitPriceMad.toStringAsFixed(2)} $currency'),
        trailing: Text('${item.totalMad.toStringAsFixed(2)} $currency'),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant))),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style:
                  strong ? const TextStyle(fontWeight: FontWeight.w700) : null,
            ),
          ),
        ],
      ),
    );
  }
}
