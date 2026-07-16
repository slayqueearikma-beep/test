import 'package:flutter/material.dart';

import 'strings/app_strings.dart';

export 'strings/app_strings.dart';

class AppLocalizations {
  AppLocalizations(this.strings);

  final AppStrings strings;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static AppLocalizations get(BuildContext context) {
    final value = of(context);
    assert(value != null, 'AppLocalizations not found in context');
    return value!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const supportedLocales = [
    Locale('en'),
    Locale('fr'),
    Locale('ar'),
  ];
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppStrings.supportedLanguageCodes.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(AppStrings.forLocale(locale.languageCode));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => true;
}

extension AppLocalizationsX on BuildContext {
  AppStrings get l10n => AppLocalizations.get(this).strings;
}
