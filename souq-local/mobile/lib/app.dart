import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/services/app_storage.dart';
import 'core/services/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/buyer/buyer_home_screen.dart';
import 'features/cart/cart_screen.dart';
import 'features/checkout/checkout_screen.dart';
import 'features/map/map_screen.dart';
import 'features/onboarding/account_type_onboarding_screen.dart';
import 'features/onboarding/buyer_registration_screen.dart';
import 'features/onboarding/onboarding_welcome_screen.dart';
import 'features/onboarding/seller_registration_screen.dart';
import 'features/orders/buyer_orders_screen.dart';
import 'features/orders/order_detail_screen.dart';
import 'features/premium/premium_screen.dart';
import 'features/search/search_screen.dart';
import 'features/seller/product_detail_screen.dart';
import 'features/seller/seller_dashboard_screen.dart';
import 'features/seller/seller_detail_screen.dart';
import 'features/seller/seller_orders_screen.dart';
import 'features/seller/seller_products_screen.dart';
import 'features/seller/seller_profile_screen.dart';
import 'features/seller/seller_reviews_screen.dart';
import 'features/seller/seller_settings_screen.dart';
import 'features/wishlist/wishlist_screen.dart';
import 'features/settings/language_selection_screen.dart';
import 'features/splash/splash_screen.dart';
import 'l10n/app_localizations.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final session =
          ProviderScope.containerOf(context).read(userSessionProvider);
      final path = state.matchedLocation;
      final isSellerManagement = path == '/seller/dashboard' ||
          path.startsWith('/seller/orders') ||
          path.startsWith('/seller/products') ||
          path.startsWith('/seller/profile') ||
          path.startsWith('/seller/reviews') ||
          path.startsWith('/seller/notifications') ||
          path.startsWith('/seller/settings');
      final isAuthProtected = path == '/checkout' ||
          path == '/wishlist' ||
          path == '/orders' ||
          path.startsWith('/orders/') ||
          isSellerManagement;
      final isAuthenticated = session != null && !session.isGuest;
      if (isAuthProtected && !isAuthenticated) {
        return '/login';
      }
      if (isSellerManagement &&
          isAuthenticated &&
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
      GoRoute(path: '/buyer/home', builder: (_, __) => const BuyerHomeShell()),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
      GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
      GoRoute(path: '/checkout', builder: (_, __) => const CheckoutScreen()),
      GoRoute(path: '/orders', builder: (_, __) => const BuyerOrdersScreen()),
      GoRoute(
          path: '/orders/:id',
          builder: (_, state) =>
              OrderDetailScreen(orderId: state.pathParameters['id']!)),
      GoRoute(path: '/wishlist', builder: (_, __) => const WishlistScreen()),
      GoRoute(path: '/premium', builder: (_, __) => const PremiumScreen()),
      GoRoute(
          path: '/seller/dashboard',
          builder: (_, __) => const SellerDashboardScreen()),
      GoRoute(
          path: '/seller/orders',
          builder: (_, __) => const SellerOrdersScreen()),
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
});

class MarGemApp extends ConsumerWidget {
  const MarGemApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);

    ref.listen(appStorageProvider, (previous, next) {
      if (next != null) {
        ref.read(localeProvider.notifier).updateStorage(next);
      }
    });

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
