# GlassMail

GlassMail is a fully-featured, local-first Gmail replacement built in Flutter.
It offers conversation threads, categories, FTS4 offline search, push notifications via IMAP IDLE, and a beautiful liquid glass design system.

## Setup & Running

1. **Prerequisites:** Flutter ^3.13.4
2. **Install dependencies:** `flutter pub get`
3. **Run the app:**
   - Debug: `flutter run`
   - Release: `flutter run --release`

### Account Setup
GlassMail connects directly to your Gmail account using an App Password.
1. Enable 2-Step Verification in your Google Account.
2. Generate an App Password for "GlassMail".
3. Use your Gmail address and the generated App Password to sign in.

## Project Structure
The app is modularized into several internal packages:
- `core_model`, `domain_mail`: Immutable models and domain logic.
- `core_database`: Drift SQLite database (mirrors the native Room v10 schema).
- `core_imap`: IMAP/SMTP implementation using `enough_mail`.
- `core_security`: Secure credential storage using Android Keystore / iOS Keychain.
- `data_mail`: Repository layer, WorkManager sync, and outbound queues.
- `lib/`: The main Flutter UI and Glass Design System.

## Glass Design System Tiers
The app automatically adjusts its visual fidelity based on device capabilities:
- **Full (Premium):** Lens refraction, dispersion, and deep blur (Requires capable GPU).
- **Balanced (Standard):** Reduced sampling and dispersion.
- **Light (Minimal):** Bounded blur/tint, ideal for battery saver.
- **Off (Opaque):** High-contrast mode, auto-selected when animations are disabled or Reduce Transparency is active.

## Build Flavors & Distribution
- **Android APK:** `flutter build apk --release` (Produces an unsigned APK for manual distribution).
- **Android App Bundle:** `flutter build appbundle --release` (For Google Play / F-Droid).
- **iOS IPA:** `flutter build ipa --release` (Requires macOS and Apple Developer provisioning).

### Signing and Release
- **Android:** Release builds are currently unsigned by default. To sign, configure a `key.properties` file in `android/` referencing your production Keystore.
- **iOS:** Push notifications on iOS are opportunistic (via `BGTaskScheduler`). True real-time push requires APNs certificates. iOS builds require macOS, Xcode, and a valid Apple Developer Team ID configured in the Runner workspace.
