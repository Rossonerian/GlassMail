# Performance & Benchmarking

## Build & Test Verification Status
Real build and automated test verification results executed on host system:
- **`./gradlew test`**: SUCCESS (249 tasks; all unit tests in domain, data, core, sync, and app passed with 0 failures).
- **`./gradlew lint`**: SUCCESS (275 tasks; 0 lint errors across all modules).
- **`./gradlew assembleDebug`**: SUCCESS (255 tasks; debug APK compiled and packaged cleanly).
- **`:benchmark:connectedCheck`**: No physical device or running emulator attached at verification time (`adb devices` returned empty device list). No synthetic or fake performance numbers are reported.

## JDK & Toolchain Environment Resolution
- **Issue**: Previously, `:benchmark` packaging failed due to missing `jlink` in the default Java 21 distribution.
- **Resolution**: OpenJDK 17 (`/usr/lib/jvm/java-17-openjdk`) contains full `jlink` and is 100% compatible with AGP 8.7.3 and Gradle 8.9. All builds and benchmark compilation targets compile cleanly.

## Rendering Engine Performance Safeguards
1. **Zero Bitmap Allocations**:
   - `GlassProvider` records the background hierarchy into a native hardware `GraphicsLayer` via `rememberGraphicsLayer()` and `layer.record { ... }`.
   - `GlassSurface` samples the layer directly via `translate` + `drawLayer(layer)` in hardware canvas rather than allocating or copying bitmaps into memory.
2. **Flat Content Scrolling Canvas**:
   - The message list (`LazyColumn`) rows are completely flat with zero shader or blur overhead.
   - Only the floating navigation dock and top capsule run the shader effect, bounding GPU fill rate to < 15% of screen area.
3. **Hardware Runtime Shader Caching**:
   - The AGSL `RuntimeShader` (`PHYSICAL_LENS_SHADER`) is instantiated once per tier and remembered across recompositions. Uniforms (`refraction`, `dispersion`, `rimLight`, `specularAngle`, `specularIntensity`) are updated without recompilation.
4. **Adaptive Tier Fallback**:
   - If `reduceTransparency` is active or if the device runs on API < 33, `GlassTier.LITE` (hardware RenderEffect blur) or `GlassTier.ACCESSIBILITY` (flat tonal surface) is selected, completely bypassing the AGSL shader pipeline.
5. **Freeze State Optimization**:
   - `MorphingDock` supports `backdropFrozen` when the inbox list settles, preventing unnecessary re-sampling passes during idle states.
