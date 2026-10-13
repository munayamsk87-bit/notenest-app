/// Static app metadata (Spec §12 "App version", §16 build info).
class AppInfo {
  AppInfo._();

  static const String name = 'NoteNest';
  static const String subtitle = 'Your little space for big ideas';
  static const String packageId = 'com.notenest.notes';
  static const String version = '1.0.0';
  static const String buildNumber = '1';
  static const String versionLabel = '$version+$buildNumber';
}
