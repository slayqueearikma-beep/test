import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_brand_logo.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/error_dialog.dart';
import '../../l10n/app_localizations.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.initialToken = ''});

  final String initialToken;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  late final TextEditingController _tokenController;
  bool _loading = false;
  bool _verified = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.initialToken);
    if (widget.initialToken.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _confirm());
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final l10n = context.l10n;
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      await showAppErrorDialog(
        context,
        title: l10n.somethingWentWrong,
        message: l10n.verificationCodeRequired,
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await apiServiceProvider.confirmEmailVerification(token);
      if (!mounted) return;
      setState(() => _verified = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.emailVerifiedSuccess)),
      );
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

  Future<void> _resend() async {
    final l10n = context.l10n;
    final session = ref.read(userSessionProvider);
    if (session == null || session.isGuest) {
      context.push('/login');
      return;
    }
    setState(() => _resending = true);
    try {
      await apiServiceProvider.requestEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.verificationEmailSent)),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        await showAppErrorDialog(
          context,
          title: l10n.somethingWentWrong,
          message: error.message,
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final canResend = session != null && !session.isGuest;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.verifyEmailTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              const Center(
                child: AppBrandLogo(
                  variant: AppBrandLogoVariant.icon,
                  iconSize: 56,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.verifyEmailTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.verifyEmailSubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_verified)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        const Icon(Icons.mark_email_read_outlined, size: 40),
                        const SizedBox(height: AppSpacing.sm),
                        Text(l10n.emailVerifiedSuccess,
                            textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.md),
                        PrimaryButton(
                          label: l10n.continueLabel,
                          onPressed: () => context.go('/buyer/home'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                TextField(
                  controller: _tokenController,
                  decoration: InputDecoration(
                    labelText: l10n.verificationCode,
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: l10n.verifyEmailAction,
                  onPressed: _confirm,
                  isLoading: _loading,
                ),
                if (canResend) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: _resending ? null : _resend,
                    child: _resending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.resendVerificationEmail),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
