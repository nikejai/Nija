class AppFeatures {
  AppFeatures._();

  // Build-time flag:
  // flutter run --dart-define=NIJA_PAID_BUILD=true
  static const bool isPaidBuild = bool.fromEnvironment(
    'NIJA_PAID_BUILD',
    defaultValue: false,
  );

  static const String paidUnavailableLabel = 'Available in paid version';

  // Cloud backup/restore is free while monetization is deferred.
  static bool get supportsCloudBackup => true;

  static bool get supportsDebugInternals => isPaidBuild;

  static bool get supportsExpandedVaultStorage => isPaidBuild;
}
