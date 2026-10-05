# GlassMail CI failure report

Status: workflow fixes prepared locally at HEAD `6c3babc`; hosted green runs have
not been verified. No commit or push was performed.

## Reported failures

The supervisor verified failures in runs `36469865609`, `36469865596`, and
`36469865566`:

- `android.yml` / `assemble`: `android-actions/setup-android@v3` requested the
  obsolete Android SDK package `tools`.
- `flutter.yml` / `android`: the same SDK setup failure.
- `flutter.yml` / `ios-simulator`: `flutter-actions/setup-flutter@v4.2` failed
  extracting its archive.
- `flutter_ci.yml`: the same SDK setup failure on macOS.

These jobs had not reached application builds or tests. The previous report's
claims that iOS succeeded and that pinning command-line tools made all workflows
green were incorrect. Raw run logs were not independently retrieved here:
`gh api` could not connect to `api.github.com` in this environment.

## Changes and verified toolchain requirements

Native Kotlin (`com.glassmail.app`) remains the canonical v1 product.
`android.yml` uses Ubuntu 24.04, Temurin JDK 17, and
`gradle/actions/setup-gradle@v4`. It runs unit tests, `lintDebug`, release assembly
with R8 enabled by the existing app configuration, and debug assembly. Every
Gradle command explicitly uses `--max-workers=2 --no-parallel`. The unsigned
native release is a compile check only; no artifact upload or publishing exists.

Flutter (`com.glassmail.dev.glassmail`) remains experimental. The duplicate
`flutter_ci.yml` was deleted. Both jobs in `flutter.yml` use
`subosito/flutter-action@v2` with exact stable Flutter `3.47.5` and caching. All
existing formatting, analysis, package generation, and package test commands are
retained. Android builds a release app bundle; macOS builds an unsigned iOS
simulator application.

The Flutter release signing configuration does **not** fall back to debug
signing: it selects a release config even when credentials are absent. The
Android workflow therefore generates a disposable CI keystore in `RUNNER_TEMP`
and supplies the existing signing environment variables only to the build step.
It uses no production credentials and uploads no bundle. Gradle files were not
changed.

Both workflows have read-only contents permissions, cancellation of superseded
runs, and 45-minute job timeouts. `gradle.properties`, all app sources, and
user-owned untracked files were untouched.

Sources checked on 2026-10-05:

- [Ubuntu 24.04 runner inventory](https://raw.githubusercontent.com/actions/runner-images/main/images/ubuntu/Ubuntu2404-Readme.md)
  (image `20260927.320.1`) includes platforms 35 and 36 and Build Tools 34.0.0
  and 36.0.0. Android SDK setup actions are unnecessary.
- [AGP 8.7 compatibility](https://developer.android.com/build/releases/agp-8-7-0-release-notes):
  native AGP 8.7.3 defaults to Build Tools 34.0.0, requires Gradle 8.9 and JDK 17,
  and supports the repository's compileSdk 35.
- [AGP 9.1 compatibility](https://developer.android.com/build/releases/agp-9-1-0-release-notes):
  Flutter's AGP 9.1.0 uses Build Tools 36.0.0, Gradle 9.3.1, and JDK 17.
  Flutter's app explicitly compiles against SDK 36.
- [Flutter 3.47.5 tag engine file](https://raw.githubusercontent.com/flutter/flutter/3.47.5/bin/internal/engine.version)
  verifies the documented tag exists. Its
  [DEPS file](https://raw.githubusercontent.com/flutter/flutter/3.47.5/DEPS)
  pins Dart revision `b530c21f7de367b94fb04787bfed9d8e989d75e8`; that revision's
  [VERSION file](https://raw.githubusercontent.com/dart-lang/sdk/b530c21f7de367b94fb04787bfed9d8e989d75e8/tools/VERSION)
  confirms stable Dart 3.13.4, satisfying `flutter_app/pubspec.yaml`'s `^3.13.4`.
  Local cached SDK metadata independently reports the same versions. No fallback
  version was needed.
- [Flutter action documentation](https://github.com/subosito/flutter-action)
  documents exact-version selection and SDK caching on Linux and macOS.

## Local checks

1. `python3 -c 'import pathlib,yaml; [yaml.safe_load(p.read_text()) for p in pathlib.Path(".github/workflows").glob("*.yml")]; print("All workflows: valid YAML")'`
   — exit 0; both remaining workflows parse successfully. Additional structural
   assertions verified contents permissions and positive timeouts for every job.
   `actionlint` is not installed.
2. `./gradlew --max-workers=2 --no-parallel --priority=low test lintDebug :app:assembleDebug`
   — run exactly once, exit 1 before Gradle configuration or task execution.
   The wrapper could not write
   `/home/rosso/.gradle/wrapper/dists/gradle-8.9-bin/90cnw93cvbtalezasaz0blq0a/gradle-8.9-bin.zip.lck`
   (`Read-only file system`). No Gradle runs overlapped. Unit tests, lint, and
   assembly results are unverified; task discovery was also blocked.
3. `flutter --version` — exit 1; the installed SDK tried to write
   `engine.stamp.tmp.47` and `engine.realm` inside its read-only cache.
   No Flutter analysis, tests, or builds were run locally.
4. `keytool -genkeypair -noprompt -keystore /tmp/glassmail-ci-signing-test.jks -storetype JKS -storepass android -keypass android -alias ci -keyalg RSA -keysize 2048 -validity 1 -dname 'CN=GlassMail CI'`
   — exit 0; temporary key generation succeeds with local JDK 17.
5. `git diff --check` — exit 0.

## Remaining verification

The setup failures have been addressed in configuration, but no hosted execution
of the revised workflows has occurred. Latent lint, code, test, dependency,
shrinker, signing integration, and iOS build failures remain unverified. No
failure was suppressed and no tests were skipped.

The supervisor should review and commit these changes, then run both workflows
on GitHub and inspect every job through completion. Any source-level failures
need a separately authorized fix; workflow green status must be based on those
new run results.
