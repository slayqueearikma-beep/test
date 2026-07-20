import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/error_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../cart/cart_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  late final TextEditingController _cityController;
  final _noteController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(userSessionProvider);
    _nameController = TextEditingController(text: session?.name ?? '');
    _cityController = TextEditingController(text: session?.city ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final orders = await apiServiceProvider.checkout(
        CheckoutPayload(
          deliveryName: _nameController.text.trim(),
          deliveryPhone: _phoneController.text.trim(),
          deliveryAddress: _addressController.text.trim(),
          deliveryCity: _cityController.text.trim(),
          buyerNote: _noteController.text.trim(),
        ),
      );
      ref.invalidate(cartProvider);
      if (!mounted) return;
      if (orders.length == 1) {
        context.go('/orders/${orders.first.id}');
      } else {
        context.go('/orders');
      }
    } on ApiException catch (error) {
      if (mounted) {
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: error.message);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkout)),
      body: cartAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView.fromError(error,
            onRetry: () => ref.invalidate(cartProvider)),
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text(l10n.emptyCart));
          }
          final summary = CartSummary(items);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              children: [
                Text(l10n.orderSummary,
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
                        ...items.map(
                          (item) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text(
                                        '${item.quantity} x ${item.name}')),
                                Text(
                                    '${item.lineTotalMad.toStringAsFixed(2)} MAD'),
                              ],
                            ),
                          ),
                        ),
                        const Divider(),
                        Row(
                          children: [
                            Text(l10n.subtotal,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Text(
                                '${summary.subtotalMad.toStringAsFixed(2)} MAD',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.deliveryDetails,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                      labelText: l10n.recipientName,
                      prefixIcon: const Icon(Icons.person_outline)),
                  validator: (value) => (value ?? '').trim().length < 2
                      ? l10n.requiredField
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                      labelText: l10n.phoneNumber,
                      prefixIcon: const Icon(Icons.phone_outlined)),
                  validator: (value) => (value ?? '').trim().length < 6
                      ? l10n.requiredField
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                      labelText: l10n.deliveryAddress,
                      prefixIcon: const Icon(Icons.location_on_outlined)),
                  validator: (value) => (value ?? '').trim().length < 5
                      ? l10n.requiredField
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                      labelText: l10n.city,
                      prefixIcon: const Icon(Icons.location_city_outlined)),
                  validator: (value) => (value ?? '').trim().length < 2
                      ? l10n.requiredField
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                      labelText: l10n.orderNoteOptional,
                      prefixIcon: const Icon(Icons.notes_outlined)),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline),
                  label:
                      Text(_submitting ? l10n.placingOrder : l10n.placeOrder),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
