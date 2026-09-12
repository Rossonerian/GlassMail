# GlassMail

GlassMail is a local-first Android email client with Room-backed Compose inbox, reader, local search, settings, debug fixtures, checkpointed Gmail IMAP metadata sync, and experimental glass-quality chrome.

It is not production-ready. Live Gmail verification requires a dedicated Gmail test account and App Password, which are not stored in this repository.

## Terminal workflow

```bash
./gradlew build
./gradlew test
./gradlew lint
./gradlew :app:assembleDebug
./gradlew :app:installDebug
adb devices
adb logcat --pid="$(adb shell pidof com.glassmail.app)"
```

The debug APK is `app/build/outputs/apk/debug/app-debug.apk`.

See `MANUAL_TEST.md` for debug fixtures and Gmail validation. Device Macrobenchmarks are defined in `:benchmark`; no measurements are claimed without a device.
