import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_brand_logo.dart';
import '../../core/widgets/error_dialog.dart';
import '../../l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final l10n = context.l10n;
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.enterEmailPassword)));
      return;
    }

    setState(() => _loading = true);
    try {
      await apiServiceProvider.runSubmit(() async {
        await apiServiceProvider.checkHealth();

        final auth = ref.read(authServiceProvider);
        final session = await auth.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        final prefs = await ref.read(sharedPreferencesProvider.future);
        await auth.persistToken(prefs);

        final storage = ref.read(appStorageProvider);
        if (storage == null) {
          throw ApiException(
              'App storage is not ready. Please restart the app.');
        }

        final existing = storage.getSession();
        var userSession = UserSession(
          name: session.user.displayName.isNotEmpty
              ? session.user.displayName
              : l10n.returningUser,
          email: session.user.email,
          accountType:
              session.user.isSeller ? AccountType.seller : AccountType.buyer,
          city: existing?.city ?? AppConfig.moroccanCities.first,
          businessName: existing?.businessName,
          sellerId: existing?.sellerId,
        );

        if (session.user.isSeller) {
          try {
            final seller = await apiServiceProvider.fetchMySeller();
            userSession = userSession.copyWith(
              sellerId: seller.id,
              businessName: seller.businessName,
              city: seller.city,
            );
          } on ApiException {
            // Seller may still need to complete onboarding profile creation.
          }
        }

        if (session.user.isBuyer) {
          final guestItems = guestFavoritesMigrationPayload(storage);
          if (guestItems.isNotEmpty) {
            await apiServiceProvider.migrateGuestFavorites(guestItems);
            await storage.clearGuestFavorites();
          }
        }

        await storage.saveSession(userSession);
        ref.read(userSessionProvider.notifier).state = userSession;
        ref.read(authSessionProvider.notifier).state = session;

        if (!mounted) return;
        context.go(session.user.isSeller ? '/seller/dashboard' : '/buyer/home');
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorDialog(context,
          title: l10n.somethingWentWrong, message: e.message);
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

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              const Center(
                  child: AppBrandLogo(
                      variant: AppBrandLogoVariant.full, width: 240)),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.welcomeBack,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.loginSubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                    labelText: l10n.email,
                    prefixIcon: const Icon(Icons.email_outlined)),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: l10n.password,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (!AppConfig.isProduction) ...[
                Text(
                  'API: ${AppConfig.apiBaseUrl}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              PrimaryButton(
                  label: l10n.logIn, onPressed: _login, isLoading: _loading),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                  onPressed: _continueAsGuest, child: Text(l10n.guestContinue)),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: Text(l10n.forgotPassword),
                ),
              ),
              LinkTextButton(
                  label: l10n.createAccount,
                  onPressed: () => context.go('/onboarding/account-type')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _continueAsGuest() async {
    final storage = ref.read(appStorageProvider);
    if (storage == null) return;
    await storage.completeOnboarding();
    await storage.saveGuestSession(city: AppConfig.moroccanCities.first);
    ref.read(userSessionProvider.notifier).state = storage.getSession();
    if (mounted) context.go('/buyer/home');
  }
}
