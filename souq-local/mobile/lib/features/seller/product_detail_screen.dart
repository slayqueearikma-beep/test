import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/network_image_view.dart';
import '../../l10n/app_localizations.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({
    super.key,
    required this.sellerId,
    required this.productId,
  });

  final String sellerId;
  final String productId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SellerModel>(
      future: apiServiceProvider.fetchSeller(sellerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(context.l10n.somethingWentWrong)),
          );
        }

        final seller = snapshot.data!;
        final matches = seller.products.where((p) => p.id == productId).toList();
        if (matches.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.products)),
            body: Center(child: Text(context.l10n.noProductsListed)),
          );
        }
        final product = matches.first;

        return Scaffold(
          appBar: AppBar(title: Text(product.name)),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: NetworkImageView(url: product.imageUrl),
                ),
              ),
              const SizedBox(height: 20),
              if (product.priceMad != null)
                Text(
                  '${product.priceMad!.toStringAsFixed(2)} MAD',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  RatingBarIndicator(
                    rating: seller.averageRating,
                    itemBuilder: (_, __) => const Icon(Icons.star, color: AppColors.star),
                    itemCount: 5,
                    itemSize: 18,
                  ),
                  const SizedBox(width: 8),
                  Text('${seller.averageRating} · ${seller.businessName}'),
                ],
              ),
              const SizedBox(height: 16),
              Text(product.description.isEmpty ? context.l10n.noDescription : product.description),
            ],
          ),
        );
      },
    );
  }
}
