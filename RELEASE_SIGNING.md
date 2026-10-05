# Release signing

The canonical v1 release is the native Kotlin app, applicationId `com.glassmail.app`.
`flutter_app/` is experimental and is excluded from release artifacts. Release builds use R8.
Never commit signing keys or passwords, and never publish unsigned APKs.

## Create and protect the keystore

Run locally, replacing placeholders. Let keytool prompt for passwords rather than
putting them in shell history. Keep secure backups of the keystore and credentials;
future updates must retain the same signing identity.

```bash
keytool -genkeypair -v -keystore /PRIVATE/PATH/glassmail-release.jks \
  -storetype JKS -alias RELEASE_KEY_ALIAS -keyalg RSA -keysize 4096 \
  -validity 10000 -dname "CN=RELEASE_OWNER, O=ORGANIZATION, C=COUNTRY_CODE"
```

## Local signing inputs

Provide all four environment variables or corresponding Gradle properties:

| Environment variable | Gradle property |
| --- | --- |
| `GLASSMAIL_RELEASE_STORE_FILE` | `glassmailReleaseStoreFile` |
| `GLASSMAIL_RELEASE_STORE_PASSWORD` | `glassmailReleaseStorePassword` |
| `GLASSMAIL_RELEASE_KEY_ALIAS` | `glassmailReleaseKeyAlias` |
| `GLASSMAIL_RELEASE_KEY_PASSWORD` | `glassmailReleaseKeyPassword` |

Environment values take precedence. Store passwords outside the repository.
Without complete inputs, the default local release build is unsigned.
Opt into strict signing for release artifact tasks:

```bash
GLASSMAIL_REQUIRE_RELEASE_SIGNING=true ./gradlew :app:assembleRelease :app:bundleRelease
# Alternatively, with signing inputs supplied:
./gradlew -PglassmailRequireReleaseSigning=true :app:assembleRelease :app:bundleRelease
```

Strict mode fails when signing inputs are incomplete and a native release artifact
assembly, bundle, packaging, signing, or signing-validation task is in the graph.
Tests, lint, and debug assembly alone do not require signing credentials. Invalid
keystores or credentials still fail Android's signing validation.

## GitHub Actions secrets

Configure these four repository or organization secrets:

- `GLASSMAIL_RELEASE_KEYSTORE_BASE64`: base64 contents of the keystore.
- `GLASSMAIL_RELEASE_STORE_PASSWORD`: keystore password.
- `GLASSMAIL_RELEASE_KEY_ALIAS`: signing alias.
- `GLASSMAIL_RELEASE_KEY_PASSWORD`: private-key password.

Generate the base64 file locally and transfer its contents through the secret UI;
remove the temporary file after use. Do not commit it or print it in CI logs.

```bash
base64 < /PRIVATE/PATH/glassmail-release.jks > /PRIVATE/PATH/keystore.base64
```

The workflow decodes the secret into `$RUNNER_TEMP`, restricts permissions to 600,
sets `GLASSMAIL_RELEASE_STORE_FILE` to that path, and removes the file on completion.
Tag pushes matching `v*` must exactly match the native versionName. Manual dispatch
is a dry run: it builds and uploads verified artifacts but never publishes a release.
Only the native APK, AAB, and APK checksum are uploaded. Release notes come from the
matching changelog section. Existing tags are not moved or recreated.

## Version policy

`versionName` is `MAJOR.MINOR.PATCH`. Compute `versionCode` as
`MAJOR * 10000 + MINOR * 100 + PATCH`; 1.0.0 maps to 10000.
Keep MINOR and PATCH in 0–99 so the encoding remains unambiguous, increase the code
for every distributed version, and stay within Android's versionCode limit.
The workflow validates the packaged values against `app/build.gradle.kts`.

## Verify an APK

Choose the latest installed SDK build-tools directory, then verify signatures and
inspect package metadata. Both v2 and v3 verification must be true for this release;
compare the certificate SHA-256 digest with the trusted release signing identity.
Confirm package `com.glassmail.app`, versionName `1.0.0`, versionCode `10000`, and no
`application-debuggable` entry. The workflow logs only the certificate SHA-256 digest
from signature verification.

```bash
"$ANDROID_HOME/build-tools/BUILD_TOOLS_VERSION/apksigner" verify --verbose --print-certs GlassMail-v1.0.0.apk
"$ANDROID_HOME/build-tools/BUILD_TOOLS_VERSION/aapt2" dump badging GlassMail-v1.0.0.apk
sha256sum GlassMail-v1.0.0.apk > GlassMail-v1.0.0.apk.sha256
sha256sum -c GlassMail-v1.0.0.apk.sha256
```

F-Droid builds from source and applies its own signing key. Device/provider acceptance
and migration verification remain release-owner checks in `RELEASE_CHECKLIST.md`.
