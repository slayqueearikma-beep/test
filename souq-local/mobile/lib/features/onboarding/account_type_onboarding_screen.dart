import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/form_widgets.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../../l10n/app_localizations.dart';

class AccountTypeOnboardingScreen extends ConsumerStatefulWidget {
  const AccountTypeOnboardingScreen({super.key});

  @override
  ConsumerState<AccountTypeOnboardingScreen> createState() =>
      _AccountTypeOnboardingScreenState();
}

class _AccountTypeOnboardingScreenState
    extends ConsumerState<AccountTypeOnboardingScreen> {
  AccountType? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return OnboardingScaffold(
      showBack: true,
      bottom: Column(
        children: [
          PrimaryButton(
            label: l10n.continueLabel,
            onPressed: _selected == null
                ? null
                : () {
                    if (_selected == AccountType.buyer) {
                      context.push('/onboarding/buyer-register');
                    } else {
                      context.push('/onboarding/seller-register');
                    }
                  },
          ),
          SecondaryTextButton(
              label: l10n.guestContinue, onPressed: _continueAsGuest),
          SecondaryTextButton(label: l10n.back, onPressed: () => context.pop()),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppScreenHeader(
            title: l10n.chooseAccountType,
            subtitle: l10n.chooseAccountTypeSubtitle,
            showLogo: true,
          ),
          const SizedBox(height: AppSpacing.xl),
          SelectionCard(
            title: l10n.buyer,
            subtitle: l10n.buyerSubtitle,
            icon: Icons.shopping_bag_outlined,
            selected: _selected == AccountType.buyer,
            accentColor: const Color(0xFF4D96FF),
            bulletPoints: [
              l10n.buyerBullet1,
              l10n.buyerBullet2,
              l10n.buyerBullet3,
              l10n.buyerBullet4
            ],
            onTap: () => setState(() => _selected = AccountType.buyer),
          ),
          const SizedBox(height: AppSpacing.md),
          SelectionCard(
            title: l10n.seller,
            subtitle: l10n.sellerSubtitle,
            icon: Icons.store_mall_directory_outlined,
            selected: _selected == AccountType.seller,
            accentColor: AppColors.primary,
            bulletPoints: [
              l10n.sellerBullet1,
              l10n.sellerBullet2,
              l10n.sellerBullet3,
              l10n.sellerBullet4
            ],
            onTap: () => setState(() => _selected = AccountType.seller),
          ),
        ],
      ),
    );
  }

  Future<void> _continueAsGuest() async {
    final storage = ref.read(appStorageProvider);
    if (storage == null) return;
    await storage.completeOnboarding();
    await storage.saveGuestSession(city: AppConfig.launchCity);
    ref.read(userSessionProvider.notifier).state = storage.getSession();
    if (mounted) context.go('/buyer/home');
  }
}
