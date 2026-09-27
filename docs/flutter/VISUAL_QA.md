# Flutter visual and accessibility evidence

This document separates local widget evidence from Android device inspection.
The screenshot files in `artifacts/` are development APK checkpoints; they do
not prove current live-account behavior or iOS parity.

| Area | Evidence | State |
| --- | --- | --- |
| Representative dark Inbox and Glass Lab | `artifacts/p0.4-pixel9a-inbox.png`, `artifacts/p0.4-pixel9a-glass-lab.png` | Pixel 9a, Android 17; inspected |
| Morphing dock expanded/folded/returned | `artifacts/p0.5-pixel9a-expanded.png`, `artifacts/p0.5-pixel9a-collapsed.png`, `artifacts/p0.5-pixel9a-return-expanded.png` | Pixel 9a, Android 17; gesture state inspected |
| Account setup and Settings | `artifacts/p0.6-pixel9a-account-setup.png`, `artifacts/p0.6-pixel9a-settings.png` | Earlier P0.6 APK; captures are not evidence for later preferences |
| Phase 1 arm64 debug APK | `flutter_app/build/app/outputs/flutter-apk/app-debug.apk` · SHA256 `6da6f8b5cc1f6d7dfe6cbc6f25f19db5af909bd533dd4c591818767ff0859176` | Build passed (148 MB); ADB reported no connected devices, so no install or current-build capture |
| Phase 2 final arm64 debug APK | `flutter_app/build/app/outputs/flutter-apk/app-debug.apk` · SHA256 `54e18fdc1baa40d0d90107017266364c672e2c7e82004679d505a26af56c0985` | Rebuilt successfully (154,817,866 bytes), including Android contacts and widget host; ADB has no connected device, so no install or Phase 2 capture |
| Unsigned Android release App Bundle | `flutter_app/build/app/outputs/bundle/release/app-release.aab` · SHA256 `ec524e3f5d85a1f8b78871fd699dc40a570c81dff14b72985903c7897c2d4eff` | Rebuilt successfully (65,605,911 bytes); not signed for distribution |
| 200% text scale, reduced animation, credential update | `flutter_app/test/widget_test.dart` | Widget smoke tests pass; not a physical-device TalkBack test |
| Untrusted HTML | `flutter_app/test/mail_html_text_test.dart` | Script/style/frame/form/SVG/image/link samples become inert plain text |
| Compose picker, draft reopen, reply/forward, Sent refresh and attachment share | `docs/flutter/MANUAL_TEST.md` | NOT RUN on Phase 1 APK |
| Light/dark, reduced transparency/motion, notification privacy, high contrast, TalkBack, IME, rotation/foldable | `docs/flutter/MANUAL_TEST.md` | NOT RUN on Phase 1 APK |
| Templates, saved views, local screener, snooze, encrypted backup, Trash purge and sender profiles | `flutter_app/test/workflow_store_test.dart`, `flutter_app/test/encrypted_mail_backup_test.dart`, `packages/data_mail/test/local_first_mail_repository_test.dart`, `packages/core_imap/test/imap_client_test.dart` | Local persistence/protocol evidence only; native picker/share, OS-level reminder, shortcut, purge, widget and background behavior remains NOT RUN |
| Android home-screen widget source | `flutter_app/android/app/src/main` and Android debug APK | Host compiles; launcher placement, refresh, deep link and TalkBack behavior NOT RUN because no device is connected |
| iOS WidgetKit target and VoiceOver | `flutter_app/ios/WidgetExtension`, `Runner.xcodeproj` | Source/target is wired; build, App Group provisioning, simulator, device and VoiceOver NOT RUN; macOS/Xcode required |

No contrast ratio, thermal/p90 performance, or end-to-end accessibility score
is claimed from the current widget tests. Device and iOS checks remain separate
acceptance evidence.
