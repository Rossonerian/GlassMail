# GlassMail Flutter — v1 Release APK Notes

## Pre-flight Checks
| Check | Result |
| :--- | :--- |
| `flutter pub get` | **SUCCESS** |
| `dart run build_runner build` | **SUCCESS** |
| `dart format` | **SUCCESS** (0 changed files) |
| `flutter analyze` | **SUCCESS** (0 issues) |
| `flutter test` | **SUCCESS** (18 tests passed) |

## Signing Configuration
- **Method:** Generated a local test upload keystore (`glassmail-upload.jks`) passed via `key.properties`.
- **SHA-256 Fingerprint:** `29:8C:79:4D:8C:8E:F3:AC:62:EB:2F:04:B4:52:86:3C:6D:6F:36:B5:95:9F:FD:68:47:98:A4:D4:56:D3:9F:1F`
- **Security:** Keystore and passwords were kept strictly local. `key.properties` is protected by `.gitignore`.

## Final Identifiers
- **Application ID:** `com.glassmail.dev.glassmail` (Retained development ID per instructions to not change silently)
- **Version:** `1.0.0+1`

## APK Outputs & Verification
All APKs successfully passed `apksigner verify` and contain the release certificate (NOT the debug certificate).

| Architecture | Path | Size |
| :--- | :--- | :--- |
| **arm64-v8a** | `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` | 39 MB |
| **armeabi-v7a** | `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` | 37 MB |
| **x86_64** | `build/app/outputs/flutter-apk/app-x86_64-release.apk` | 41 MB |
| **Universal** | `build/app/outputs/flutter-apk/app-release.apk` | 82 MB |

## Smoke Test
- **Result:** **PASSED**
- **Device:** Physical Android device (`5B271XEBF3XDF0`, ABI: `arm64-v8a`)
- **Status:** Installed `app-arm64-v8a-release.apk`, successfully launched with Impeller/Vulkan, LiquidGlass initialized, no crashes observed.

## Known Risks for Public Release
The following items from `FUNCTIONAL_STATUS.md` remain **UNVERIFIED** and pose risks for a public v1 rollout:
1. **Live Gmail APPEND/IDLE/quota:** UNVERIFIED in a true live environment.
2. **Database Migrations:** UNVERIFIED on existing DBs migrating from previous versions.
3. **On-device Layout & Performance:** UNVERIFIED on physical hardware (since the smoke test could not be executed).
