import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/models/models.dart';
import 'core/navigation/app_back_handler.dart';
import 'core/services/app_storage.dart';
import 'core/services/auth_service.dart';
import 'core/services/locale_provider.dart';
import 'core/services/theme_mode_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/verify_email_screen.dart';
import 'features/buyer/buyer_home_screen.dart';
import 'features/map/map_screen.dart';
import 'features/messages/messages_inbox_screen.dart';
import 'features/onboarding/account_type_onboarding_screen.dart';
import 'features/onboarding/become_seller_screen.dart';
import 'features/onboarding/buyer_registration_screen.dart';
import 'features/onboarding/onboarding_welcome_screen.dart';
import 'features/onboarding/seller_registration_screen.dart';
import 'features/premium/premium_screen.dart';
import 'features/search/search_screen.dart';
import 'features/seller/product_detail_screen.dart';
import 'features/seller/seller_catalog_screen.dart';
import 'features/seller/seller_dashboard_screen.dart';
import 'features/seller/seller_detail_screen.dart';
import 'features/seller/seller_products_screen.dart';
import 'features/seller/seller_profile_screen.dart';
import 'features/seller/seller_reviews_screen.dart';
import 'features/seller/seller_settings_screen.dart';
import 'features/wishlist/wishlist_screen.dart';
import 'features/settings/language_selection_screen.dart';
import 'features/splash/splash_screen.dart';
import 'l10n/app_localizations.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    // Keep the page stack for Android system-back; only splash/auth flows
    // intentionally replace via context.go().
    redirect: (context, state) {
      final session =
          ProviderScope.containerOf(context).read(userSessionProvider);
      final path = state.matchedLocation;
      final isSellerManagement = path == '/seller/dashboard' ||
          path.startsWith('/seller/products') ||
          path.startsWith('/seller/profile') ||
          path.startsWith('/seller/reviews') ||
          path.startsWith('/seller/notifications') ||
          path.startsWith('/seller/settings') ||
          path.startsWith('/seller/messages');
      final isAuthProtected = isSellerManagement;
      final isAuthenticated = session != null && !session.isGuest;
      if (isAuthProtected && !isAuthenticated) {
        return '/login';
      }
      if (isSellerManagement &&
          isAuthenticated &&
          !session.hasSellerProfile &&
          session.accountType != AccountType.seller) {
        return '/buyer/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(
          path: '/language',
          builder: (_, __) => const LanguageSelectionScreen()),
      GoRoute(
        path: '/settings/language',
        builder: (_, __) => const LanguageSelectionScreen(fromSettings: true),
      ),
      GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingWelcomeScreen()),
      GoRoute(
          path: '/onboarding/account-type',
          builder: (_, __) => const AccountTypeOnboardingScreen()),
      GoRoute(
          path: '/onboarding/buyer-register',
          builder: (_, __) => const BuyerRegistrationScreen()),
      GoRoute(
          path: '/onboarding/seller-register',
          builder: (_, __) => const SellerRegistrationScreen()),
      GoRoute(
          path: '/onboarding/become-seller',
          builder: (_, __) => const BecomeSellerScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => ForgotPasswordScreen(
          resetMode: true,
          initialToken: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, state) => VerifyEmailScreen(
          initialToken: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(path: '/buyer/home', builder: (_, __) => const BuyerHomeShell()),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
      GoRoute(path: '/favorites', builder: (_, __) => const FavoritesScreen()),
      GoRoute(path: '/premium', builder: (_, __) => const PremiumScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const BuyerProfileScreen()),
      GoRoute(
          path: '/messages',
          builder: (_, __) => const Scaffold(body: MessagesInboxScreen())),
      GoRoute(
        path: '/messages/:id',
        builder: (_, state) {
          final extra = state.extra;
          return ConversationThreadScreen(
            conversationId: state.pathParameters['id']!,
            conversation: extra is ConversationModel ? extra : null,
          );
        },
      ),
      GoRoute(
          path: '/seller/dashboard',
          builder: (_, __) => const SellerDashboardScreen()),
      GoRoute(
          path: '/seller/messages',
          builder: (_, __) => const Scaffold(body: MessagesInboxScreen())),
      GoRoute(
          path: '/seller/products',
          builder: (_, __) => const SellerProductsScreen()),
      GoRoute(
          path: '/seller/products/new',
          builder: (_, __) => const SellerProductEditorScreen()),
      GoRoute(
        path: '/seller/products/:productId',
        builder: (_, state) => SellerProductEditorScreen(
            productId: state.pathParameters['productId']),
      ),
      GoRoute(
          path: '/seller/profile',
          builder: (_, __) => const SellerProfileScreen()),
      GoRoute(
          path: '/seller/reviews',
          builder: (_, __) => const SellerReviewsScreen()),
      GoRoute(
          path: '/seller/notifications',
          builder: (_, __) => const SellerNotificationsScreen()),
      GoRoute(
          path: '/seller/settings',
          builder: (_, __) => const SellerSettingsScreen()),
      GoRoute(
        path: '/seller/:id',
        builder: (_, state) =>
            SellerDetailScreen(sellerId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'products',
            builder: (_, state) {
              final extra = state.extra;
              return SellerCatalogScreen(
                sellerId: state.pathParameters['id']!,
                initialSeller: extra is SellerModel ? extra : null,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/product/:sellerId/:productId',
        builder: (_, state) => ProductDetailScreen(
          sellerId: state.pathParameters['sellerId']!,
          productId: state.pathParameters['productId']!,
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class MarGemApp extends ConsumerStatefulWidget {
  const MarGemApp({super.key});

  @override
  ConsumerState<MarGemApp> createState() => _MarGemAppState();
}

class _MarGemAppState extends ConsumerState<MarGemApp>
    with WidgetsBindingObserver {
  var _sessionBound = false;

  @override
  void initState() {
    super.initState();
    // Intercept Android system back before go_router exits the activity when
    // canPop is false on a root route (and still pop the stack when it can).
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) {
      // No navigator yet (startup) — let the framework decide.
      return false;
    }
    return handleAppBack(context: navContext, ref: ref);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);

    ref.listen(appStorageProvider, (previous, next) {
      if (next != null) {
        ref.read(localeProvider.notifier).updateStorage(next);
        ref.read(themeModeProvider.notifier).updateStorage(next);
      }
    });

    // Bind once at the app root so the callback outlives SplashScreen disposal.
    if (!_sessionBound) {
      _sessionBound = true;
      ref.read(authServiceProvider).bindApi(
        onSessionExpired: () async {
          final prefs = await ref.read(sharedPreferencesProvider.future);
          await ref.read(authServiceProvider).logout(prefs);
          await ref.read(appStorageProvider)?.logout();
          ref.read(userSessionProvider.notifier).state = null;
          ref.read(authSessionProvider.notifier).state = null;
          router.go('/login');
        },
      );
    }

    return MaterialApp.router(
      title: 'MarGem',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
