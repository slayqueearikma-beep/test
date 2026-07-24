import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/buyer/buyer_home_screen.dart';
import '../../l10n/app_localizations.dart';

/// Root navigator key shared with [GoRouter] so dialogs, sheets, and
/// pushed pages all share one stack for Android system-back handling.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Shared double-back timer so [RootBackScope] and the app observer stay in sync.
final backExitPromptAtProvider = StateProvider<DateTime?>((ref) => null);

/// Prevents observer + PopScope from handling the same press twice.
var _backHandling = false;

/// Paths treated as app roots (double-back-to-exit when the stack is empty).
bool isAppRootLocation(String path) {
  return path == '/buyer/home' ||
      path == '/seller/dashboard' ||
      path == '/login' ||
      path == '/splash' ||
      path == '/language' ||
      path == '/onboarding';
}

/// Shared back logic used by [MarGemApp]'s binding observer and [RootBackScope].
///
/// Returns `true` when the event was handled (Android must not kill the app).
Future<bool> handleAppBack({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  if (_backHandling) return true;
  _backHandling = true;
  try {
    final navigator = rootNavigatorKey.currentState;

    // 1) Close dialogs, bottom sheets, menus, and any other overlay routes first.
    if (navigator != null && navigator.canPop()) {
      await navigator.maybePop();
      return true;
    }

    // 2) Pop GoRouter's page stack when a previous screen exists.
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
      return true;
    }

    final location = router?.state.uri.path ??
        router?.routerDelegate.currentConfiguration.uri.path ??
        '';

    // 3) Buyer bottom navigation: return to Home tab before exiting.
    if (location == '/buyer/home') {
      final tab = ref.read(buyerTabIndexProvider);
      if (tab != 0) {
        ref.read(buyerTabIndexProvider.notifier).state = 0;
        ref.read(backExitPromptAtProvider.notifier).state = null;
        return true;
      }
    }

    // 4) Orphan leaf route (empty stack after deep link) → Home, don't exit.
    if (location.isNotEmpty && !isAppRootLocation(location)) {
      ref.read(backExitPromptAtProvider.notifier).state = null;
      if (location.startsWith('/seller/products') ||
          location.startsWith('/seller/profile') ||
          location.startsWith('/seller/reviews') ||
          location.startsWith('/seller/settings') ||
          location.startsWith('/seller/notifications') ||
          location.startsWith('/seller/messages') ||
          location == '/seller/dashboard') {
        router?.go('/seller/dashboard');
      } else {
        router?.go('/buyer/home');
      }
      return true;
    }

    // 5) Double-back-to-exit only on true root screens.
    final lastPrompt = ref.read(backExitPromptAtProvider);
    final now = DateTime.now();
    final withinWindow = lastPrompt != null &&
        now.difference(lastPrompt) < const Duration(seconds: 2);

    if (withinWindow) {
      ref.read(backExitPromptAtProvider.notifier).state = null;
      await SystemNavigator.pop();
      return true;
    }

    ref.read(backExitPromptAtProvider.notifier).state = now;
    final messengerContext = rootNavigatorKey.currentContext ?? context;
    final messenger = ScaffoldMessenger.maybeOf(messengerContext);
    final strings = AppLocalizations.of(messengerContext)?.strings;
    if (messenger != null && strings != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(strings.pressBackAgainToExit),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
    return true;
  } finally {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _backHandling = false;
    });
  }
}

/// PopScope wrapper for root shells (predictive back / Android 13+).
///
/// Blocks auto-exit on roots and delegates to [handleAppBack] for tabs +
/// double-back-to-exit. When a previous route exists, allows the framework pop.
class RootBackScope extends ConsumerWidget {
  const RootBackScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter.maybeOf(context);
    final canPopStack = router?.canPop() ?? false;
    final navCanPop = rootNavigatorKey.currentState?.canPop() ?? false;
    final allowFrameworkPop = canPopStack || navCanPop;

    return PopScope(
      canPop: allowFrameworkPop,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await handleAppBack(context: context, ref: ref);
      },
      child: child,
    );
  }
}
