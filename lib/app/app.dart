import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/localization/app_strings.dart';
import '../features/onboarding/presentation/onboarding_flow.dart';
import 'theme/app_theme.dart';

class NijaApp extends StatefulWidget {
  const NijaApp({super.key});

  @override
  State<NijaApp> createState() => _NijaAppState();
}

class _NijaAppState extends State<NijaApp> {
  static const _themeModePrefsKey = 'nija_theme_mode_v1';

  String _languageMode = 'system';
  ThemeMode _themeMode = ThemeMode.system;

  Locale? get _forcedLocale => switch (_languageMode) {
    'en' => const Locale('en'),
    'es' => const Locale('es'),
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    _restoreThemeMode();
  }

  Future<void> _restoreThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themeModePrefsKey);
    final restored = _themeModeFromName(stored);
    if (!mounted || restored == _themeMode) return;
    setState(() => _themeMode = restored);
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModePrefsKey, mode.name);
  }

  ThemeMode _themeModeFromName(String? name) => switch (name) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  @override
  Widget build(BuildContext context) {
    final systemCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final activeCode =
        _forcedLocale?.languageCode ?? (systemCode == 'es' ? 'es' : 'en');
    AppStrings.setLanguageCode(activeCode);

    return MaterialApp(
      title: 'Nija',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      locale: _forcedLocale,
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('es')],
      localeResolutionCallback: (locale, supportedLocales) {
        final resolved = locale == null
            ? supportedLocales.first
            : supportedLocales.firstWhere(
                (item) => item.languageCode == locale.languageCode,
                orElse: () => supportedLocales.first,
              );
        return resolved;
      },
      home: OnboardingFlow(
        languageMode: _languageMode,
        onLanguageModeChanged: (mode) => setState(() => _languageMode = mode),
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}
