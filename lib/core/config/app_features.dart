class AppFeatures {
  AppFeatures._();

  // Build-time flag:
  // flutter run --dart-define=NIJA_PAID_BUILD=true
  static const bool isPaidBuild = bool.fromEnvironment(
    'NIJA_PAID_BUILD',
    defaultValue: false,
  );

  static const String paidUnavailableLabel = 'Available in paid version';

  // Development override only. Production Android cloud backup should be
  // enabled through the runtime Google Play entitlement.
  static bool get supportsCloudBackup => isPaidBuild;

  static bool get supportsDebugInternals => isPaidBuild;

  static bool get supportsExpandedVaultStorage => isPaidBuild;
}
