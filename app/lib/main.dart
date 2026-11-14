import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/keys.dart';
import 'l10n/l10n.dart';
import 'screens/auth.dart';
import 'screens/home.dart';
import 'screens/intro.dart';
import 'screens/scan.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

final navKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NexVaultApp());
}

class NexVaultApp extends StatefulWidget {
  const NexVaultApp({super.key});
  @override
  State<NexVaultApp> createState() => _NexVaultAppState();
}

class _NexVaultAppState extends State<NexVaultApp> with WidgetsBindingObserver {
  bool unlocked = false;
  bool? setUp;
  bool intro = true; // first launch: the three intro pages before setup
  String? pendingLink;
  DateTime? pausedAt;
  bool pausedForSystem = false; // a picker / system screen the user opened from the app

  /// Lock when the app has been in the background longer than this (Settings > Tự khoá).
  Duration autoLock = const Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Keys.isSetUp().then((v) => setState(() => setUp = v));
    Keys.autoLockSeconds().then((v) => autoLock = Duration(seconds: v));
    Keys.language().then((l) => language.value = l);
    language.addListener(_relocalize);
    Keys.initialLink().then((l) => pendingLink = l);
    Keys.onLink((l) {
      if (unlocked) {
        openLink(navKey.currentContext!, l);
      } else {
        pendingLink = l;
      }
    });
  }

  void _relocalize() => setState(() {});

  @override
  void didChangeLocales(List<Locale>? locales) => _relocalize();

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      pausedAt = DateTime.now();
      pausedForSystem = Keys.prompting;
    }
    if (s == AppLifecycleState.paused) Keys.autoLockSeconds().then((v) => autoLock = Duration(seconds: v));
    if (s != AppLifecycleState.resumed) return;
    // Consume the pause timestamp on every resume. Otherwise the old timestamp survives the
    // lock: the fingerprint dialog only makes the app "inactive", so after a successful scan
    // the app resumes, sees the stale timestamp, locks again and re-prompts (a flicker loop).
    final p = pausedAt;
    pausedAt = null;
    // auth prompts, file pickers and system settings opened from the app do not count as leaving
    // it, but still lock if the user wanders off for longer than 5 minutes
    final limit = pausedForSystem ? const Duration(minutes: 5) : autoLock;
    if (unlocked && p != null && DateTime.now().difference(p) >= limit) {
      Keys.lock();
      setState(() => unlocked = false);
      navKey.currentState?.popUntil((r) => r.isFirst);
    }
  }

  void _unlocked() {
    setState(() {
      unlocked = true;
      setUp = true;
    });
    final l = pendingLink;
    pendingLink = null;
    if (l != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => openLink(navKey.currentContext!, l));
    }
  }

  bool? _phone;
  Locale? _lastLocale;

  @override
  void didChangeMetrics() {
    if (_phone == null) setState(() {});
  }

  /// Phones stay in portrait; tablets (iPad, Android tablets) rotate freely. Decided once the
  /// first real window size is known (it can be zero before the first frame on iOS).
  void _orientation(BuildContext context) {
    if (_phone != null) return;
    final v = View.of(context);
    final shortest = v.physicalSize.shortestSide / v.devicePixelRatio;
    if (shortest == 0) return;
    _phone = shortest < 600;
    SystemChrome.setPreferredOrientations(_phone! ? [DeviceOrientation.portraitUp] : []);
  }

  @override
  Widget build(BuildContext context) {
    _orientation(context);
    Widget home;
    if (setUp == null) {
      home = const Scaffold(backgroundColor: NV.ground);
    } else if (!unlocked) {
      home = setUp!
          ? UnlockScreen(onUnlocked: _unlocked)
          : intro
          ? IntroScreen(onDone: () => setState(() => intro = false))
          : OnboardingScreen(onDone: _unlocked);
    } else {
      home = HomeScreen(
        onWiped: () {
          navKey.currentState?.popUntil((r) => r.isFirst);
          setState(() {
            unlocked = false;
            setUp = false;
            intro = false; // they know the app already
          });
        },
        onLock: () async {
          await Keys.lock();
          setState(() => unlocked = false);
        },
      );
    }
    final locale = resolveLocale(WidgetsBinding.instance.platformDispatcher.locales, language.value);
    if (locale != _lastLocale) {
      _lastLocale = locale;
      tr = lookupS(locale);
      Keys.setNativeLabels();
    }
    return MaterialApp(
      title: 'NexVault',
      locale: locale,
      supportedLocales: S.supportedLocales,
      localizationsDelegates: S.localizationsDelegates,
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      theme: NV.light(),
      builder: (context, child) => WideFrame(child: child!),
      home: home,
    );
  }
}
