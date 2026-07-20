import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

class LanguageSettingsTile extends ConsumerWidget {
  const LanguageSettingsTile({super.key});

  String _languageLabel(AppStrings l10n, String code) {
    switch (code) {
      case 'fr':
        return '🇫🇷 ${l10n.french}';
      case 'ar':
        return '🇲🇦 ${l10n.arabic}';
      default:
        return '🇬🇧 ${l10n.english}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final code = Localizations.localeOf(context).languageCode;

    return ListTile(
      leading: const Icon(Icons.language_rounded, color: AppColors.primary),
      title: Text(l10n.language),
      subtitle: Text(_languageLabel(l10n, code)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push('/settings/language'),
    );
  }
}
