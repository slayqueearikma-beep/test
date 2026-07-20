import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_config.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/form_widgets.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../../l10n/app_localizations.dart';
import '../cart/cart_provider.dart';

class BuyerRegistrationScreen extends ConsumerStatefulWidget {
  const BuyerRegistrationScreen({super.key});

  @override
  ConsumerState<BuyerRegistrationScreen> createState() =>
      _BuyerRegistrationScreenState();
}

class _BuyerRegistrationScreenState
    extends ConsumerState<BuyerRegistrationScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _city = AppConfig.moroccanCities.first;
  XFile? _profileImage;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (image != null) setState(() => _profileImage = image);
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.length < 8) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.fillRequiredFields)));
      return;
    }

    setState(() => _loading = true);
    try {
      await apiServiceProvider.runSubmit(() async {
        await apiServiceProvider.checkHealth();

        final auth = ref.read(authServiceProvider);
        final session = await auth.register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          accountType: 'buyer',
          displayName: _nameController.text.trim(),
        );

        final prefs = await ref.read(sharedPreferencesProvider.future);
        await auth.persistToken(prefs);

        final storage = ref.read(appStorageProvider);
        if (storage == null) {
          throw ApiException(
              'App storage is not ready. Please restart the app.');
        }

        final userSession = UserSession(
          name: session.user.displayName,
          email: session.user.email,
          accountType: AccountType.buyer,
          city: _city,
        );

        final guestItems = guestCartMigrationPayload(storage);
        if (guestItems.isNotEmpty) {
          await apiServiceProvider.migrateGuestCart(guestItems);
          await storage.clearGuestCart();
        }

        await storage.completeOnboarding();
        await storage.saveSession(userSession);
        ref.read(userSessionProvider.notifier).state = userSession;
        ref.read(authSessionProvider.notifier).state = session;
        ref.invalidate(cartProvider);

        if (!mounted) return;
        context.go('/buyer/home');
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorDialog(context,
          title: l10n.somethingWentWrong, message: e.message);
    } on TimeoutException {
      if (!mounted) return;
      await showAppErrorDialog(context,
          title: l10n.somethingWentWrong, message: l10n.serverUnreachable);
    } catch (e) {
      if (!mounted) return;
      await showAppErrorDialog(context,
          title: l10n.somethingWentWrong, message: l10n.serverUnreachable);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return OnboardingScaffold(
      showBack: true,
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!AppConfig.isProduction) ...[
            const Text(
              'API: ${AppConfig.apiBaseUrl}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          PrimaryButton(
              label: l10n.createAccount,
              onPressed: _submit,
              isLoading: _loading),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppScreenHeader(
              title: l10n.createBuyerAccount,
              subtitle: l10n.createBuyerSubtitle),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 48,
                backgroundColor:
                    Theme.of(context).inputDecorationTheme.fillColor,
                backgroundImage: _profileImage != null
                    ? FileImage(File(_profileImage!.path))
                    : null,
                child: _profileImage == null
                    ? const Icon(Icons.add_a_photo_outlined,
                        size: 28, color: Colors.grey)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
              child: Text(l10n.profilePictureOptional,
                  style: const TextStyle(color: Colors.grey, fontSize: 13))),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
              label: l10n.fullName,
              controller: _nameController,
              hint: l10n.yourName),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.email,
            controller: _emailController,
            hint: l10n.emailHint,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.password,
            controller: _passwordController,
            hint: l10n.passwordHint,
            obscureText: true,
            prefixIcon: Icons.lock_outline,
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
                  children: AppConfig.moroccanCities
                      .map((city) => ListTile(
                          title: Text(city),
                          onTap: () => Navigator.pop(ctx, city)))
                      .toList(),
                ),
              );
              if (selected != null) setState(() => _city = selected);
            },
          ),
        ],
      ),
    );
  }
}
