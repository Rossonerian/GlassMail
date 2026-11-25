# Third-party notices

This file covers the native Kotlin v1 application (`com.glassmail.app`), including every resolved runtime dependency group and artifact from `:app:dependencies` (`releaseRuntimeClasspath`), build-time plugins, and bundled font assets.

## Native runtime dependencies (`releaseRuntimeClasspath`)

| Group | Artifact(s) | Resolved Version | Purpose | License |
| --- | --- | --- | --- | --- |
| `org.jetbrains.kotlin` | `kotlin-stdlib`, `kotlin-stdlib-common` | `2.1.20` | Kotlin standard library | Apache-2.0 |
| `org.jetbrains` | `annotations` | `23.0.0` | JetBrains static analysis annotations | Apache-2.0 |
| `org.jetbrains.kotlinx` | `kotlinx-coroutines-bom`, `kotlinx-coroutines-core`, `kotlinx-coroutines-core-jvm`, `kotlinx-coroutines-android` | `1.9.0` | Structured concurrency and Android main-dispatcher support | Apache-2.0 |
| `org.jetbrains.kotlinx` | `kotlinx-serialization-bom`, `kotlinx-serialization-core`, `kotlinx-serialization-core-jvm` | `1.6.3` | Navigation type-safe serialization runtime | Apache-2.0 |
| `org.jspecify` | `jspecify` | `1.0.0` | Nullability annotations | Apache-2.0 |
| `com.google.guava` | `listenablefuture` | `1.0` | `ListenableFuture` interface used by AndroidX/WorkManager | Apache-2.0 |
| `com.sun.mail` | `android-mail`, `android-activation` | `1.6.7` | Android JavaMail / Activation for SMTP submission, IMAP/MIME parsing, and RFC 822 encoding | CDDL-1.1 / GPL-2.0 with Classpath Exception |
| `androidx.activity` | `activity-compose`, `activity-ktx`, `activity` | `1.9.2` | Compose activity integration and Activity KTX | Apache-2.0 |
| `androidx.core` | `core-ktx`, `core` | `1.15.0` | AndroidX Core and Kotlin extensions | Apache-2.0 |
| `androidx.navigation` | `navigation-compose`, `navigation-runtime-ktx`, `navigation-runtime`, `navigation-common-ktx`, `navigation-common` | `2.8.2` | Jetpack Navigation for Compose | Apache-2.0 |
| `androidx.compose` | `compose-bom` | `2024.09.03` | Jetpack Compose Bill of Materials | Apache-2.0 |
| `androidx.compose.animation` | `animation`, `animation-android`, `animation-core`, `animation-core-android` | `1.7.3` | Jetpack Compose animations | Apache-2.0 |
| `androidx.compose.foundation` | `foundation`, `foundation-android`, `foundation-layout`, `foundation-layout-android` | `1.7.3` | Jetpack Compose foundation and layout primitives | Apache-2.0 |
| `androidx.compose.material` | `material-icons-core`, `material-icons-core-android`, `material-icons-extended`, `material-icons-extended-android`, `material-ripple`, `material-ripple-android` | `1.7.3` | Material icons and ripple effects | Apache-2.0 |
| `androidx.compose.material3` | `material3`, `material3-android` | `1.3.0` | Material 3 UI components | Apache-2.0 |
| `androidx.compose.runtime` | `runtime`, `runtime-android`, `runtime-saveable`, `runtime-saveable-android` | `1.7.3` | Jetpack Compose runtime and saveable state | Apache-2.0 |
| `androidx.compose.ui` | `ui`, `ui-android`, `ui-geometry`, `ui-geometry-android`, `ui-graphics`, `ui-graphics-android`, `ui-text`, `ui-text-android`, `ui-unit`, `ui-unit-android`, `ui-util`, `ui-util-android` | `1.7.3` | Jetpack Compose UI, graphics, text, and geometry | Apache-2.0 |
| `androidx.lifecycle` | `lifecycle-common`, `lifecycle-common-jvm`, `lifecycle-common-java8`, `lifecycle-livedata`, `lifecycle-livedata-core`, `lifecycle-livedata-core-ktx`, `lifecycle-process`, `lifecycle-runtime`, `lifecycle-runtime-android`, `lifecycle-runtime-compose`, `lifecycle-runtime-compose-android`, `lifecycle-runtime-ktx`, `lifecycle-runtime-ktx-android`, `lifecycle-service`, `lifecycle-viewmodel`, `lifecycle-viewmodel-android`, `lifecycle-viewmodel-compose`, `lifecycle-viewmodel-compose-android`, `lifecycle-viewmodel-ktx`, `lifecycle-viewmodel-savedstate` | `2.8.7` | Lifecycle, ViewModel, LiveData, Service, and Compose lifecycle integration | Apache-2.0 |
| `androidx.room` | `room-runtime`, `room-runtime-android`, `room-common`, `room-common-jvm` | `2.7.2` | Durable local SQLite ORM runtime | Apache-2.0 |
| `androidx.sqlite` | `sqlite`, `sqlite-android`, `sqlite-framework`, `sqlite-framework-android` | `2.5.1` | AndroidX SQLite abstraction and framework driver | Apache-2.0 |
| `androidx.work` | `work-runtime-ktx`, `work-runtime` | `2.11.2` | Background work scheduling (periodic sync, delayed send, draft sync) | Apache-2.0 |
| `androidx.annotation` | `annotation`, `annotation-jvm`, `annotation-experimental` | `1.9.1` / `1.4.1` | AndroidX compile/runtime annotations | Apache-2.0 |
| `androidx.arch.core` | `core-common`, `core-runtime` | `2.2.0` | AndroidX Architecture core utilities | Apache-2.0 |
| `androidx.collection` | `collection`, `collection-jvm`, `collection-ktx` | `1.4.4` | AndroidX optimized collections | Apache-2.0 |
| `androidx.concurrent` | `concurrent-futures`, `concurrent-futures-ktx` | `1.1.0` | `ListenableFuture` / `CallbackToFutureAdapter` helpers | Apache-2.0 |
| `androidx.savedstate` | `savedstate`, `savedstate-ktx` | `1.2.1` | Saved instance state registry | Apache-2.0 |
| `androidx.startup` | `startup-runtime` | `1.1.1` | App Startup initialization | Apache-2.0 |
| `androidx.profileinstaller` | `profileinstaller` | `1.3.1` | Baseline profile installation | Apache-2.0 |
| `androidx.tracing` | `tracing`, `tracing-ktx` | `1.2.0` | System trace markers | Apache-2.0 |
| `androidx.autofill` | `autofill` | `1.0.0` | Autofill hint support | Apache-2.0 |
| `androidx.customview` | `customview-poolingcontainer` | `1.0.0` | View recycling pool container support | Apache-2.0 |
| `androidx.emoji2` | `emoji2` | `1.3.0` | Emoji compatibility rendering | Apache-2.0 |
| `androidx.graphics` | `graphics-path` | `1.0.1` | Vector path utilities | Apache-2.0 |
| `androidx.interpolator` | `interpolator` | `1.0.0` | Animation interpolators | Apache-2.0 |
| `androidx.versionedparcelable` | `versionedparcelable` | `1.1.1` | Parcelable versioning utilities | Apache-2.0 |

The JavaMail jars (`com.sun.mail:android-mail` and `com.sun.mail:android-activation`) duplicate `META-INF/NOTICE.md` and `META-INF/LICENSE.md`; the app packaging configuration excludes those duplicate metadata resources while retaining the runtime classes. Review the upstream license and notices before release.

## Build-time tools, benchmarks, and bundled fonts

| Component | Version | Purpose | License |
| --- | --- | --- | --- |
| Kotlin Gradle & Compose plugins | `2.0.21` | Language and Compose compiler Gradle plugins | Apache-2.0 |
| Android Gradle Plugin | `8.7.3` | Android build system | Apache-2.0 |
| KSP (`com.google.devtools.ksp`) | `2.0.21-1.0.28` | Room Kotlin symbol processing | Apache-2.0 |
| AndroidX Room Compiler / Testing | `2.7.2` | Compile-time DAO/schema generation and migration tests | Apache-2.0 |
| AndroidX Benchmark (`androidx.benchmark:benchmark-macro-junit4`) | `1.3.3` | Device-only Macrobenchmark infrastructure | Apache-2.0 |
| Lobster Two | Google Fonts repository snapshot | Wordmark/display typography; local Bold Italic font asset | SIL Open Font License 1.1 |
| Trirong | Google Fonts repository snapshot | Section headings and message subjects; local Regular font asset | SIL Open Font License 1.1 |
| Maitree | Google Fonts repository snapshot | Reading text and interface labels; local Regular font asset | SIL Open Font License 1.1 |

The `designsystem/src/main/assets/font-licenses/` directory contains the font license texts alongside the bundled font assets.

## Flutter host (experimental)

The parallel experimental Flutter development host (`flutter_app/`, `com.glassmail.dev.glassmail`) has its own locked package, native source, and build-tool inventory in [flutter_app/DEPENDENCY_LICENSES.md](flutter_app/DEPENDENCY_LICENSES.md). Keep the Flutter SDK, Gradle plugins, generated native host, and any later runtime packages/assets in that inventory.

The Flutter credential-store adapter uses `flutter_secure_storage` under BSD-3-Clause. Android app backup is disabled; account removal must call the adapter's per-account delete operation. See the migration matrix for the current key and backup policy.

The Flutter development host additionally uses `flutter_contacts` (MIT), `home_widget` (BSD-3-Clause), and `cryptography` / `cryptography_flutter` (Apache-2.0) for its user-invoked contacts picker, aggregate unread widgets and password-protected local backup. See [DEPENDENCY_LICENSES.md](flutter_app/DEPENDENCY_LICENSES.md) for exact locked versions and all transitive/build-time licenses.

## Rendering Evaluation (Phase 0)

Kyant0/AndroidLiquidGlass was evaluated against a custom native AGSL renderer on source quality, maintenance, Compose 1.7+ compatibility, GPU path, backdrop correctness, license, extensibility, and visual fidelity.

- **Decision**: Adopt a custom in-tree AGSL renderer (`:designsystem:glass`) using Jetpack Compose 1.7 `GraphicsLayer` recording.
- **Rationale**:
  1. *Backdrop Correctness*: Compose 1.7's `rememberGraphicsLayer()` + `Modifier.drawWithContent { graphicsLayer.record { ... } }` allows zero-copy recording of content layers directly within the Compose render tree. External View-based libraries require surface view overlays or PixelCopy asynchronous roundtrips.
  2. *API & Ecosystem*: Pure Compose architecture without View hierarchy wrapping or fragile native bindings.
  3. *Physical Lens Model*: Full control over a 14-parameter physical glass model (`GlassMaterial`), including multi-channel chromatic dispersion, SDF rounded corners, specular highlights, and dynamic luminance adaptation.
  4. *Zero Third-Party Licensing/Transitive Dependencies*: Keeps binary size minimal and avoids external release coupling.

Square's navbar behavior and Kyant0/AndroidLiquidGlass's Backdrop catalog were reviewed at `147a6e79b53c033e5f01eab9453e60b3e9f827e6` and `65ab177e90e5c1d8c62e70cf7755841982da65f6`, respectively. GlassMail keeps its own in-tree Compose/AGSL renderer and glass components; the bottom dock and reusable button, switch, slider, and segmented controls follow those interaction patterns. No Square application source, AndroidLiquidGlass catalog source, or external liquid-glass runtime dependency is included. The upstream repositories and their licenses must be reviewed again before copying source in a future change.
