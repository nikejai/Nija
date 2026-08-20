class GoogleOAuthConfig {
  GoogleOAuthConfig._();

  /// Public OAuth 2.0 web client ID (not a secret).
  ///
  /// Override at build/run time with:
  /// `--dart-define=NIJA_GOOGLE_WEB_CLIENT_ID=....apps.googleusercontent.com`
  static const String webClientId = String.fromEnvironment(
    'NIJA_GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '698262730675-ui2upcjqi4c3mpu8lm9ci3bv1okrbp2v.apps.googleusercontent.com',
  );

  /// Optional Web OAuth client id used as the native Google Sign-In
  /// `serverClientId` for Android/iOS Drive backup.
  ///
  /// Native Android sign-in still requires an Android OAuth client with package
  /// `com.nija` and the installed build's SHA-1 fingerprint.
  static const String nativeServerClientId = String.fromEnvironment(
    'NIJA_GOOGLE_NATIVE_SERVER_CLIENT_ID',
    defaultValue: '',
  );
}
