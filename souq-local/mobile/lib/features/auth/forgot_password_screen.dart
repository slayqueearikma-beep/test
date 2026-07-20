import 'package:flutter/material.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_brand_logo.dart';
import '../../core/widgets/error_dialog.dart';
import '../../l10n/app_localizations.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.resetMode = false,
    this.initialToken = '',
  });

  final bool resetMode;
  final String initialToken;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  late final TextEditingController _tokenController;
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _requestSent = false;
  bool _resetComplete = false;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.initialToken);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    final l10n = context.l10n;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.emailRequired)));
      return;
    }
    setState(() => _loading = true);
    try {
      await apiServiceProvider.requestPasswordReset(email);
      if (mounted) setState(() => _requestSent = true);
    } on ApiException catch (error) {
      if (mounted) {
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: error.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmReset() async {
    final l10n = context.l10n;
    if (_tokenController.text.trim().isEmpty ||
        _passwordController.text.length < 8) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.resetPasswordValidation)));
      return;
    }
    setState(() => _loading = true);
    try {
      await apiServiceProvider.confirmPasswordReset(
        token: _tokenController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (mounted) setState(() => _resetComplete = true);
    } on ApiException catch (error) {
      if (mounted) {
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: error.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final resetMode = widget.resetMode;

    return Scaffold(
      appBar: AppBar(
          title: Text(resetMode ? l10n.resetPassword : l10n.forgotPassword)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            const Center(
                child: AppBrandLogo(
                    variant: AppBrandLogoVariant.icon, iconSize: 56)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              resetMode ? l10n.resetPassword : l10n.forgotPassword,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              resetMode
                  ? l10n.resetPasswordSubtitle
                  : l10n.forgotPasswordSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (!resetMode) ...[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                    labelText: l10n.email,
                    prefixIcon: const Icon(Icons.email_outlined)),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _loading ? null : _requestReset,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.sendResetLink),
              ),
              if (_requestSent) ...[
                const SizedBox(height: AppSpacing.md),
                _SuccessMessage(message: l10n.resetLinkSent),
              ],
            ] else ...[
              TextField(
                controller: _tokenController,
                decoration: InputDecoration(
                    labelText: l10n.resetToken,
                    prefixIcon: const Icon(Icons.key_outlined)),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: l10n.newPassword,
                    prefixIcon: const Icon(Icons.lock_outline)),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _loading ? null : _confirmReset,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.resetPassword),
              ),
              if (_resetComplete) ...[
                const SizedBox(height: AppSpacing.md),
                _SuccessMessage(message: l10n.passwordResetComplete),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SuccessMessage extends StatelessWidget {
  const _SuccessMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
