# Flutter dependency and toolchain license inventory

Initial inventory recorded 2026-09-26 and updated 2026-09-27 from `pubspec.lock` and the generated Android host. Re-audit whenever a runtime package, platform plugin, native SDK, icon/font asset or CI action changes.

## App and workspace runtime

| Dependency | Version | License | Scope |
| --- | --- | --- | --- |
| Flutter SDK and engine (`flutter`, `sky_engine`) | 3.47.5 / Dart 3.13.4 | BSD-3-Clause | App runtime; Material icons are bundled from the SDK |
| `glassmail_core_model`, `glassmail_domain_mail` | 0.1.0 | Apache-2.0 | First-party workspace packages |
| `flutter_riverpod` / `riverpod` | 3.4.3 | MIT | Repository provider and app dependency composition |
| `state_notifier` | 1.0.0 | MIT | Riverpod state runtime dependency |
| `drift` | 2.35.0 | MIT | Typed SQLite schema and persistence runtime in `core_database` |
| `drift_flutter` | 0.3.1 | MIT | Flutter database connection in `core_database` |
| `path_provider` | 2.1.6 | BSD-3-Clause | Application-support directory for the local database |
| `sqlite3` | 3.5.2 | MIT | Dart SQLite wrapper; uses the pinned SQLite amalgamation below |
| `flutter_secure_storage_darwin` | 0.4.3 | BSD-3-Clause | iOS/macOS Keychain platform implementation |
| `flutter_secure_storage_linux` | 3.0.3 | BSD-3-Clause | Linux keyring implementation resolved by plugin; not a mobile release target |
| `flutter_secure_storage_platform_interface` | 2.1.1 | BSD-3-Clause | Plugin platform interface |
| `flutter_secure_storage_web` | 2.1.1 | BSD-3-Clause | Web implementation resolved by plugin; not a mobile release target |
| `flutter_secure_storage_windows` | 4.2.2 | BSD-3-Clause | Windows implementation resolved by plugin; not a mobile release target |
| `flutter_secure_storage` | 11.2.0 | BSD-3-Clause | Android Keystore-wrapped AES-GCM storage and iOS Keychain adapter in `core_security` |
| `flutter_local_notifications` | 22.3.1 | BSD-3-Clause | New-mail notification adapter; permissions are requested from explicit UI |
| `flutter_contacts` | 2.5.0 | MIT | User-invoked native contact picker for sender display profiles |
| `home_widget` | 0.10.0 | BSD-3-Clause | Android and iOS home-screen widget data/update bridge |
| `cryptography` | 2.9.0 | Apache-2.0 | Authenticated encrypted backup format and key derivation |
| `cryptography_flutter` | 2.3.4 | Apache-2.0 | Native crypto implementation used by encrypted backups |
| `workmanager` | 0.10.10 | MIT | Flutter API for Android WorkManager and iOS background refresh |
| `liquid_glass_widgets` | 1.7.2 | MIT | GlassMail-owned renderer adapter for clipped navigation chrome; package's in-tree engine attribution and MIT notices are included in Flutter's generated license bundle |
| `workmanager_android` | 0.10.9 | MIT | Native Android WorkManager implementation |
| `workmanager_apple` | 0.9.11 | MIT | Native iOS BGTaskScheduler/background refresh implementation |
| `workmanager_platform_interface` | 0.10.5 | MIT | WorkManager method-channel API contract |
| `file_selector` | 1.1.0 | BSD-3-Clause | Native Android/iOS file selection for outgoing mail attachments |
| `file_selector_android` | 0.5.2+11 | Apache-2.0, BSD-3-Clause | Android file selection implementation |
| `file_selector_ios` | 0.5.3+6 | BSD-3-Clause | iOS document picker implementation |
| `file_selector_platform_interface` | 2.7.0 | BSD-3-Clause | File selection platform contract |
| `share_plus` | 13.3.0 | BSD-3-Clause | Native Android/iOS share sheet for downloaded mail attachments |
| `share_plus_platform_interface` | 7.2.0 | BSD-3-Clause | Share-sheet platform contract |
| `cross_file` | 0.3.5+5 | BSD-3-Clause | Cross-platform file stream and metadata used by picker/share plugins |
| `url_launcher` / Android / iOS | 6.3.2 / 6.3.33 / 6.4.2 | BSD-3-Clause | Opens message links in the system browser after explicit confirmation |
| `quick_actions` / Android / iOS | 1.1.1 / 1.0.33 / 1.2.5 | BSD-3-Clause | Compose, Inbox and Search launcher shortcuts |
| `flutter_timezone` | 5.1.0 | Apache-2.0 | Reads the native IANA timezone for scheduled reminders |
| `timezone` | 0.11.1 | BSD-2-Clause | Timezone-aware reminder scheduling and current IANA database |

`core_database` contains the v10 schema and DAO operations and is opened by the Flutter development host. `core_security` uses `flutter_secure_storage` 11.2.0. `core_imap` is app-owned Dart code; `enough_mail` 2.1.7 was evaluated but is not a runtime dependency. `drift_flutter` currently resolves the legacy `sqlite3_flutter_libs` and `sqlcipher_flutter_libs` compatibility packages; the active SQLite implementation is supplied by the `sqlite3` v3 build hook and the workspace's custom-source configuration. Desktop/web federated plugin packages are lockfile-resolved but are not release targets.

`liquid_glass_widgets` 1.7.2 declares Flutter `>=3.41.0` / Dart `>=3.5.0`, supports Android and iOS, has no non-SDK runtime dependencies, and is MIT licensed. Its engine attribution identifies the in-tree rendering base as derived from `liquid_glass_renderer` v0.2.0-dev.4 by Tim Lehmann (MIT). GlassMail maps `FULL` to the package's `premium`, `BALANCED` to `standard`, and `LIGHT` to `minimal`; `OFF` and explicit reduce-transparency/high-contrast requests use GlassMail's opaque fallback. This is an app-owned adapter; it does not claim parity with Compose's `GraphicsLayer.record` sampling.

## Vendored native source

| Source | Version | License | Scope |
| --- | --- | --- | --- |
| SQLite amalgamation (`sqlite3.c`, `sqlite3.h`) | 3.53.4 | Public domain | Compiled by the `sqlite3` build hook with `SQLITE_ENABLE_FTS4`; official download URL and SHA3-256 are recorded in `third_party/sqlite/3.53.4/README.md` |

## Locked development dependencies

These packages are pulled by `flutter_test` or `flutter_lints` and are not app runtime dependencies.

| Package | Version | License |
| --- | --- | --- |
| `async` | 2.13.1 | BSD-3-Clause |
| `boolean_selector` | 2.1.2 | BSD-3-Clause |
| `characters` | 1.4.1 | BSD-3-Clause |
| `clock` | 1.1.3 | Apache-2.0 |
| `collection` | 1.19.1 | BSD-3-Clause |
| `fake_async` | 1.3.3 | Apache-2.0 |
| `flutter_lints` | 6.0.0 | BSD-3-Clause |
| `lints` | 6.1.0 | BSD-3-Clause |
| `leak_tracker` | 11.0.2 | BSD-3-Clause |
| `leak_tracker_flutter_testing` | 3.0.10 | BSD-3-Clause |
| `leak_tracker_testing` | 3.0.2 | BSD-3-Clause |
| `matcher` | 0.12.20 | BSD-3-Clause |
| `material_color_utilities` | 0.13.0 | Apache-2.0 |
| `meta` | 1.18.3 | BSD-3-Clause |
| `path` | 1.9.1 | BSD-3-Clause |
| `source_span` | 1.10.2 | BSD-3-Clause |
| `stack_trace` | 1.12.2 | BSD-3-Clause |
| `stream_channel` | 2.1.4 | BSD-3-Clause |
| `string_scanner` | 1.4.1 | BSD-3-Clause |
| `term_glyph` | 1.2.2 | BSD-3-Clause |
| `test_api` | 0.7.12 | BSD-3-Clause |
| `vector_math` | 2.4.0 | BSD-3-Clause |
| `vm_service` | 15.3.0 | BSD-3-Clause |
| `flutter`, `flutter_test` | 3.47.5 SDK | BSD-3-Clause | Flutter SDK packages, used by app and tests respectively |

## Build and CI tools

| Tool | Version | License | Scope |
| --- | --- | --- | --- |
| Flutter Gradle plugin | Bundled with Flutter 3.47.5 | BSD-3-Clause | Android host build |
| Android Gradle Plugin | 9.1.0 | Apache-2.0 | Android host build |
| Kotlin Android Gradle plugin | 2.4.0 | Apache-2.0 | Android host build |
| Gradle wrapper | 9.3.1 | Apache-2.0 | Android host build |
| Android NDK | 28.2.13676358 | Android SDK component license | Local native toolchain; not a Dart app dependency |
| Android Build Tools | 36.0.0 | Android SDK component license | Local native toolchain; not a Dart app dependency |
| Android CMake | 3.22.1 | Android SDK component license | Local native toolchain; not a Dart app dependency |
| `flutter-actions/setup-flutter` | v4.2 | MIT | GitHub Actions only |
| `android-actions/setup-android` | v3 | Apache-2.0 | GitHub Actions only; used in the Android workflow |
| `build_runner` | 2.16.1 | BSD-3-Clause | Drift code generation |
| `drift_dev` | 2.35.0 | MIT | Drift schema analysis and code generation |

Android SDK license acceptance remains a machine-level concern. `flutter doctor -v` still reports that some Android SDK licenses are not accepted; the local release bundle nevertheless built and passed Flutter's symbol inspection after command-line tools were installed. No remaining SDK license was accepted manually as part of this change.
