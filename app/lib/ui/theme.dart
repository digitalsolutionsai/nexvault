import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Tokens from docs/ui.md. Dark ground = high-risk moment; brass = brand + seal only.
class NV {
  /// The phone is in dark mode: the everyday (paper) screens use the night palette. The dark
  /// ground of high-risk screens (DarkZone) stays as it is, so it still stands out at night.
  static bool night = false;

  static Color get paper => night ? const Color(0xFF101716) : const Color(0xFFEDF0EE);
  static Color get surface => night ? const Color(0xFF1A2422) : const Color(0xFFF8F9F8);
  static Color get ink => night ? const Color(0xFFE6ECEA) : const Color(0xFF13252A);
  static Color get ink2 => night ? const Color(0xFF9FB0AC) : const Color(0xFF4F6267);
  static Color get line => night ? const Color(0xFF2C3A37) : const Color(0xFFD3DBD9);
  static Color get edge => night ? const Color(0xFF4D5F5B) : const Color(0xFF8FA19D);
  static Color get verdigris => night ? const Color(0xFF6FC2B0) : const Color(0xFF1F6B5E);
  static Color get warn => night ? const Color(0xFFE0A458) : const Color(0xFF94540A);
  static Color get danger => night ? const Color(0xFFF08A80) : const Color(0xFFA8302E);
  static Color get ok => night ? const Color(0xFF7CCB98) : const Color(0xFF2B7A4B);

  /// Text on a [verdigris] fill (filled buttons, "me" avatar).
  static Color get onVerdigris => night ? const Color(0xFF0E1A18) : Colors.white;

  /// Avatars and other soft fills on paper.
  static Color get tint => night ? const Color(0xFF24332F) : const Color(0xFFDCE5E2);

  /// QR codes stay dark on white in both modes: cameras read that best.
  static const qrInk = Color(0xFF13252A);
  static const qrPaper = Color(0xFFF8F9F8);

  static const ground = Color(0xFF173D3A);
  static const brass = Color(0xFFC8963A);
  // on dark ground
  static const dText = Color(0xFFE9EFEC);
  static const dSub = Color(0xFFA9C0BA);
  static const dOk = Color(0xFF8FD3A8);
  // "running" is blue, so it never reads as "done" (green) at a glance
  static const dRun = Color(0xFF8DBEF0);
  static const dWait = Color(0xFFA3B8B3);
  static const dBad = Color(0xFFF0A39A);
  static const dEdge = Color(0x80FFFFFF);

  static const sans = 'BeVietnamPro';
  static const mono = 'JetBrainsMono';

  static ThemeData light() => _theme(Brightness.light);
  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness b) {
    final dark = b == Brightness.dark; // the dark ground (DarkZone), not night mode
    if (!dark && night) b = Brightness.dark;
    final fg = dark ? dText : ink;
    final scheme = ColorScheme(
      brightness: b,
      primary: dark ? dText : verdigris,
      onPrimary: dark ? ground : onVerdigris,
      secondary: brass,
      onSecondary: const Color(0xFF13252A),
      // selected chips, tonal buttons: verdigris tint, never brass (brass = brand + seal only)
      secondaryContainer: dark ? const Color(0xFF2E625B) : (night ? const Color(0xFF1F3F39) : const Color(0xFFD3E7E1)),
      onSecondaryContainer: fg,
      error: dark ? dBad : danger,
      onError: dark || night ? const Color(0xFF13252A) : Colors.white,
      surface: dark ? ground : paper,
      onSurface: fg,
      surfaceContainerHighest: dark ? const Color(0xFF214B47) : surface,
      outline: dark ? dEdge : edge,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: sans, scaffoldBackgroundColor: scheme.surface);
    return base.copyWith(
      textTheme: base.textTheme
          .apply(bodyColor: fg, displayColor: fg)
          .copyWith(
            headlineSmall: TextStyle(fontFamily: sans, fontSize: 22, fontWeight: FontWeight.w700, color: fg, letterSpacing: -.2),
            titleMedium: TextStyle(fontFamily: sans, fontSize: 16, fontWeight: FontWeight.w600, color: fg),
            bodyMedium: TextStyle(fontFamily: sans, fontSize: 15, color: fg, height: 1.4),
            bodySmall: TextStyle(fontFamily: sans, fontSize: 13.5, color: dark ? dSub : ink2, height: 1.4),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontFamily: sans, fontSize: 20, fontWeight: FontWeight.w700, color: fg),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: sans, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: dark ? dText : verdigris,
          side: BorderSide(color: dark ? dEdge : edge, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: sans, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: dark ? dText : verdigris,
          textStyle: const TextStyle(fontFamily: sans, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0x14FFFFFF) : surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dark ? dEdge : line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dark ? dText : verdigris, width: 2),
        ),
        labelStyle: TextStyle(color: dark ? dSub : ink2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: night ? const Color(0xFF2A3836) : const Color(0xFF13252A)),
      dividerTheme: DividerThemeData(color: line, space: 1, thickness: 1),
      dialogTheme: DialogThemeData(
        titleTextStyle: TextStyle(fontFamily: sans, fontSize: 21, fontWeight: FontWeight.w700, color: fg, letterSpacing: -.2),
      ),
      chipTheme: ChipThemeData(
        labelStyle: TextStyle(fontFamily: sans, fontSize: 14, color: fg),
        side: BorderSide(color: dark ? dEdge : edge),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

String timeAgo(int? ms) {
  if (ms == null) return tr.timeNeverSynced;
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 2) return tr.timeJustNow;
  if (d.inHours < 1) return tr.timeMinutesAgo(d.inMinutes);
  if (d.inDays < 1) return tr.timeHoursAgo(d.inHours);
  if (d.inDays == 1) return tr.timeYesterday;
  return tr.timeDaysAgo(d.inDays);
}

String shortDate(int ms) {
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int n) => n.toString().padLeft(2, '0');
  final today = DateTime.now();
  final time = '${two(t.hour)}:${two(t.minute)}';
  if (t.year == today.year && t.month == today.month && t.day == today.day) return tr.timeToday(time);
  return '${two(t.day)}/${two(t.month)} $time';
}
