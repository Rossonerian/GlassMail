# GlassMail

GlassMail is a local-first Android email client for Gmail. Native Kotlin (`com.glassmail.app`, v1.0.0, Android SDK 34–35) is the canonical v1 application; `flutter_app/` remains experimental. It uses IMAP over TLS for mailbox sync and SMTP with STARTTLS for outgoing mail. Mail metadata, message bodies, drafts, and attachment cache are stored in a local Room database; account credentials are held by Android Keystore.

## v1 feature set & hardening

- **Inbox & multi-message reader**: Threaded inbox with Gmail categories, offline full-text search, expandable thread reader with per-message attachments and labels, and Reader archive/delete back navigation with archive undo.
- **Swipe actions, drafts & send reliability**: Configurable short and long swipe actions, configurable 5/10/15/30-second undo-send window, serialized send/autosave/undo handling in `ComposeViewModel`, bounded remote draft sync retries (max 5 transport attempts), Sent-folder filing, and post-SMTP cancellation protection.
- **Transport, protocol & credential security**: TLS 1.2/1.3 floor with RFC 2818 hostname verification on both IMAP (TLS) and SMTP (`STARTTLS`), SMTP CR/LF/NUL header-injection rejection, unified cancellable IMAP connections, multi-line `SEARCH` and unsolicited `FETCH` handling, `1.MIME` fallback, `UIDVALIDITY` guards, RFC 2231 / split-UTF-8 RFC 2047 / single-pass HTML entity decoding with bounded MIME depth, and `AndroidKeystoreCredentialStore` concurrency locking, `Dispatchers.IO` offloading, corruption handling, and `CharArray`/`ByteArray` zeroing without heap `String` copies.
- **Restricted HTML WebView**: JavaScript, network loads, remote images, file/content access, and DOM storage are disabled, with CSP (`base-uri 'none'; form-action 'none';`), `<meta>`/`<svg>`/non-allowlisted `data:` URI stripping, a 6 MiB inline `cid:` expansion cap, WebView disposal cleanup, and blocking of zero-click, subframe, and redirect navigations (explicit user-tapped main-frame links open externally).
- **Sync, memory & debug gating**: IMAP IDLE foreground service with Android 15 `dataSync` `onTimeout` handling and 15-minute WorkManager fallback, per-account cache caps and offline cached attachment reads with path confinement, restricted RAM mode with `onTrimMemory`/`onLowMemory` trimming, up to two accounts with a unified inbox, RFC 8058 / `mailto:` unsubscribe, and `BuildConfig.DEBUG`-gated fixture seeding and Optical Lab UI (hidden in release builds).

The app does not include analytics or telemetry. Mail and credentials are sent only to the configured mail provider for sync and delivery. See [Privacy Policy](PRIVACY.md), [Functional Status](FUNCTIONAL_STATUS.md), and [Third-party notices](THIRD_PARTY_NOTICES.md).

## Build

Requirements: Android SDK 35 and JDK 17.

```bash
./gradlew :app:assembleDebug
```

The debug APK is `app/build/outputs/apk/debug/app-debug.apk`. To install on a connected device, run `./gradlew :app:installDebug`. Release builds use R8 (`versionCode 10000`, `versionName "1.0.0"`); distribution signing must be configured by the release owner via `GLASSMAIL_RELEASE_*` environment variables / Gradle properties (`GLASSMAIL_REQUIRE_RELEASE_SIGNING=true` enforces failure if absent) and is intentionally not checked into this repository.

## Flutter migration host (experimental)

The parallel experimental Flutter host is in `flutter_app/`. It uses a separate `com.glassmail.dev.glassmail` development identity and starts with an empty local cache. It does not import existing Room data or credentials; keep the Kotlin app as the canonical v1 reference. See the [Flutter port matrix](docs/flutter/PORT_MATRIX.md) and [migration decisions](docs/flutter/DECISIONS.md) if working on the experimental track, or `flutter_app/README.md` for build instructions.

## Gmail setup

Connect a Gmail address with a Google App Password. App Passwords require two-step verification on the Google account. Credentials are not included in this repository or written to application logs. Use a dedicated test account during manual validation.

## Manual validation & verification status

See [MANUAL_TEST.md](MANUAL_TEST.md) for the planned device workflow and [FUNCTIONAL_STATUS.md](FUNCTIONAL_STATUS.md) for the full implementation vs. verification matrix.

Currently **unverified / pending device and live QA**:
- Live Gmail acceptance (real Gmail IMAP/SMTP send/receive, Sent APPEND, remote Drafts sync, one-click unsubscribe, quota responses, IDLE push timing/reconnect, and two-account live operation).
- Device WebView sizing/rendering (`INT-4`), physical glass rendering, rotation, and process-death recovery on hardware.
- Pixel 9a connected/instrumented test suites (`:core:security:connectedDebugAndroidTest`, `:core:database:connectedCheck`, `:sync:connectedCheck`) and Macrobenchmark runs.

No live Gmail, Pixel 9a instrumented, or device performance results are claimed until executed against a dedicated account and attached device.

## License

GlassMail is distributed under the Apache License 2.0. See [LICENSE](LICENSE).
