## 2024-05-30 - DateTimeFormatter Re-instantiation overhead
**Learning:** Instantiating `java.time.format.DateTimeFormatter` repeatedly inside a Compose list row's render path (or parsing loop) causes unnecessary GC pressure and CPU overhead. These formatters are thread-safe and immutable.
**Action:** Always extract `DateTimeFormatter.ofPattern` calls to top-level/static properties when used in frequently called methods like list rendering or data parsing.
## 2026-09-27 - Flutter version mismatches
**Learning:** CI was failing because the `setup-flutter` action was configured with a version (`3.47.5`) that was incompatible with the `pubspec.yaml` SDK constraints (`^3.13.4`).
**Action:** Always check `pubspec.yaml` for the `environment: sdk:` constraint before updating Flutter action versions in GitHub workflow files.
## 2026-09-27 - android-actions/setup-android deprecation
**Learning:** The GitHub action `android-actions/setup-android@v3` causes failures (`Failed to find package 'tools'` exit code 1) because the legacy tools package has been removed from recent Android SDKs.
**Action:** Remove `android-actions/setup-android@v3` from workflows entirely. GitHub's `ubuntu-latest` environment already comes pre-installed with the necessary Android SDK.
