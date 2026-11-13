import 'package:flutter/widgets.dart';

import 'gen/app_localizations.dart';

export 'gen/app_localizations.dart' show S, lookupS;

/// UI strings for the current language, usable outside the widget tree (core error texts,
/// prompt titles). The app sets it from the resolved locale; widgets read it as `tr.key`.
S tr = lookupS(const Locale('en'));

/// The app speaks Vietnamese to Vietnamese phones and English to everyone else, unless the
/// user picked a language in Settings ([override]: 'vi', 'en' or null for the phone language).
Locale resolveLocale(List<Locale>? phone, String? override) {
  if (override == 'vi' || override == 'en') return Locale(override!);
  for (final l in phone ?? const <Locale>[]) {
    if (l.languageCode == 'vi') return const Locale('vi');
    if (l.languageCode == 'en') return const Locale('en');
  }
  return const Locale('en');
}

/// Language picked in Settings ('vi', 'en', or null = phone language). The app rebuilds on change.
final language = ValueNotifier<String?>(null);
