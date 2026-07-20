import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_storage.dart';
import '../../core/services/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_logo_placeholder.dart';
import '../../l10n/app_localizations.dart';

class LanguageOption {
  const LanguageOption({
    required this.code,
    required this.flag,
    required this.label,
  });

  final String code;
  final String flag;
  final String label;
}

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key, this.fromSettings = false});

  final bool fromSettings;

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  String _selected = 'en';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selected = ref.read(appStorageProvider)?.languageCode ?? _selected;
  }

  List<LanguageOption> _options(AppStrings l10n) => [
        LanguageOption(code: 'en', flag: '🇬🇧', label: l10n.english),
        LanguageOption(code: 'fr', flag: '🇫🇷', label: l10n.french),
        LanguageOption(code: 'ar', flag: '🇲🇦', label: l10n.arabic),
      ];

  Future<void> _applyLanguage(String code) async {
    final storage = ref.read(appStorageProvider);
    if (storage == null) return;

    await ref.read(localeProvider.notifier).setLanguage(code);
    setState(() => _selected = code);

    if (widget.fromSettings) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
  }

  Future<void> _continue() async {
    await _applyLanguage(_selected);
    if (!mounted || widget.fromSettings) return;
    context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.fromSettings)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.fromSettings)
                      const SizedBox(height: AppSpacing.md),
                    const Center(
                        child: AppBrandLogo(
                            variant: AppBrandLogoVariant.full, width: 200)),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.selectLanguage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.selectLanguageSubtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    ..._options(l10n).map((option) => _LanguageCard(
                          flag: option.flag,
                          label: option.label,
                          selected: _selected == option.code,
                          onTap: () {
                            if (widget.fromSettings) {
                              _applyLanguage(option.code);
                            } else {
                              setState(() => _selected = option.code);
                            }
                          },
                        )),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
            if (!widget.fromSettings)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.sm,
                  AppSpacing.screenHorizontal,
                  AppSpacing.lg,
                ),
                child: PrimaryButton(
                    label: l10n.continueLabel, onPressed: _continue),
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.flag,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String flag;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: selected
            ? (isDark
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.cardSelected)
            : (isDark ? AppColors.darkCard : AppColors.cardUnselected),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : (isDark ? AppColors.darkBorder : AppColors.border),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border,
                        width: 2),
                    color: selected ? AppColors.primary : Colors.transparent,
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
