import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/network_image_view.dart';
import '../../l10n/app_localizations.dart';
import 'rate_seller_sheet.dart';

class SellerDetailScreen extends ConsumerStatefulWidget {
  const SellerDetailScreen({super.key, required this.sellerId});

  final String sellerId;

  @override
  ConsumerState<SellerDetailScreen> createState() => _SellerDetailScreenState();
}

class _SellerDetailScreenState extends ConsumerState<SellerDetailScreen> {
  late Future<SellerModel> _sellerFuture;
  late Future<List<ReviewModel>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    final session = ref.read(userSessionProvider);
    final asOwner = session?.accountType == AccountType.seller;
    _sellerFuture =
        apiServiceProvider.fetchSeller(widget.sellerId, auth: asOwner);
    _reviewsFuture = apiServiceProvider.fetchReviews(widget.sellerId);
  }

  Future<void> _openDirections(SellerModel seller) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${seller.latitude},${seller.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _messageSeller(SellerModel seller) async {
    final l10n = context.l10n;
    final session = ref.read(userSessionProvider);
    if (session == null || session.isGuest) {
      if (!mounted) return;
      await context.push('/login');
      return;
    }
    // Sellers messaging their own storefront is blocked by the API — hide early.
    final mySellerId = session.sellerId;
    if (mySellerId != null && mySellerId.isNotEmpty && mySellerId == seller.id) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cannotMessageOwnStore)),
      );
      return;
    }
    try {
      await apiServiceProvider.createContactEvent(
        sellerId: seller.id,
        channel: 'message',
      );
      final message = await apiServiceProvider.startConversationWithSeller(
        seller.id,
        l10n.inquiryAboutListing(seller.businessName),
      );
      if (!mounted) return;
      context.push('/messages/${message.conversationId}');
    } catch (error) {
      if (!mounted) return;
      await showAppErrorDialog(context,
          title: l10n.somethingWentWrong, message: error.toString());
    }
  }

  Future<void> _recordContact(SellerModel seller, String channel) async {
    try {
      await apiServiceProvider.createContactEvent(
        sellerId: seller.id,
        channel: channel,
      );
    } catch (_) {}
  }

  Future<void> _callSeller(SellerModel seller) async {
    final phone = seller.phone.trim();
    if (phone.isEmpty) return;
    await _recordContact(seller, 'call');
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _followSeller(SellerModel seller) async {
    final l10n = context.l10n;
    final session = ref.read(userSessionProvider);
    if (session == null || session.isGuest) {
      if (!mounted) return;
      await context.push('/login');
      return;
    }
    try {
      await apiServiceProvider.followSeller(seller.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.nowFollowing(seller.businessName))),
      );
    } catch (error) {
      if (!mounted) return;
      await showAppErrorDialog(context,
          title: l10n.somethingWentWrong, message: error.toString());
    }
  }

  void _reload() {
    final session = ref.read(userSessionProvider);
    final asOwner = session?.accountType == AccountType.seller;
    setState(() {
      _sellerFuture =
          apiServiceProvider.fetchSeller(widget.sellerId, auth: asOwner);
      _reviewsFuture = apiServiceProvider.fetchReviews(widget.sellerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<SellerModel>(
        future: _sellerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AsyncErrorView.fromError(snapshot.error!, onRetry: _reload);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final seller = snapshot.data!;
          final l10n = context.l10n;
          final session = ref.watch(userSessionProvider);
          final isOwnStore = session?.sellerId != null &&
              session!.sellerId!.isNotEmpty &&
              session.sellerId == seller.id;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(seller.businessName),
                  background: NetworkImageView(
                    url: seller.coverImageUrl,
                    placeholderIcon: Icons.storefront,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          RatingBarIndicator(
                            rating: seller.averageRating,
                            itemBuilder: (_, __) =>
                                const Icon(Icons.star, color: AppColors.star),
                            itemCount: 5,
                            itemSize: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                              '${seller.averageRating} (${l10n.reviewsCount(seller.reviewCount)})'),
                          const Spacer(),
                          if (seller.verificationStatus == 'verified')
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.verified,
                                  color: Colors.blue, size: 22),
                            ),
                          if (seller.isPremium)
                            const Icon(Icons.workspace_premium,
                                color: Color(0xFFC9A227), size: 22),
                          if (seller.achievementStars > 0)
                            ...List.generate(
                              seller.achievementStars.clamp(0, 5),
                              (_) =>
                                  const Icon(Icons.star, color: AppColors.star),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(seller.description),
                      const SizedBox(height: 16),
                      _InfoRow(
                          icon: Icons.location_on_outlined,
                          text: seller.address),
                      _InfoRow(
                          icon: Icons.phone_outlined,
                          text: seller.phone.isEmpty
                              ? l10n.noPhone
                              : seller.phone),
                      if (seller.whatsappNumber.isNotEmpty)
                        _InfoRow(
                            icon: Icons.chat_outlined,
                            text: seller.whatsappNumber),
                      if (seller.websiteUrl.isNotEmpty)
                        _InfoRow(
                            icon: Icons.language_outlined,
                            text: seller.websiteUrl),
                      if (!seller.openingHours.isEmpty)
                        _InfoRow(
                          icon: Icons.schedule_outlined,
                          text:
                              '${l10n.opens} ${seller.openingHours.open} · ${l10n.closes} ${seller.openingHours.close}',
                        ),
                      if (seller.avgResponseMinutes > 0)
                        _InfoRow(
                          icon: Icons.timer_outlined,
                          text: l10n.responseTimeLabel(
                              seller.avgResponseMinutes),
                        ),
                      if (seller.paymentMethods.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(l10n.acceptedPaymentMethods,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: seller.paymentMethods
                              .map((method) => Chip(
                                    label: Text(method.replaceAll('_', ' ')),
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                      ],
                      if (seller.deliveryMethods.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(l10n.deliveryOptionsLabel,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: seller.deliveryMethods
                              .map((method) => Chip(
                                    label: Text(method.replaceAll('_', ' ')),
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openDirections(seller),
                              icon: const Icon(Icons.directions),
                              label: Text(l10n.directions),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed:
                                  seller.phone.trim().isEmpty ? null : () => _callSeller(seller),
                              icon: const Icon(Icons.call_outlined),
                              label: Text(l10n.callSeller),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!isOwnStore)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _openRateSeller(seller),
                            icon: const Icon(Icons.star_rate_rounded),
                            label: Text(l10n.rateSeller),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ),
                      if (!isOwnStore) const SizedBox(height: 12),
                      Row(
                        children: [
                          if (!isOwnStore)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _messageSeller(seller),
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: Text(l10n.messageBusiness),
                              ),
                            ),
                          if (!isOwnStore) const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _followSeller(seller),
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                              label: Text(l10n.followBusiness),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(l10n.products,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      if (seller.products.isEmpty)
                        Text(l10n.noProductsListed)
                      else
                        SizedBox(
                          height: 180,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: seller.products.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (_, index) {
                              final product = seller.products[index];
                              return _CatalogCard(
                                title: product.name,
                                price: product.priceMad,
                                imageUrl: product.imageUrl,
                                onTap: () => context.push(
                                    '/product/${seller.id}/${product.id}'),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(l10n.services,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      if (seller.services.isEmpty)
                        Text(l10n.noServicesListed)
                      else
                        ...seller.services.map(
                          (service) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(service.name),
                            subtitle: Text(service.description),
                            trailing: service.priceMad != null
                                ? Text(
                                    '${service.priceMad!.toStringAsFixed(0)} MAD')
                                : null,
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(l10n.reviews,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      FutureBuilder<List<ReviewModel>>(
                        future: _reviewsFuture,
                        builder: (context, reviewSnapshot) {
                          if (reviewSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            );
                          }
                          if (reviewSnapshot.hasError) {
                            return Text(l10n.somethingWentWrong);
                          }
                          final reviews = reviewSnapshot.data ?? [];
                          if (reviews.isEmpty) return Text(l10n.noReviewsYet);
                          return Column(
                            children: reviews
                                .map(
                                  (r) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                        child: Text(
                                            r.buyerDisplayName.isNotEmpty
                                                ? r.buyerDisplayName[0]
                                                : 'B')),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            r.buyerDisplayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        RatingBarIndicator(
                                          rating: r.overallRating,
                                          itemBuilder: (_, __) =>
                                              const Icon(Icons.star,
                                                  color: AppColors.star),
                                          itemCount: 5,
                                          itemSize: 14,
                                        ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (r.comment.isNotEmpty) Text(r.comment),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${l10n.ratingProductQuality}: ${r.productQuality} · '
                                          '${l10n.ratingCustomerService}: ${r.customerService} · '
                                          '${l10n.ratingCommunication}: ${r.communication} · '
                                          '${l10n.ratingTrustworthiness}: ${r.trustworthiness}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openRateSeller(SellerModel seller) async {
    final l10n = context.l10n;
    final session = ref.read(userSessionProvider);
    if (session == null || session.isGuest) {
      if (!mounted) return;
      await context.push('/login');
      return;
    }
    if (session.sellerId != null &&
        session.sellerId!.isNotEmpty &&
        session.sellerId == seller.id) {
      if (!mounted) return;
      await showAppErrorDialog(context,
          title: l10n.somethingWentWrong, message: l10n.cannotReviewOwnStore);
      return;
    }

    try {
      final eligibility =
          await apiServiceProvider.fetchReviewEligibility(seller.id);
      if (!mounted) return;
      if (!eligibility.canReview) {
        final message = switch (eligibility.reason) {
          'own_store' => l10n.cannotReviewOwnStore,
          'no_completed_transaction' => l10n.reviewRequiresCompletedTransaction,
          _ => l10n.somethingWentWrong,
        };
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: message);
        return;
      }

      final submitted = await showRateSellerSheet(
        context: context,
        seller: seller,
      );
      if (!mounted) return;
      if (submitted) {
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.reviewSubmittedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on Object catch (error) {
      if (!mounted) return;
      await showAppErrorDialog(context,
          title: l10n.somethingWentWrong, message: error.toString());
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard(
      {required this.title,
      this.price,
      required this.imageUrl,
      required this.onTap});

  final String title;
  final double? price;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: NetworkImageView(url: imageUrl)),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (price != null)
                      Text('${price!.toStringAsFixed(0)} MAD',
                          style: const TextStyle(color: AppColors.primary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
