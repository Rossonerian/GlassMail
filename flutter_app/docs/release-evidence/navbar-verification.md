# Liquid glass navbar verification

Date: 2026-09-29

## Implementation

GlassMail now uses `liquid_glass_widgets` 1.6.2, the same package version used
by Karmi. Karmi's shell constructs `GlassTabBar.bottom`; GlassMail uses
`GlassTabBar.minimizable` so scrolling can still minimize the dock. Its
expanded draggable tab indicator uses the package's shared drag recognizer:
it follows the pointer and selects the tab on release. The old custom gesture
and renderer implementation has been removed from the navigation adapter.

References:

- `/home/rosso/Projects/Karmi/mobile/lib/shell/karmi_shell.dart`
- `/home/rosso/.pub-cache/hosted/pub.dev/liquid_glass_widgets-1.6.2/lib/src/widgets/surfaces/tab_bar_drag_gesture_mixin.dart`
- `/home/rosso/Projects/GlassMail/flutter_app/lib/design/liquid_glass_nav_bar.dart`

## Build and checks

- `flutter analyze`: passed with no issues.
- `flutter build apk --release --target-platform android-arm64`: succeeded.
- APK: `flutter_app/artifacts/glassmail-karmi-nav-v2.apk`
- Package: `com.glassmail.dev.glassmail`, version `1.0.0` (version code 2).
- Size: 41,228,077 bytes.
- SHA-256: `c87cafc36d9869e9a3e184ce10ad552875e262395a1b5b186c297c011b926a74`
- The release build reports SkSL shader-translation warnings for the existing
  `liquid_glass_renderer` dependency. The APK still builds successfully.
- The test suite was not run for this APK.

## Device status

An Android device reporting as Pixel 9a was connected during the build. The APK
was not installed or finger-tested; the user plans to install it manually. The
drag gesture and visual behavior on the device therefore remain unverified.

## Final status

`LIQUID GLASS NAVBAR UNVERIFIED — DEVICE TEST NOT COMPLETED`
