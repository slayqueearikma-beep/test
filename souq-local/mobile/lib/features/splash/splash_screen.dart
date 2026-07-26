import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_brand_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _scale = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.6, curve: Curves.easeOut)),
    );
    _controller.forward();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final storage = ref.read(appStorageProvider);
    if (storage == null) {
      await ref.read(sharedPreferencesProvider.future);
      if (!mounted) return;
      return _navigateNext();
    }

    await ref.read(authServiceProvider).loadStoredToken();
    var restored = await ref.read(authServiceProvider).restoreAuthSession();
    if (restored != null) {
      ref.read(authSessionProvider.notifier).state = restored;
    }

    if (!storage.isLanguageSelected) {
      if (!mounted) return;
      context.go('/language');
      return;
    }

    final session = storage.getSession();
    if (session != null) {
      if (session.isGuest) {
        ref.read(userSessionProvider.notifier).state = session;
        if (mounted) context.go('/buyer/home');
        return;
      }
      final valid = await ref.read(authServiceProvider).ensureSessionValid();
      if (!valid) {
        await storage.logout();
        ref.read(userSessionProvider.notifier).state = null;
        ref.read(authSessionProvider.notifier).state = null;
        if (mounted) context.go('/login');
        return;
      }
      // A refresh may have succeeded after the first restore attempt. Re-read
      // /auth/me so authSessionProvider and the persisted routing session stay
      // coherent after a cold start.
      restored ??= await ref.read(authServiceProvider).restoreAuthSession();
      if (restored == null) {
        await storage.logout();
        ref.read(userSessionProvider.notifier).state = null;
        ref.read(authSessionProvider.notifier).state = null;
        if (mounted) context.go('/login');
        return;
      }
      ref.read(authSessionProvider.notifier).state = restored;
      final hydrated = session.copyWith(
        name: restored.user.displayName,
        email: restored.user.email,
      );
      await storage.saveSession(hydrated);
      ref.read(userSessionProvider.notifier).state = hydrated;
      if (mounted) {
        context.go(storage.homeRouteFor(hydrated));
      }
      return;
    }

    if (storage.isOnboardingComplete) {
      if (!mounted) return;
      context.go('/login');
      return;
    }

    if (!mounted) return;
    context.go('/onboarding');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: const AppBrandLogo(
                variant: AppBrandLogoVariant.full, width: 280),
          ),
        ),
      ),
    );
  }
}
