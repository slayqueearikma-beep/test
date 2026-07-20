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
    _sellerFuture = apiServiceProvider.fetchSeller(widget.sellerId, auth: asOwner);
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

  void _reload() {
    final session = ref.read(userSessionProvider);
    final asOwner = session?.accountType == AccountType.seller;
    setState(() {
      _sellerFuture = apiServiceProvider.fetchSeller(widget.sellerId, auth: asOwner);
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
                            itemBuilder: (_, __) => const Icon(Icons.star, color: AppColors.star),
                            itemCount: 5,
                            itemSize: 20,
                          ),
                          const SizedBox(width: 8),
                          Text('${seller.averageRating} (${l10n.reviewsCount(seller.reviewCount)})'),
                          if (seller.achievementStars > 0) ...[
                            const Spacer(),
                            ...List.generate(
                              seller.achievementStars.clamp(0, 5),
                              (_) => const Icon(Icons.star, color: AppColors.star),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(seller.description),
                      const SizedBox(height: 16),
                      _InfoRow(icon: Icons.location_on_outlined, text: seller.address),
                      _InfoRow(icon: Icons.phone_outlined, text: seller.phone.isEmpty ? l10n.noPhone : seller.phone),
                      if (!seller.openingHours.isEmpty)
                        _InfoRow(
                          icon: Icons.schedule_outlined,
                          text:
                              '${l10n.opens} ${seller.openingHours.open} · ${l10n.closes} ${seller.openingHours.close}',
                        ),
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
                              onPressed: () => _showReviewSheet(seller),
                              icon: const Icon(Icons.rate_review_outlined),
                              label: Text(l10n.review),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(l10n.products, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      if (seller.products.isEmpty)
                        Text(l10n.noProductsListed)
                      else
                        SizedBox(
                          height: 180,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: seller.products.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (_, index) {
                              final product = seller.products[index];
                              return _CatalogCard(
                                title: product.name,
                                price: product.priceMad,
                                imageUrl: product.imageUrl,
                                onTap: () => context.push('/product/${seller.id}/${product.id}'),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(l10n.services, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      if (seller.services.isEmpty)
                        Text(l10n.noServicesListed)
                      else
                        ...seller.services.map(
                          (service) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(service.name),
                            subtitle: Text(service.description),
                            trailing: service.priceMad != null ? Text('${service.priceMad!.toStringAsFixed(0)} MAD') : null,
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(l10n.reviews, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      FutureBuilder<List<ReviewModel>>(
                        future: _reviewsFuture,
                        builder: (context, reviewSnapshot) {
                          if (reviewSnapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
                                    leading: CircleAvatar(child: Text(r.buyerDisplayName.isNotEmpty ? r.buyerDisplayName[0] : 'B')),
                                    title: Row(
                                      children: [
                                        Text(r.buyerDisplayName),
                                        const SizedBox(width: 8),
                                        ...List.generate(r.rating, (_) => const Icon(Icons.star, size: 14, color: AppColors.star)),
                                      ],
                                    ),
                                    subtitle: Text(r.comment),
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

  Future<void> _showReviewSheet(SellerModel seller) async {
    final l10n = context.l10n;
    final session = ref.read(userSessionProvider);
    if (session == null) {
      if (!mounted) return;
      await context.push('/login');
      return;
    }
    if (session.accountType != AccountType.buyer) {
      if (!mounted) return;
      await showAppErrorDialog(context, title: l10n.somethingWentWrong, message: l10n.somethingWentWrong);
      return;
    }

    var rating = 5.0;
    var submitting = false;
    final controller = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${l10n.review} ${seller.businessName}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  RatingBar.builder(
                    initialRating: rating,
                    minRating: 1,
                    itemBuilder: (_, __) => const Icon(Icons.star, color: AppColors.star),
                    onRatingUpdate: (value) => rating = value,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    enabled: !submitting,
                    decoration: InputDecoration(hintText: l10n.shareExperience),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: submitting
                          ? null
                          : () async {
                              setModalState(() => submitting = true);
                              try {
                                await apiServiceProvider.submitReview(
                                  seller.id,
                                  rating: rating.round(),
                                  comment: controller.text,
                                );
                                if (sheetContext.mounted) Navigator.pop(sheetContext);
                                if (mounted) _reload();
                              } on Object catch (e) {
                                setModalState(() => submitting = false);
                                if (context.mounted) {
                                  await showAppErrorDialog(
                                    context,
                                    title: l10n.somethingWentWrong,
                                    message: e.toString(),
                                  );
                                }
                              }
                            },
                      child: submitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(l10n.submitReview),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
  const _CatalogCard({required this.title, this.price, required this.imageUrl, required this.onTap});

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
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (price != null) Text('${price!.toStringAsFixed(0)} MAD', style: const TextStyle(color: AppColors.primary)),
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
