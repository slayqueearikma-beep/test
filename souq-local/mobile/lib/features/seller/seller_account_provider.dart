import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';

/// Loads and caches the authenticated seller's profile + dashboard stats.
///
/// Important: do **not** `watch` [userSessionProvider] here. Updating the session
/// after a successful fetch would re-trigger this provider and spam the API.
final sellerAccountProvider = FutureProvider.autoDispose<SellerAccountData>((ref) async {
  final session = ref.read(userSessionProvider);
  if (session == null || session.accountType != AccountType.seller) {
    throw ApiException('Seller session required');
  }

  // Keep the provider alive while the seller shell is open so brief unmounts
  // (navigation between seller tabs/screens) do not immediately dispose + refetch.
  final link = ref.keepAlive();
  ref.onCancel(() {
    Future<void>.delayed(const Duration(seconds: 30), link.close);
  });

  final api = apiServiceProvider;
  final profile = await api.fetchMySeller();
  final stats = await api.fetchMySellerDashboard();

  final storage = ref.read(appStorageProvider);
  if (storage != null) {
    final needsUpdate = session.sellerId != profile.id ||
        session.businessName != profile.businessName ||
        session.city != profile.city;
    if (needsUpdate) {
      final updated = session.copyWith(
        sellerId: profile.id,
        businessName: profile.businessName,
        city: profile.city,
      );
      await storage.saveSession(updated);
      ref.read(userSessionProvider.notifier).state = updated;
    }
  }

  return SellerAccountData(profile: profile, stats: stats);
});

class SellerAccountData {
  const SellerAccountData({required this.profile, required this.stats});

  final SellerModel profile;
  final SellerDashboardStats stats;
}
