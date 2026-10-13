# Building NoteNest

This document is the exact, ordered set of steps to produce the release APK/AAB.
NoteNest was authored in an environment **without** the Flutter/Android toolchain,
so the build must be run where that toolchain exists (see "Why no APK ships in
this repo" at the end).

---

## 1. Prerequisites

| Tool | Version used / recommended |
|---|---|
| Flutter SDK | 3.22 – 3.24 (stable channel) |
| Dart | 3.4+ (bundled with Flutter) |
| JDK | **17** (required by AGP 8.x / Gradle 8.x) |
| Android SDK Platform | API 34 (`compileSdk`/`targetSdk` = 34) |
| Android Build-Tools | 34.0.0 |
| Android SDK Platform-Tools | any recent |
| Gradle | supplied by the Flutter wrapper (8.x) |

Install via Android Studio (SDK Manager) or the command-line tools, then:

```bash
flutter doctor        # resolve every red item before continuing
```

Accept licences if prompted:

```bash
flutter doctor --android-licenses
```

---

## 2. Configure the project

From the project root:

```bash
flutter pub get
```

Create `android/local.properties` (Flutter usually writes this for you; if not):

```properties
sdk.dir=/absolute/path/to/Android/sdk
flutter.sdk=/absolute/path/to/flutter
```

### App icon (optional regeneration)

The launcher icon is committed under `assets/icon/`. To regenerate the Android
mipmaps from it:

```bash
dart run flutter_launcher_icons
```

---

## 3. Static checks and tests

```bash
dart format --set-exit-if-changed lib test   # formatting
flutter analyze                              # static analysis
flutter test                                 # unit tests in test/
```

Fix anything `analyze` reports before building.

---

## 4. Release signing

Release builds read signing config from `android/key.properties` (which is
**git-ignored** — never commit real secrets).

1. Create a keystore:

   ```bash
   keytool -genkey -v -keystore ~/notenest-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias notenest
   ```

2. Copy `android/key.properties.example` to `android/key.properties` and fill it:

   ```properties
   storePassword=********
   keyPassword=********
   keyAlias=notenest
   storeFile=/absolute/path/to/notenest-release.jks
   ```

If `key.properties` is absent, the release build falls back to the **debug**
signing config so `flutter build apk --release` still works for local testing —
but such an APK is **not** suitable for distribution.

---

## 5. Build the artifacts

```bash
# APK
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk

# App Bundle (Play Store)
flutter build appbundle --release
# -> build/app/outputs/bundle/release/app-release.aab

# Per-ABI APKs (smaller downloads), optional
flutter build apk --split-per-abi --release
```

---

## 6. Install and verify

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Then walk the manual QA checklist in `README.md` (§ "Manual QA checklist").

Sanity-check the artifact is real and non-empty:

```bash
ls -lh build/app/outputs/flutter-apk/app-release.apk
unzip -l build/app/outputs/flutter-apk/app-release.apk | head
```

---

## 7. Troubleshooting

| Symptom | Fix |
|---|---|
| `Unsupported class file major version` / Kotlin/Java errors | Use **JDK 17** (`flutter config --jdk-dir <path>`). |
| `Could not find com.android.tools.build:gradle` | Ensure `google()` + `mavenCentral()` repos are reachable; check `android/settings.gradle`. |
| `minSdkVersion 23 ... required by mlkit` | Already set to 23; keep it. |
| Exact-alarm reminders fire late | On Android 12+ grant "Alarms & reminders" for NoteNest; the app falls back to inexact scheduling otherwise and says so. |
| Notifications silent | Grant the notification permission (Settings → Notifications in-app, or the OS prompt). |
| `Execution failed for task ':app:minifyReleaseWithR8'` | Adjust `android/app/proguard-rules.pro`; keep-rules for ML Kit and `flutter_local_notifications` are already included. |
| Build OOMs on a small machine | Lower `org.gradle.jvmargs` in `android/gradle.properties` (e.g. `-Xmx1536M`) or build with `--split-per-abi`. |

---

## 8. Why no APK ships in this repository

The environment this project was written in had **no Flutter, Dart, JDK, Android
SDK or Gradle**, `apt` installs were blocked, RAM was ~2 GB (a per-process cap of
~1.5 GB), and background jobs were disallowed. A Gradle/AGP release build needs
more headroom than that, and the full toolchain could not be fetched and run
within the execution limits.

Per the spec's section 16, that case is handled by delivering **the complete
source project plus these exact remaining build steps** rather than claiming an
APK that was never produced. Running sections 1–6 above on a normal Android
development machine yields `app-release.apk`.
