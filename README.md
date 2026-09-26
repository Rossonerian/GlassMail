# GlassMail

GlassMail is a local-first Android email client for Gmail. It uses IMAP over TLS for mailbox sync and SMTP with STARTTLS for outgoing mail. Mail metadata, message bodies, drafts, and attachment cache are stored in a local Room database; account credentials are held by Android Keystore.

## v1 feature set

- Threaded inbox with Gmail categories, offline full-text search, and an immersive reader.
- Configurable short and long swipe actions, thread archive/mute/star/delete, and archive undo.
- Configurable undo-send window, local and Gmail Drafts synchronization, and Sent-folder filing.
- Newsletter unsubscribe for RFC 8058 one-click endpoints and `mailto:` links.
- Per-account body and attachment cache limits, storage quota display, and up to two accounts with a unified inbox.
- IMAP IDLE connection with an ongoing Android notification and 15-minute WorkManager sync fallback.
- HTML bodies are rendered in a restricted WebView. JavaScript, remote images, and link navigation are disabled; detectable tracking pixels are removed and counted.

The app does not include analytics or telemetry. Mail and credentials are sent only to the configured mail provider for sync and delivery. See [Privacy Policy](PRIVACY.md) and [Third-party notices](THIRD_PARTY_NOTICES.md).

## Build

Requirements: Android SDK 35 and JDK 17.

```bash
./gradlew :app:assembleDebug
```

The debug APK is `app/build/outputs/apk/debug/app-debug.apk`. To install on a connected device, run `./gradlew :app:installDebug`. Release builds use R8; distribution signing must be configured by the release owner and is intentionally not checked into this repository.

## Gmail setup

Connect a Gmail address with a Google App Password. App Passwords require two-step verification on the Google account. Credentials are not included in this repository or written to application logs. Use a dedicated test account during manual validation.

## Manual validation

See [MANUAL_TEST.md](MANUAL_TEST.md) for the device workflow and [FUNCTIONAL_STATUS.md](FUNCTIONAL_STATUS.md) for current implementation and verification status. The live IMAP/SMTP flows, IDLE behavior, and device-specific glass performance still require phone verification; no device measurements are claimed here.

## License

GlassMail is distributed under the Apache License 2.0. See [LICENSE](LICENSE).
