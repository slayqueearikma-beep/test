import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../l10n/app_localizations.dart';

final buyerOrdersProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) {
  return apiServiceProvider.fetchBuyerOrders();
});

class BuyerOrdersScreen extends ConsumerWidget {
  const BuyerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ordersAsync = ref.watch(buyerOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.orders)),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView.fromError(error,
            onRetry: () => ref.invalidate(buyerOrdersProvider)),
        data: (orders) {
          if (orders.isEmpty) {
            return EmptyOrdersView(
              title: l10n.noOrdersYet,
              subtitle: l10n.noOrdersYetSubtitle,
              actionLabel: l10n.browseProducts,
              onAction: () => context.go('/buyer/home'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(buyerOrdersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              itemCount: orders.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => OrderListTile(
                order: orders[index],
                onTap: () => context.push('/orders/${orders[index].id}'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class OrderListTile extends StatelessWidget {
  const OrderListTile({
    super.key,
    required this.order,
    required this.onTap,
    this.trailing,
  });

  final OrderModel order;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        title: Row(
          children: [
            Expanded(
              child: Text(
                order.sellerName.isEmpty
                    ? l10n.orderNumber(shortOrderId(order.id))
                    : order.sellerName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            OrderStatusChip(status: order.status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.itemsCount(order.items.length)),
              const SizedBox(height: 2),
              Text('${order.totalMad.toStringAsFixed(2)} ${order.currency}'),
              if (order.createdAt.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(formatDate(order.createdAt),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'pending' => AppColors.warning,
      'accepted' => AppColors.primary,
      'ready' => AppColors.illustrationBlue,
      'completed' => AppColors.success,
      'cancelled' || 'rejected' => AppColors.danger,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusLabel(context, status),
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class EmptyOrdersView extends StatelessWidget {
  const EmptyOrdersView({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

String shortOrderId(String id) => id.length <= 8 ? id : id.substring(0, 8);

String formatDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value.length > 10 ? value.substring(0, 10) : value;
  final local = parsed.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

String statusLabel(BuildContext context, String status) {
  final l10n = context.l10n;
  return switch (status) {
    'pending' => l10n.orderStatusPending,
    'accepted' => l10n.orderStatusAccepted,
    'ready' => l10n.orderStatusReady,
    'completed' => l10n.orderStatusCompleted,
    'cancelled' => l10n.orderStatusCancelled,
    'rejected' => l10n.orderStatusRejected,
    _ => status,
  };
}
