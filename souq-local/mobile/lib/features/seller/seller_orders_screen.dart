import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/error_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../orders/buyer_orders_screen.dart';

final sellerOrdersProvider =
    FutureProvider.autoDispose<List<OrderModel>>((ref) {
  return apiServiceProvider.fetchSellerOrders();
});

class SellerOrdersScreen extends ConsumerWidget {
  const SellerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ordersAsync = ref.watch(sellerOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.orders)),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView.fromError(error,
            onRetry: () => ref.invalidate(sellerOrdersProvider)),
        data: (orders) {
          if (orders.isEmpty) {
            return EmptyOrdersView(
              title: l10n.noSellerOrders,
              subtitle: l10n.noSellerOrdersSubtitle,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(sellerOrdersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              itemCount: orders.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  _SellerOrderCard(order: orders[index]),
            ),
          );
        },
      ),
    );
  }
}

class _SellerOrderCard extends ConsumerStatefulWidget {
  const _SellerOrderCard({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_SellerOrderCard> createState() => _SellerOrderCardState();
}

class _SellerOrderCardState extends ConsumerState<_SellerOrderCard> {
  String? _action;

  Future<void> _runAction(String action) async {
    final l10n = context.l10n;
    var note = '';
    if (action == 'accept' || action == 'reject') {
      final controller = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(action == 'accept' ? l10n.acceptOrder : l10n.rejectOrder),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(labelText: l10n.sellerNoteOptional),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: Text(l10n.confirm)),
          ],
        ),
      );
      if (result == null) return;
      note = result;
    }

    setState(() => _action = action);
    try {
      await apiServiceProvider.sellerOrderAction(widget.order.id, action,
          note: note);
      ref.invalidate(sellerOrdersProvider);
    } on ApiException catch (error) {
      if (mounted) {
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: error.message);
      }
    } finally {
      if (mounted) setState(() => _action = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final order = widget.order;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => context.push('/orders/${order.id}'),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.orderNumber(shortOrderId(order.id)),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  OrderStatusChip(status: order.status),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('${order.deliveryName} · ${order.deliveryCity}'),
            const SizedBox(height: 2),
            Text(
                '${order.items.length} ${l10n.items.toLowerCase()} · ${order.totalMad.toStringAsFixed(2)} ${order.currency}'),
            if (order.buyerNote.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(order.buyerNote,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (order.canSellerAccept) ...[
                  _ActionButton(
                    label: l10n.acceptOrder,
                    icon: Icons.check_circle_outline,
                    loading: _action == 'accept',
                    onPressed: () => _runAction('accept'),
                  ),
                  _ActionButton(
                    label: l10n.rejectOrder,
                    icon: Icons.cancel_outlined,
                    danger: true,
                    loading: _action == 'reject',
                    onPressed: () => _runAction('reject'),
                  ),
                ],
                if (order.canSellerMarkReady)
                  _ActionButton(
                    label: l10n.markReady,
                    icon: Icons.inventory_2_outlined,
                    loading: _action == 'ready',
                    onPressed: () => _runAction('ready'),
                  ),
                if (order.canSellerComplete)
                  _ActionButton(
                    label: l10n.completeOrder,
                    icon: Icons.done_all,
                    loading: _action == 'complete',
                    onPressed: () => _runAction('complete'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.primary;
    return OutlinedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon, color: color, size: 18),
      label: Text(label, style: TextStyle(color: color)),
    );
  }
}
