# Release signing

The release build uses R8. Signing keys are supplied by the release owner and must never be checked in.

Set these environment variables locally or in a protected release environment:

- `GLASSMAIL_RELEASE_STORE_FILE`
- `GLASSMAIL_RELEASE_STORE_PASSWORD`
- `GLASSMAIL_RELEASE_KEY_ALIAS`
- `GLASSMAIL_RELEASE_KEY_PASSWORD`

Then build with `./gradlew :app:assembleRelease`. Without those values Gradle produces an unsigned release APK. F-Droid should build from source and apply its own signing key; do not publish the unsigned APK as an installable release.
