/// App identity shared across the codebase.
class AppInfo {
  AppInfo._();

  /// Android application ID (Google Play package name). Must match
  /// `applicationId` in android/app/build.gradle.kts.
  static const androidAppId = 'com.gulflimousine.travel.app';
}
