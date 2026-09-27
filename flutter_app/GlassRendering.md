# Glass Rendering Engine & Pipeline

## Architecture & Upstream Integration

GlassMail uses the upstream `liquid_glass_renderer` package as its true rendering engine for floating glass UI. 
- **Package Path**: `packages/liquid_glass_renderer` from `https://github.com/whynotmake-it/flutter_liquid_glass.git` (pinned revision).
- **Chrome vs Content**: Liquid glass is strictly reserved for floating chrome (Top Capsule, Dock, Reader Actions, FAB, Command Palette). Content surfaces like mail rows, reader bodies, and composer canvases remain entirely flat and opaque to preserve contrast and readability.
- **Layer Strategy**: The application creates localized `LiquidGlassLayer` bounds using `LiquidGlass.auto` instead of a full-screen filter. This minimizes texture size and GPU workload per the upstream performance recommendations.

---

## 16-Field Glass Material Model

GlassMail maps its internal design tokens (`GlassMaterial`) to `LiquidGlassSettings`:
- **Blur**: Gaussian blur radius (up to 18).
- **Tint/Opacity**: Base color and alpha for the glass.
- **Thickness & Refraction**: Mapped to `LiquidGlassSettings.thickness` and `refractiveIndex`.
- **Chromatic Aberration**: Driven by the `dispersion` token.
- **Lighting**: `specularIntensity` and `specularAngle` control the Impeller shader's lighting.
- **Shape**: Always uses `LiquidRoundedSuperellipse` for floating surfaces.
- **Interactions**: Utilizes `GlassGlow` and `LiquidStretch` for dynamic touch feedback.

---

## Performance & Accessibility Tiering

GlassMail owns the performance policy by categorizing rendering into four active tiers:

| Tier | Rendering Target | Fallback Strategy |
|---|---|---|
| **`FULL`** | High-end GPUs. | `LiquidGlass` with full refraction, thickness, and chromatic aberration. |
| **`BALANCED`** | Mid-range GPUs. | `LiquidGlass` with lower refraction and disabled chromatic aberration. Automatically triggered when animations are disabled. |
| **`LITE`** | Low-end devices. | Drops to `FakeGlass` (platform `BackdropFilter` with blur/tint only). |
| **`ACCESSIBILITY`** | `reduceTransparency` | Flat opaque `DecoratedBox`. 0 blur, 0 shaders. |

- When the OS-level **Reduce Transparency** is enabled, all glass chrome instantly falls back to `GlassTier.OFF` (flat rendering).

## Toolchain Verification

- Built for Flutter 3.47.5 (Dart 3.13.4).
- Shaders compile strictly for the **Impeller backend (Vulkan)** on Android. 
- Devices falling back to Skia will gracefully render without advanced shaders, and `FakeGlass` is heavily optimized for these.
