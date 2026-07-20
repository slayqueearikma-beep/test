import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_config.dart';
import '../../core/models/auth_models.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/upload_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/network_image_view.dart';
import '../../l10n/app_localizations.dart';
import 'seller_account_provider.dart';

class SellerProductsScreen extends ConsumerWidget {
  const SellerProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final accountAsync = ref.watch(sellerAccountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.productManagement),
        actions: [
          IconButton(
            tooltip: l10n.addProduct,
            onPressed: () => context.push('/seller/products/new'),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/seller/products/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.addProduct),
      ),
      body: accountAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(sellerAccountProvider),
        ),
        data: (account) {
          final products = account.profile.products;
          if (products.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.noProductsYet, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: () => context.push('/seller/products/new'),
                      child: Text(l10n.addProduct),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(sellerAccountProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.md,
                AppSpacing.screenHorizontal,
                100,
              ),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(AppSpacing.sm),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: NetworkImageView(
                          url: product.imageUrl,
                          placeholderIcon: Icons.shopping_bag_outlined,
                        ),
                      ),
                    ),
                    title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product.priceMad != null)
                          Text('${product.priceMad!.toStringAsFixed(0)} MAD'),
                        Text(
                          product.isAvailable ? l10n.available : l10n.unavailable,
                          style: TextStyle(
                            color: product.isAvailable ? AppColors.success : AppColors.warning,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/seller/products/${product.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class SellerProductEditorScreen extends ConsumerStatefulWidget {
  const SellerProductEditorScreen({super.key, this.productId});

  final String? productId;

  bool get isEditing => productId != null;

  @override
  ConsumerState<SellerProductEditorScreen> createState() => _SellerProductEditorScreenState();
}

class _SellerProductEditorScreenState extends ConsumerState<SellerProductEditorScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  bool _available = true;
  bool _loading = false;
  bool _initialized = false;
  String _imageUrl = '';
  XFile? _pickedImage;
  ProductModel? _existing;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _hydrate(ProductModel product) {
    if (_initialized) return;
    _existing = product;
    _nameController.text = product.name;
    _descriptionController.text = product.description;
    if (product.priceMad != null) {
      _priceController.text = product.priceMad!.toStringAsFixed(
        product.priceMad! % 1 == 0 ? 0 : 2,
      );
    }
    _available = product.isAvailable;
    _imageUrl = product.imageUrl;
    _initialized = true;
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (image != null) setState(() => _pickedImage = image);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.completeRequiredStep)));
      return;
    }

    setState(() => _loading = true);
    try {
      await apiServiceProvider.runSubmit(() async {
        final account = await ref.read(sellerAccountProvider.future);
        final sellerId = account.profile.id;

        var imageUrl = _imageUrl;
        if (_pickedImage != null) {
          try {
            imageUrl = await ref.read(uploadServiceProvider).uploadImage(_pickedImage!);
          } on ApiException {
            if (AppConfig.isProduction) rethrow;
          }
        }

        final priceText = _priceController.text.trim();
        final price = priceText.isEmpty ? null : double.tryParse(priceText);
        if (priceText.isNotEmpty && price == null) {
          throw ApiException('Enter a valid price');
        }

        if (widget.isEditing) {
          await apiServiceProvider.updateProduct(
            sellerId,
            widget.productId!,
            ProductUpdatePayload(
              name: name,
              description: _descriptionController.text.trim(),
              priceMad: price,
              clearPrice: priceText.isEmpty,
              imageUrl: imageUrl,
              isAvailable: _available,
            ),
          );
        } else {
          await apiServiceProvider.addProduct(
            sellerId,
            ProductCreatePayload(
              name: name,
              description: _descriptionController.text.trim(),
              priceMad: price,
              imageUrl: imageUrl,
            ),
          );
        }
      });

      ref.invalidate(sellerAccountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.productSaved)));
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorDialog(context, title: l10n.somethingWentWrong, message: e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteProduct),
        content: Text(l10n.deleteProductConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteProduct),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final account = await ref.read(sellerAccountProvider.future);
      await apiServiceProvider.deleteProduct(account.profile.id, widget.productId!);
      ref.invalidate(sellerAccountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.productDeleted)));
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorDialog(context, title: l10n.somethingWentWrong, message: e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (widget.isEditing) {
      final accountAsync = ref.watch(sellerAccountProvider);
      return accountAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(
          appBar: AppBar(),
          body: AsyncErrorView.fromError(error, onRetry: () => ref.invalidate(sellerAccountProvider)),
        ),
        data: (account) {
          final product = account.profile.products.where((p) => p.id == widget.productId).firstOrNull;
          if (product == null) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(child: Text(l10n.somethingWentWrong)),
            );
          }
          _hydrate(product);
          return _buildForm(l10n);
        },
      );
    }

    return _buildForm(l10n);
  }

  Widget _buildForm(AppStrings l10n) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? l10n.editProduct : l10n.addProduct),
        actions: [
          if (widget.isEditing)
            IconButton(
              onPressed: _loading ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteProduct,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          GestureDetector(
            onTap: _loading ? null : _pickImage,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: _pickedImage != null
                    ? Image.file(File(_pickedImage!.path), fit: BoxFit.cover)
                    : _imageUrl.isNotEmpty
                        ? NetworkImageView(url: _imageUrl, placeholderIcon: Icons.image_outlined)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_a_photo_outlined, size: 36),
                              const SizedBox(height: 8),
                              Text(l10n.tapToUpload),
                            ],
                          ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _nameController,
            enabled: !_loading,
            decoration: InputDecoration(labelText: l10n.name),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _descriptionController,
            enabled: !_loading,
            decoration: InputDecoration(labelText: l10n.description),
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _priceController,
            enabled: !_loading,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.priceOptional),
          ),
          if (widget.isEditing) ...[
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_available ? l10n.available : l10n.unavailable),
              value: _available,
              onChanged: _loading ? null : (value) => setState(() => _available = value),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(label: l10n.saveChanges, onPressed: _save, isLoading: _loading),
          if (_existing != null) const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
