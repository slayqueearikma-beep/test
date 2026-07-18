import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_brand_logo.dart';
import '../../core/widgets/content_widgets.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/strings/app_strings.dart';

class OnboardingWelcomeScreen extends StatefulWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  State<OnboardingWelcomeScreen> createState() => _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState extends State<OnboardingWelcomeScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  List<_SlideData> _slides(AppStrings l10n) => [
        _SlideData(
          title: l10n.discoverTitle,
          subtitle: l10n.discoverSubtitle,
          backgroundColor: AppColors.illustrationBurgundy,
          icon: Icons.storefront_rounded,
        ),
        _SlideData(
          title: l10n.exploreMapTitle,
          subtitle: l10n.exploreMapSubtitle,
          backgroundColor: AppColors.illustrationGreen,
          icon: Icons.map_rounded,
        ),
        _SlideData(
          title: l10n.trustedReviewsTitle,
          subtitle: l10n.trustedReviewsSubtitle,
          backgroundColor: AppColors.illustrationOrange,
          icon: Icons.star_rounded,
        ),
      ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next(int slideCount) {
    if (_currentPage < slideCount - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    } else {
      context.push('/onboarding/account-type');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final slides = _slides(l10n);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: slides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (_, index) {
                  final slide = slides[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.lg,
                      AppSpacing.screenHorizontal,
                      0,
                    ),
                    child: Column(
                      children: [
                        OnboardingIllustration(
                          backgroundColor: slide.backgroundColor,
                          icon: slide.icon,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        if (index == 0) ...[
                          const AppBrandLogo(variant: AppBrandLogoVariant.full, width: 220),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          slide.subtitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            PageDots(count: slides.length, currentIndex: _currentPage),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
              child: PrimaryButton(
                label: _currentPage == slides.length - 1 ? l10n.getStarted : l10n.next,
                onPressed: () => _next(slides.length),
              ),
            ),
            LinkTextButton(label: l10n.login, onPressed: () => context.go('/login')),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _SlideData {
  const _SlideData({
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final Color backgroundColor;
  final IconData icon;
}
