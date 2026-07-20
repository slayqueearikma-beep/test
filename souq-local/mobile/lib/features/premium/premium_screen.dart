import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/error_dialog.dart';
import '../../l10n/app_localizations.dart';

final subscriptionPlansProvider =
    FutureProvider.autoDispose<List<SubscriptionPlanModel>>((ref) {
  return apiServiceProvider.fetchSubscriptionPlans();
});

final mySubscriptionProvider =
    FutureProvider.autoDispose<SubscriptionModel?>((ref) {
  final session = ref.watch(userSessionProvider);
  if (session == null || session.isGuest) return Future.value(null);
  return apiServiceProvider.fetchMySubscription();
});

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  String? _subscribingCode;

  Future<void> _subscribe(SubscriptionPlanModel plan) async {
    final l10n = context.l10n;
    final session = ref.read(userSessionProvider);
    if (session == null || session.isGuest) {
      context.push('/login');
      return;
    }
    setState(() => _subscribingCode = plan.code);
    try {
      await apiServiceProvider.subscribe(plan.code);
      ref.invalidate(mySubscriptionProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.premiumActivated)));
      }
    } on ApiException catch (error) {
      if (mounted) {
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: error.message);
      }
    } finally {
      if (mounted) setState(() => _subscribingCode = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final subscriptionAsync = ref.watch(mySubscriptionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.premium)),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView.fromError(error,
            onRetry: () => ref.invalidate(subscriptionPlansProvider)),
        data: (plans) {
          if (plans.isEmpty) {
            return Center(child: Text(l10n.noPremiumPlans));
          }
          final active = subscriptionAsync.valueOrNull;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(subscriptionPlansProvider);
              ref.invalidate(mySubscriptionProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.workspace_premium_outlined,
                            color: AppColors.primary, size: 36),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.premiumTitle,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.premiumSubtitle,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                        if (active != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Chip(
                            avatar: const Icon(Icons.check_circle,
                                color: AppColors.success),
                            label: Text(l10n.activePlan(active.plan.name)),
                          ),
                        ] else if (session == null || session.isGuest) ...[
                          const SizedBox(height: AppSpacing.md),
                          TextButton.icon(
                            onPressed: () => context.push('/login'),
                            icon: const Icon(Icons.login),
                            label: Text(l10n.signInToSubscribe),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ...plans.map(
                  (plan) => _PlanCard(
                    plan: plan,
                    active: active?.plan.code == plan.code,
                    loading: _subscribingCode == plan.code,
                    onSubscribe: () => _subscribe(plan),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.active,
    required this.loading,
    required this.onSubscribe,
  });

  final SubscriptionPlanModel plan;
  final bool active;
  final bool loading;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(plan.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                if (active)
                  const Icon(Icons.check_circle, color: AppColors.success),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(plan.description,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${plan.priceMad.toStringAsFixed(0)} MAD / ${plan.billingPeriodDays} ${l10n.days}',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              ...plan.features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(Icons.check,
                          color: AppColors.success, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(feature)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: active || loading ? null : onSubscribe,
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(active ? l10n.currentPlan : l10n.subscribe),
            ),
          ],
        ),
      ),
    );
  }
}
