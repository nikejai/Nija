class AppFeatures {
  AppFeatures._();

  // Build-time flag:
  // flutter run --dart-define=NIJA_PAID_BUILD=true
  static const bool isPaidBuild = bool.fromEnvironment(
    'NIJA_PAID_BUILD',
    defaultValue: false,
  );
}
