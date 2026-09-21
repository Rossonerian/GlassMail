# Glass Rendering Engine & Pipeline

## Architecture & Zero-Copy Live Backdrop Sampling
GlassMail implements a zero-copy live GPU backdrop sampling and AGSL refraction shader architecture in `:designsystem:glass` without external dependencies.

```
┌─────────────────────────────────────────────────────────┐
│                      AmbientCanvas                      │
│  ┌───────────────────────────────────────────────────┐  │
│  │                   GlassProvider                   │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │         GraphicsLayer.record { ... }        │  │  │
│  │  │  (NavHost, Flat Canvas, List, Reader Body)  │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │                         │                         │  │
│  │                LocalBackdropSource                │  │
│  │                         │                         │  │
│  │                         ▼                         │  │
│  │                   GlassSurface                    │  │
│  │       (AGSL Shader / RenderEffect / Fallback)     │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

1. **`GlassProvider` & `LocalBackdropSource`**: Wraps the screen tree with `rememberGraphicsLayer()` and records the underlying content via `GraphicsLayer.record { ... }`. The captured layer reference is supplied via CompositionLocal `LocalBackdropSource`.
2. **`GlassSurface` Coordinate Translation**: When floating glass elements (Dock, Top Capsule, Reader Actions, Command Palette) render, `GlassSurface` determines its window coordinates relative to the captured `GraphicsLayer`, translating the canvas and drawing the underlying layer directly into the shader's `imageShader` input with zero byte copying and zero bitmap allocations.
3. **Flat Reading & Composing Canvas**: In strict accordance with the GlassMail design guidelines, message rows, reader bodies, and composer canvases remain completely FLAT and distortion-free for optimal readability and contrast. Liquid glass is reserved exclusively for floating chrome.

---

## 14-Parameter Physical Glass Material Model
The optical engine models light interaction through a 14-parameter physical glass material:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `blur` | `Dp` | `18.dp` | Gaussian blur kernel radius applied to the backdrop layer |
| `saturation` | `Float` | `1.05f` | Backdrop color saturation boost to counteract blur desaturation |
| `tint` | `Color` | `Color.Unspecified` | Translucent tonal tint overlay |
| `opacity` | `Float` | `0.52f` | Alpha opacity of the base tint layer |
| `refraction` | `Float` | `0.24f` | Lens displacement strength (refractive index delta) |
| `refractionHeight`| `Dp` | `8.dp` | Simulated physical depth/thickness of the glass slab |
| `dispersion` | `Float` | `0.16f` | Chromatic dispersion splitting RGB channels across refraction paths |
| `rimLight` | `Float` | `0.38f` | Specular rim lighting intensity along border curves |
| `specularIntensity`| `Float` | `0.46f` | Key directional light reflection intensity |
| `specularAngle` | `Float` | `-0.785f` | Directional key light angle (~ -45° upper-left key light) |
| `highlightFalloff`| `Float` | `4.0f` | Exponential falloff exponent for specular sheen |
| `shadow` | `Dp` | `10.dp` | Projected ambient shadow elevation |
| `cornerRadius` | `Dp` | `20.dp` | Analytical SDF rounded corner radius |
| `innerShadow` | `Dp` | `0.dp` | Inner bezel occlusion shadow |
| `interactionStrength`| `Float` | `0.28f` | Dynamic feedback response on user interaction |
| `luminanceAdaptation`| `Float` | `0.35f` | Dynamic contrast balance against underlying light/dark luminance |

---

## AGSL Hardware Shader Pipeline
On Android 13+ (API 33+ / TIRAMISU), `GlassSurface` compiles an AGSL `RuntimeShader` (`PHYSICAL_LENS_SHADER`):
- **Signed Distance Field (SDF)**: Evaluates exact analytical rounded-box distance `sdRoundedBox(coord - center, halfSize, radius)`.
- **Surface Normal Approximation**: Derives pseudo-3D normals from SDF gradient vectors `vec2(d(x+e) - d(x-e), d(y+e) - d(y-e))`.
- **Chromatic Dispersion**: Offsets red, green, and blue texture sampling coordinates along the normal vector:
  - `Red: coord + normal * refraction * (1.0 + dispersion)`
  - `Green: coord + normal * refraction`
  - `Blue: coord + normal * refraction * (1.0 - dispersion)`
- **Specular Rim Highlights**: Blends upper-left directional key specular light and perimeter fresnel rim glow.
- **Luminance Adaptation**: Calculates perceived luminance `dot(sampledColor.rgb, vec3(0.299, 0.587, 0.114))` and adjusts tint opacity to guarantee text contrast >= 4.5:1.

---

## Performance & Accessibility Tiering

| Tier | Quality Enum | Render Pipeline | Battery & Device Target |
|---|---|---|---|
| **`FULL`** | `LIQUID` / `AUTOMATIC` | Full AGSL SDF + Chromatic Dispersion + Rim Light + Backdrop Layer | High-end GPU, API 33+, Normal battery |
| **`BALANCED`**| Internal fallback | AGSL SDF + Refraction (no dispersion) | Mid-range GPU, 60fps budget target |
| **`LITE`** | `BLUR` | Platform hardware `RenderEffect.createBlurEffect()` | API 31-32, Low-memory or battery saver |
| **`ACCESSIBILITY`**| `TRANSPARENT` | Flat semi-opaque tonal surface (0 blur, 0 distortion) | `reduceTransparency` enabled, API < 31 |

- When user toggles **Reduce Transparency**, all glass chrome immediately drops to `GlassTier.ACCESSIBILITY`, rendering flat high-contrast tonal surfaces.
- When user toggles **Reduce Motion**, all spring animations transition to zero-overshoot short tweens (80–100ms).
- When running in **Glass Optical Lab** (`ROUTE_GLASS_LAB`), developers can inspect live frame timings (60Hz / 120Hz frame budget) and tune all 14 optical parameters in real time.

---

## Toolchain Verification
- **Compose**: 1.7.3 (`composeBom = "2024.09.03"`). Provides `rememberGraphicsLayer()` / `GraphicsLayer.record` for zero-copy live backdrop recording.
- **Kotlin**: 2.0.21 with Compose Compiler Gradle Plugin.
- **AGP**: 8.7.3.
- **JDK**: OpenJDK 17 (`/usr/lib/jvm/java-17-openjdk`) containing `jlink` for benchmark packaging and full Gradle 8.9 compatibility.
