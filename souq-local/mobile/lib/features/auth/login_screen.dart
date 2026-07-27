import 'package:flutter/foundation.dart';
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
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('MarGem API_BASE_URL=${AppConfig.apiBaseUrl}');
    }
  }

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
              session.user.canSell ? AccountType.seller : AccountType.buyer,
          city: AppConfig.launchCity,
          businessName: existing?.businessName,
          sellerId: existing?.sellerId,
        );

        if (session.user.canSell || session.user.hasSellerProfile) {
          try {
            final seller = await apiServiceProvider.fetchMySeller();
            userSession = userSession.copyWith(
              accountType: AccountType.seller,
              sellerId: seller.id,
              businessName: seller.businessName,
              city: seller.city,
            );
          } on ApiException {
            // Seller may still need to complete onboarding profile creation.
          }
        }

        final guestItems = guestFavoritesMigrationPayload(storage);
        if (guestItems.isNotEmpty) {
          await apiServiceProvider.migrateGuestFavorites(guestItems);
          await storage.clearGuestFavorites();
        }

        await storage.saveSession(userSession);
        if (userSession.hasSellerProfile &&
            storage.getAppMode(session: userSession) == AppMode.buyer &&
            session.user.accountType == 'seller') {
          await storage.saveAppMode(AppMode.seller);
        }
        ref.read(userSessionProvider.notifier).state = userSession;
        ref.read(authSessionProvider.notifier).state = session;

        if (!mounted) return;
        context.go(storage.homeRouteFor(userSession));
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

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surfaceMuted.withValues(alpha: 0.65),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.md,
            AppSpacing.screenHorizontal,
            AppSpacing.lg + bottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppSpacing.illustrationRadius),
                child: AspectRatio(
                  aspectRatio: 1.15,
                  child: Image.asset(
                    'assets/images/onboarding/onboarding_01_ideas.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.cardSelected,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.waving_hand_rounded,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                l10n.welcomeBack,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.loginSubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email
                ],
                decoration: _fieldDecoration(
                  label: l10n.email,
                  icon: Icons.email_outlined,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _login(),
                decoration: _fieldDecoration(
                  label: l10n.password,
                  icon: Icons.lock_outline,
                  suffix: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: Text(l10n.forgotPassword),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: l10n.logIn,
                onPressed: _login,
                isLoading: _loading,
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => context.push('/onboarding/account-type'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side:
                        const BorderSide(color: AppColors.primary, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  child: Text(l10n.createAccount),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _continueAsGuest,
                child: Text(
                  l10n.guestContinue,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
    await storage.saveGuestSession(city: AppConfig.launchCity);
    ref.read(userSessionProvider.notifier).state = storage.getSession();
    if (mounted) context.go('/buyer/home');
  }
}
