# Third-party notices

| Component | Version | Purpose | License |
| --- | --- | --- | --- |
| Kotlin | 2.0.21 | Language and Gradle plugin | Apache-2.0 |
| Android Gradle Plugin | 8.7.3 | Android build | Apache-2.0 |
| AndroidX Room | 2.7.2 | Durable local database and KSP code generation; latest stable line compatible with the Kotlin 2.0.21/KSP toolchain used by this project | Apache-2.0 |
| AndroidX WorkManager | 2.11.2 | Background scheduling | Apache-2.0 |
| AndroidX Benchmark | 1.3.3 | Device-only Macrobenchmark infrastructure | Apache-2.0 |
| AndroidX Compose / Material 3 / Lifecycle | catalog-managed | Native UI and lifecycle state collection | Apache-2.0 |
| KSP | 2.0.21-1.0.28 | Room Kotlin code generation | Apache-2.0 |
| kotlinx.coroutines | 1.9.0 | Structured asynchronous work | Apache-2.0 |
| Android JavaMail / Activation | 1.6.7 | SMTP submission over authenticated STARTTLS | CDDL-1.1 / GPL-2.0 with Classpath Exception |
| Lobster Two | Google Fonts repository snapshot | Wordmark/display typography; local Bold Italic font asset | SIL Open Font License 1.1 |
| Trirong | Google Fonts repository snapshot | Section headings and message subjects; local Regular font asset | SIL Open Font License 1.1 |
| Maitree | Google Fonts repository snapshot | Reading text and interface labels; local Regular font asset | SIL Open Font License 1.1 |

The JavaMail jars duplicate `META-INF/NOTICE.md`; the app packaging configuration excludes that duplicate metadata resource while retaining the runtime classes. Review the upstream license and notices before release.

## Rendering Evaluation (Phase 0)

Kyant0/AndroidLiquidGlass was evaluated against a custom native AGSL renderer on source quality, maintenance, Compose 1.7+ compatibility, GPU path, backdrop correctness, license, extensibility, and visual fidelity.

- **Decision**: Adopt a custom in-tree AGSL renderer (`:designsystem:glass`) using Jetpack Compose 1.7 `GraphicsLayer` recording.
- **Rationale**:
  1. *Backdrop Correctness*: Compose 1.7's `rememberGraphicsLayer()` + `Modifier.drawWithContent { graphicsLayer.record { ... } }` allows zero-copy recording of content layers directly within the Compose render tree. External View-based libraries require surface view overlays or PixelCopy asynchronous roundtrips.
  2. *API & Ecosystem*: Pure Compose architecture without View hierarchy wrapping or fragile native bindings.
  3. *Physical Lens Model*: Full control over a 14-parameter physical glass model (`GlassMaterial`), including multi-channel chromatic dispersion, SDF rounded corners, specular highlights, and dynamic luminance adaptation.
  4. *Zero Third-Party Licensing/Transitive Dependencies*: Keeps binary size minimal and avoids external release coupling.

The `designsystem/src/main/assets/font-licenses/` directory contains the font license texts alongside the bundled font assets.

Square's navbar behavior and Kyant0/AndroidLiquidGlass's Backdrop catalog were reviewed at `147a6e79b53c033e5f01eab9453e60b3e9f827e6` and `65ab177e90e5c1d8c62e70cf7755841982da65f6`, respectively. GlassMail keeps its own in-tree Compose/AGSL renderer and glass components; the bottom dock and reusable button, switch, slider, and segmented controls follow those interaction patterns. No Square application source, AndroidLiquidGlass catalog source, or external liquid-glass runtime dependency is included. The upstream repositories and their licenses must be reviewed again before copying source in a future change.
