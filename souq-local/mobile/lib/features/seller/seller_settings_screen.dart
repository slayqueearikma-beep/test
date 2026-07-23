import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/theme_mode_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/error_dialog.dart';
import '../../l10n/app_localizations.dart';
import 'seller_account_provider.dart';

class SellerSettingsScreen extends ConsumerStatefulWidget {
  const SellerSettingsScreen({super.key});

  @override
  ConsumerState<SellerSettingsScreen> createState() => _SellerSettingsScreenState();
}

class _SellerSettingsScreenState extends ConsumerState<SellerSettingsScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _loadingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final l10n = context.l10n;
    if (_currentPasswordController.text.isEmpty || _newPasswordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.completeRequiredStep)));
      return;
    }

    setState(() => _loadingPassword = true);
    try {
      await apiServiceProvider.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordChanged)));
      _currentPasswordController.clear();
      _newPasswordController.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorDialog(context, title: l10n.somethingWentWrong, message: e.message);
    } finally {
      if (mounted) setState(() => _loadingPassword = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAccount),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deleteAccountConfirm),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.password),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteAccount),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      controller.dispose();
      return;
    }

    try {
      await ref.read(authServiceProvider).deleteAccount(password: controller.text);
      controller.dispose();
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await ref.read(authServiceProvider).logout(prefs);
      await ref.read(appStorageProvider)?.logout();
      ref.invalidate(sellerAccountProvider);
      ref.read(userSessionProvider.notifier).state = null;
      ref.read(authSessionProvider.notifier).state = null;
      if (!mounted) return;
      context.go('/login');
    } on ApiException catch (e) {
      controller.dispose();
      if (!mounted) return;
      await showAppErrorDialog(context, title: l10n.somethingWentWrong, message: e.message);
    } catch (_) {
      controller.dispose();
      if (!mounted) return;
      await showAppErrorDialog(context, title: l10n.somethingWentWrong, message: l10n.serverUnreachable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountSecurity)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          Text(l10n.appearance, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(value: ThemeMode.system, label: Text(l10n.systemTheme), icon: const Icon(Icons.brightness_auto)),
              ButtonSegment(value: ThemeMode.light, label: Text(l10n.lightTheme), icon: const Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeMode.dark, label: Text(l10n.darkTheme), icon: const Icon(Icons.dark_mode_outlined)),
            ],
            selected: {themeMode},
            onSelectionChanged: (values) {
              ref.read(themeModeProvider.notifier).setThemeMode(values.first);
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.verifyEmailTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.mark_email_unread_outlined),
            title: Text(l10n.resendVerificationEmail),
            onTap: () => context.push('/verify-email'),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.changePassword, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _currentPasswordController,
            obscureText: _obscureCurrent,
            decoration: InputDecoration(
              labelText: l10n.currentPassword,
              suffixIcon: IconButton(
                icon: Icon(_obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _newPasswordController,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              labelText: l10n.newPassword,
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: l10n.changePassword,
            onPressed: _changePassword,
            isLoading: _loadingPassword,
          ),
          const SizedBox(height: AppSpacing.xxl),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: _confirmDeleteAccount,
            child: Text(l10n.deleteAccount),
          ),
        ],
      ),
    );
  }
}
