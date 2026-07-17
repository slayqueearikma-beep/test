import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

class SellerDetailScreen extends StatefulWidget {
  const SellerDetailScreen({super.key, required this.sellerId});

  final String sellerId;

  @override
  State<SellerDetailScreen> createState() => _SellerDetailScreenState();
}

class _SellerDetailScreenState extends State<SellerDetailScreen> {
  late Future<SellerModel> _sellerFuture;
  late Future<List<ReviewModel>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _sellerFuture = apiServiceProvider.fetchSeller(widget.sellerId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<SellerModel>(
        future: _sellerFuture,
        builder: (context, snapshot) {
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
                  background: Container(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                    child: seller.coverImageUrl.isEmpty
                        ? const Icon(Icons.storefront, size: 72)
                        : null,
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
    var rating = 5.0;
    final controller = TextEditingController();
    final l10n = context.l10n;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
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
                decoration: InputDecoration(hintText: l10n.shareExperience),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await apiServiceProvider.submitReview(
                      seller.id,
                      rating: rating.round(),
                      comment: controller.text,
                    );
                    if (context.mounted) Navigator.pop(context);
                    setState(() {
                      _sellerFuture = apiServiceProvider.fetchSeller(widget.sellerId);
                      _reviewsFuture = apiServiceProvider.fetchReviews(widget.sellerId);
                    });
                  },
                  child: Text(l10n.submitReview),
                ),
              ),
            ],
          ),
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
  const _CatalogCard({required this.title, this.price, required this.onTap});

  final String title;
  final double? price;
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
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                  child: const Icon(Icons.image_outlined),
                ),
              ),
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
