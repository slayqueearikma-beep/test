import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/data/city_coordinates.dart';
import '../../core/models/auth_models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/error_dialog.dart';
import '../../l10n/app_localizations.dart';

/// Logged-in users open a storefront on the same email/password account.
class BecomeSellerScreen extends ConsumerStatefulWidget {
  const BecomeSellerScreen({super.key});

  @override
  ConsumerState<BecomeSellerScreen> createState() => _BecomeSellerScreenState();
}

class _BecomeSellerScreenState extends ConsumerState<BecomeSellerScreen> {
  final _businessName = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _businessName.dispose();
    _description.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final session = ref.read(userSessionProvider);
    if (session == null || session.isGuest) {
      context.push('/login');
      return;
    }
    if (_businessName.text.trim().length < 2 ||
        _address.text.trim().length < 5 ||
        _phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.completeRequiredStep)),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final coords = CityCoordinates.casablanca;
      final seller = await apiServiceProvider.createSeller(
        SellerCreatePayload(
          businessName: _businessName.text.trim(),
          description: _description.text.trim(),
          address: _address.text.trim(),
          city: AppConfig.launchCity,
          latitude: coords.latitude,
          longitude: coords.longitude,
          phone: _phone.text.trim(),
        ),
      );
      final storage = ref.read(appStorageProvider);
      final updated = session.copyWith(
        accountType: AccountType.seller,
        sellerId: seller.id,
        businessName: seller.businessName,
        city: seller.city,
      );
      await storage?.saveSession(updated);
      await storage?.saveAppMode(AppMode.seller);
      ref.read(userSessionProvider.notifier).state = updated;
      if (!mounted) return;
      context.go('/seller/dashboard');
    } on ApiException catch (error) {
      if (mounted) {
        await showAppErrorDialog(
          context,
          title: l10n.somethingWentWrong,
          message: error.message,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.becomeSeller)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            Text(
              l10n.becomeSellerSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _businessName,
              decoration: InputDecoration(labelText: l10n.businessName),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.description),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _address,
              decoration: InputDecoration(labelText: l10n.fullAddress),
            ),
            const SizedBox(height: AppSpacing.md),
            InputDecorator(
              decoration: InputDecoration(labelText: l10n.city),
              child: const Text(AppConfig.launchCity),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: l10n.phoneNumber),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: l10n.openStorefront,
              isLoading: _loading,
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
