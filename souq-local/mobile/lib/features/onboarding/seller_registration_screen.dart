import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_config.dart';
import '../../core/models/auth_models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/strings/app_strings.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/form_widgets.dart';
import '../../core/widgets/map_widgets.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../../core/data/demo_map_data.dart';

class SellerRegistrationScreen extends ConsumerStatefulWidget {
  const SellerRegistrationScreen({super.key});

  @override
  ConsumerState<SellerRegistrationScreen> createState() => _SellerRegistrationScreenState();
}

class _SellerRegistrationScreenState extends ConsumerState<SellerRegistrationScreen> {
  static const _totalSteps = 5;
  int _step = 1;
  bool _loading = false;

  // Step 1
  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Step 2
  String _category = 'Food';
  String _city = AppConfig.moroccanCities.first;
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  LatLng _location = DemoMapData.cityCenter(AppConfig.moroccanCities.first);

  // Step 3
  final _descriptionController = TextEditingController();
  XFile? _logoImage;
  XFile? _coverImage;
  final Map<String, bool> _openDays = {
    'Mon': true,
    'Tue': true,
    'Wed': true,
    'Thu': true,
    'Fri': true,
    'Sat': true,
    'Sun': false,
  };
  TimeOfDay _openTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 21, minute: 0);

  // Step 4
  final List<_ProductDraft> _products = [_ProductDraft()];

  static const _categories = [
    'Food',
    'Clothing',
    'Electronics',
    'Beauty',
    'Services',
    'Home & Garden',
    'Health',
    'Sports',
  ];

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    for (final p in _products) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(void Function(XFile) setter) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (image != null) setState(() => setter(image));
  }

  bool _validateStep() {
    switch (_step) {
      case 1:
        return _businessNameController.text.trim().isNotEmpty &&
            _ownerNameController.text.trim().isNotEmpty &&
            _emailController.text.trim().isNotEmpty &&
            _passwordController.text.length >= 6;
      case 2:
        return _addressController.text.trim().isNotEmpty && _phoneController.text.trim().isNotEmpty;
      case 3:
        return _descriptionController.text.trim().isNotEmpty;
      case 4:
        return _products.any((p) => p.nameController.text.trim().isNotEmpty);
      default:
        return true;
    }
  }

  void _next() {
    final l10n = context.l10n;
    if (!_validateStep()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.completeRequiredStep)));
      return;
    }
    if (_step < _totalSteps) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 1) {
      setState(() => _step--);
    } else {
      context.pop();
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider);
      final session = await auth.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        accountType: 'seller',
        displayName: _ownerNameController.text.trim(),
      );

      final prefs = await ref.read(sharedPreferencesProvider.future);
      await auth.persistToken(prefs);

      final slug = sellerCategorySlugMap[_category] ?? 'food';
      final categoryId = await apiServiceProvider.categoryIdForSlug(slug);

      final sellerId = await apiServiceProvider.createSeller(
        SellerCreatePayload(
          businessName: _businessNameController.text.trim(),
          description: _descriptionController.text.trim(),
          address: _addressController.text.trim(),
          city: _city,
          latitude: _location.latitude,
          longitude: _location.longitude,
          phone: _phoneController.text.trim(),
          categoryIds: categoryId != null ? [categoryId] : [],
        ),
      );

      for (final product in _products) {
        final name = product.nameController.text.trim();
        if (name.isEmpty) continue;
        final price = double.tryParse(product.priceController.text.trim());
        await apiServiceProvider.addProduct(
          sellerId,
          ProductCreatePayload(
            name: name,
            description: product.descriptionController.text.trim(),
            priceMad: price,
          ),
        );
      }

      final storage = ref.read(appStorageProvider);
      if (storage == null) return;

      final userSession = UserSession(
        name: _ownerNameController.text.trim(),
        email: session.user.email,
        accountType: AccountType.seller,
        city: _city,
        businessName: _businessNameController.text.trim(),
      );

      await storage.completeOnboarding();
      await storage.saveSession(userSession);
      ref.read(userSessionProvider.notifier).state = userSession;
      ref.read(authSessionProvider.notifier).state = session;

      if (!mounted) return;
      context.go('/seller/dashboard');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.completeRequiredStep)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return OnboardingScaffold(
      showBack: true,
      onBack: _back,
      progressStep: _step,
      progressTotal: _totalSteps,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildStep(l10n),
      ),
      bottom: Column(
        children: [
          PrimaryButton(
            label: _step == _totalSteps ? l10n.submitCreateAccount : l10n.next,
            onPressed: _next,
            isLoading: _loading,
          ),
          if (_step < _totalSteps) SecondaryTextButton(label: l10n.back, onPressed: _back),
        ],
      ),
    );
  }

  Widget _buildStep(AppStrings l10n) {
    return switch (_step) {
      1 => _buildStep1(l10n),
      2 => _buildStep2(l10n),
      3 => _buildStep3(l10n),
      4 => _buildStep4(l10n),
      _ => _buildStep5(l10n),
    };
  }

  Widget _buildStep1(AppStrings l10n) {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppScreenHeader(title: l10n.sellerStep1Title, subtitle: l10n.sellerStep1Subtitle),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(label: l10n.businessName, controller: _businessNameController, hint: l10n.businessNameHint),
        const SizedBox(height: AppSpacing.md),
        AppTextField(label: l10n.ownerName, controller: _ownerNameController, hint: l10n.ownerNameHint),
        const SizedBox(height: AppSpacing.md),
        AppTextField(label: l10n.email, controller: _emailController, hint: l10n.emailHint, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: AppSpacing.md),
        AppTextField(label: l10n.password, controller: _passwordController, hint: l10n.passwordHint, obscureText: true),
      ],
    );
  }

  Widget _buildStep2(AppStrings l10n) {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppScreenHeader(title: l10n.sellerStep2Title, subtitle: l10n.sellerStep2Subtitle),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          label: l10n.businessCategory,
          hint: l10n.categoryLabel(_category),
          readOnly: true,
          prefixIcon: Icons.category_outlined,
          onTap: () async {
            final selected = await showModalBottomSheet<String>(
              context: context,
              builder: (ctx) => ListView(
                children: _categories
                    .map((c) => ListTile(title: Text(l10n.categoryLabel(c)), onTap: () => Navigator.pop(ctx, c)))
                    .toList(),
              ),
            );
            if (selected != null) setState(() => _category = selected);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: l10n.city,
          hint: _city,
          readOnly: true,
          prefixIcon: Icons.location_city_outlined,
          onTap: () async {
            final selected = await showModalBottomSheet<String>(
              context: context,
              builder: (ctx) => ListView(
                children: AppConfig.moroccanCities.map((c) => ListTile(title: Text(c), onTap: () => Navigator.pop(ctx, c))).toList(),
              ),
            );
            if (selected != null) {
              setState(() {
                _city = selected;
                _location = DemoMapData.cityCenter(selected);
              });
            }
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(label: l10n.fullAddress, controller: _addressController, hint: l10n.addressHint),
        const SizedBox(height: AppSpacing.md),
        AppTextField(label: l10n.phoneNumber, controller: _phoneController, hint: l10n.phoneHint, keyboardType: TextInputType.phone),
        const SizedBox(height: AppSpacing.md),
        StoreLocationPickerTile(
          label: l10n.storeLocation,
          hint: l10n.tapMapToSetPin,
          location: _location,
          onLocationChanged: (pos) => setState(() => _location = pos),
        ),
      ],
    );
  }

  Widget _buildStep3(AppStrings l10n) {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppScreenHeader(title: l10n.sellerStep3Title, subtitle: l10n.sellerStep3Subtitle),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(label: l10n.businessDescription, controller: _descriptionController, hint: l10n.descriptionHint, maxLines: 4),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: _ImagePickerBox(label: l10n.businessLogo, file: _logoImage, onTap: () => _pickImage((f) => _logoImage = f), height: 100)),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _ImagePickerBox(label: l10n.coverPhoto, file: _coverImage, onTap: () => _pickImage((f) => _coverImage = f), height: 100)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.openingHours, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _openDays.entries.map((entry) {
            return FilterChip(
              label: Text(l10n.dayLabel(entry.key)),
              selected: entry.value,
              onSelected: (v) => setState(() => _openDays[entry.key] = v),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: _TimePickerTile(label: l10n.opens, time: _openTime, onPick: (t) => setState(() => _openTime = t))),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _TimePickerTile(label: l10n.closes, time: _closeTime, onPick: (t) => setState(() => _closeTime = t))),
          ],
        ),
      ],
    );
  }

  Widget _buildStep4(AppStrings l10n) {
    return Column(
      key: const ValueKey(4),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppScreenHeader(title: l10n.sellerStep4Title, subtitle: l10n.sellerStep4Subtitle),
        const SizedBox(height: AppSpacing.xl),
        ..._products.asMap().entries.map((entry) {
          final index = entry.key;
          final product = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _ImagePickerBox(label: l10n.productImage, file: product.image, onTap: () => _pickImage((f) => setState(() => product.image = f)), height: 120),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(label: l10n.name, controller: product.nameController, hint: l10n.productNameHint),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(label: l10n.description, controller: product.descriptionController, hint: l10n.productDescriptionHint, maxLines: 2),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(label: l10n.priceOptional, controller: product.priceController, hint: l10n.priceHint, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  if (_products.length > 1)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() {
                          product.dispose();
                          _products.removeAt(index);
                        }),
                        child: Text(l10n.remove, style: const TextStyle(color: AppColors.danger)),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () => setState(() => _products.add(_ProductDraft())),
          icon: const Icon(Icons.add),
          label: Text(l10n.addAnotherItem),
        ),
      ],
    );
  }

  Widget _buildStep5(AppStrings l10n) {
    final productCount = _products.where((p) => p.nameController.text.isNotEmpty).length;
    return Column(
      key: const ValueKey(5),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppScreenHeader(title: l10n.sellerStep5Title, subtitle: l10n.sellerStep5Subtitle),
        const SizedBox(height: AppSpacing.xl),
        _ReviewRow(l10n.reviewBusiness, _businessNameController.text),
        _ReviewRow(l10n.reviewOwner, _ownerNameController.text),
        _ReviewRow(l10n.email, _emailController.text),
        _ReviewRow(l10n.reviewCategory, l10n.categoryLabel(_category)),
        _ReviewRow(l10n.reviewCity, _city),
        _ReviewRow(l10n.reviewAddress, _addressController.text),
        _ReviewRow(l10n.reviewPhone, _phoneController.text),
        _ReviewRow(l10n.reviewProducts, l10n.itemsCount(productCount)),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(l10n.sellerVisibilityNote(_city), style: Theme.of(context).textTheme.bodySmall)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _ImagePickerBox extends StatelessWidget {
  const _ImagePickerBox({required this.label, required this.onTap, this.file, this.height = 120});

  final String label;
  final VoidCallback onTap;
  final XFile? file;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          child: Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              color: Theme.of(context).inputDecorationTheme.fillColor,
            ),
            child: file != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                    child: Image.file(File(file!.path), fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined, color: AppColors.textSecondary),
                      const SizedBox(height: 4),
                      Text(context.l10n.upload, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  const _TimePickerTile({required this.label, required this.time, required this.onPick});

  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onPick(picked);
      },
      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.access_time, size: 18),
        ),
        child: Text(time.format(context)),
      ),
    );
  }
}

class _ProductDraft {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();
  XFile? image;

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
  }
}
