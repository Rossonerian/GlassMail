# GlassMail Performance Architecture

GlassMail aims to provide 60/120fps scrolling and interaction on modern hardware while rendering physically convincing liquid glass effects.

## Liquid Glass Rendering

We use `liquid_glass_renderer` as our rendering engine. To meet performance goals:
1. **No Screen-Sized Render Targets:** We never wrap the `Scaffold` or main app body in a `LiquidGlassLayer`. Instead, `GlassMailGlass` utilizes `LiquidGlass.auto` which creates minimal-sized layer bounds precisely around Chrome elements like the Dock and App Capsule.
2. **Animation Constraint:** The `MorphingMailDock` uses strict `OverflowBox` bounds so that layout does not repeatedly invalidate and jitter during the animation.
3. **No Filtered Content:** Mail threads and compose views remain 100% flat (opaque or transparent without blur), meaning scrolling through dense content is never bottlenecked by shader operations.
4. **Tiering System:**
   - **FULL**: Full shading.
   - **BALANCED**: Auto-applied if animations are disabled on the OS level, reducing some shader complexity.
   - **LITE**: Uses `FakeGlass`, which relies purely on platform hardware blur (`BackdropFilter`) instead of a complex optical shader.
   - **ACCESSIBILITY**: 0ms overhead, flat opaque rendering.

## Testing Observations (Android/Impeller)
- The app has been verified to run seamlessly on Vulkan/Impeller backends.
- While the advanced shaders will fallback on Skia devices (due to SkSL loop constraints), `FakeGlass` remains highly performant there.

