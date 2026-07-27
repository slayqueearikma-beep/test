import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

const int kReviewCommentMaxLength = 500;

/// Modern bottom sheet for multi-category seller ratings.
Future<bool> showRateSellerSheet({
  required BuildContext context,
  required SellerModel seller,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: _RateSellerSheet(seller: seller),
      );
    },
  ).then((value) => value ?? false);
}

class _RateSellerSheet extends StatefulWidget {
  const _RateSellerSheet({required this.seller});

  final SellerModel seller;

  @override
  State<_RateSellerSheet> createState() => _RateSellerSheetState();
}

class _RateSellerSheetState extends State<_RateSellerSheet> {
  final _commentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  double? _productQuality;
  double? _customerService;
  double? _communication;
  double? _trustworthiness;
  var _submitting = false;
  String? _validationMessage;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  bool get _allRated =>
      _productQuality != null &&
      _customerService != null &&
      _communication != null &&
      _trustworthiness != null;

  double? get _overall {
    if (!_allRated) return null;
    return (_productQuality! +
            _customerService! +
            _communication! +
            _trustworthiness!) /
        4.0;
  }

  Future<void> _submit(AppStrings l10n) async {
    if (!_allRated) {
      setState(() => _validationMessage = l10n.rateAllCategoriesRequired);
      return;
    }
    setState(() {
      _submitting = true;
      _validationMessage = null;
    });
    try {
      await apiServiceProvider.submitReview(
        widget.seller.id,
        productQuality: _productQuality!.round(),
        customerService: _customerService!.round(),
        communication: _communication!.round(),
        trustworthiness: _trustworthiness!.round(),
        comment: _commentController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.somethingWentWrong),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final overall = _overall;
    final commentLength = _commentController.text.characters.length;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.rateSellerTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.seller.businessName,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? AppColors.darkCard
                      : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? AppColors.darkBorder
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.overallRating,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (overall == null)
                      Text(
                        '—',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else ...[
                      RatingBarIndicator(
                        rating: overall,
                        itemBuilder: (_, __) => const Icon(Icons.star_rounded,
                            color: AppColors.star),
                        itemCount: 5,
                        itemSize: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        overall.toStringAsFixed(1),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _CategoryRatingRow(
                label: l10n.ratingProductQuality,
                value: _productQuality,
                enabled: !_submitting,
                onChanged: (value) => setState(() {
                  _productQuality = value;
                  _validationMessage = null;
                }),
              ),
              _CategoryRatingRow(
                label: l10n.ratingCustomerService,
                value: _customerService,
                enabled: !_submitting,
                onChanged: (value) => setState(() {
                  _customerService = value;
                  _validationMessage = null;
                }),
              ),
              _CategoryRatingRow(
                label: l10n.ratingCommunication,
                value: _communication,
                enabled: !_submitting,
                onChanged: (value) => setState(() {
                  _communication = value;
                  _validationMessage = null;
                }),
              ),
              _CategoryRatingRow(
                label: l10n.ratingTrustworthiness,
                value: _trustworthiness,
                enabled: !_submitting,
                onChanged: (value) => setState(() {
                  _trustworthiness = value;
                  _validationMessage = null;
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                enabled: !_submitting,
                maxLines: 4,
                maxLength: kReviewCommentMaxLength,
                textInputAction: TextInputAction.newline,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.shareExperience,
                  alignLabelWithHint: true,
                  counterText: '$commentLength / $kReviewCommentMaxLength',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              if (_validationMessage != null) ...[
                const SizedBox(height: 4),
                Text(
                  _validationMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _submitting ? null : () => _submit(l10n),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.submitReview),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRatingRow extends StatelessWidget {
  const _CategoryRatingRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final String label;
  final double? value;
  final ValueChanged<double> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Semantics(
        label: label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            RatingBar.builder(
              initialRating: value ?? 0,
              minRating: 1,
              allowHalfRating: false,
              itemCount: 5,
              itemSize: 32,
              glow: false,
              ignoreGestures: !enabled,
              unratedColor: theme.brightness == Brightness.dark
                  ? AppColors.darkBorder
                  : AppColors.border,
              itemBuilder: (_, __) =>
                  const Icon(Icons.star_rounded, color: AppColors.star),
              onRatingUpdate: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
