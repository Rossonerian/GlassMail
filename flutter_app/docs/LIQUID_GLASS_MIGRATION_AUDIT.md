# Liquid Glass Migration Audit

## 1. Current Glass Architecture
- **Kotlin Origin:** The original Android/Kotlin codebase used a custom AGSL shader (`PHYSICAL_LENS_SHADER`), `GlassSurface`, `GlassProvider`, and `LocalBackdropSource` for zero-copy backdrop sampling.
- **Flutter Current State:** During the Flutter migration, this custom AGSL architecture was not ported. Instead, the Flutter app (`flutter_app/`) currently wraps an external package using `GlassMailGlass` (in `lib/design/glass_mail_glass.dart`) and maps custom `GlassMaterial` tokens to it. It recently transitioned from `liquid_glass_widgets` to `apple_liquid_glass` (a facade package pointing to `liquid_glass_renderer`).
- **Dependencies:** The current `pubspec.yaml` depends on `apple_liquid_glass` from git, but then explicitly overrides `liquid_glass_renderer` to resolve a versioning conflict. This dual-dependency structure is redundant and brittle.

## 2. Upstream Architecture (`liquid_glass_renderer`)
- **Package Path:** `packages/liquid_glass_renderer` in the `whynotmake-it/flutter_liquid_glass.git` repository.
- **Core Components:**
  - `LiquidGlassLayer`: Required parent for rendering glass, captures the background.
  - `LiquidGlass`: Creates the individual glass shapes. `LiquidGlass.auto` automatically renders on an ancestor layer or creates its own.
  - `FakeGlass`: A highly performant fallback using platform blur.
  - `LiquidGlassSettings`: Controls refraction, thickness, blur, glassColor, and lighting.
  - `LiquidRoundedSuperellipse`: Specifically designed smooth squircle shape (equivalent to Apple's continuous rounded rectangles).
- **Performance:** Recommends keeping the bounding box of `LiquidGlassLayer` as small as possible. In `GlassMail`, isolating the Top Capsule and Dock into their own `LiquidGlass.auto` layers aligns perfectly with this guidance.

## 3. Migration Sequence & Compatibility Assessment
- **Compatibility:** Upstream package handles Flutter >= 3.10 and requires Impeller for full shaders (though `FakeGlass` works everywhere). GlassMail is on Flutter 3.47.5, so compatibility is guaranteed.
- **Step 1:** Consolidate `pubspec.yaml` dependencies. Remove the `apple_liquid_glass` facade and depend solely on `liquid_glass_renderer` at a pinned git revision (`ad3bcff22549f17f67bf87a01f80ed1f06cf9a0e`).
- **Step 2:** Define `GlassMailGlass` using `liquid_glass_renderer` directly. Implement Tiers:
  - **FULL:** Uses `LiquidGlass` with full settings.
  - **LITE (or disabled animations):** Uses `FakeGlass` (reduces load on older GPUs).
  - **ACCESSIBILITY:** Flat decorated box (respects `reduceTransparency`).
- **Step 3:** Convert core floating surfaces (App Capsule, Dock) to use the new `GlassMailGlass` abstraction.
- **Step 4:** Review visuals and confirm flat content surfaces (mail rows, reader) remain strictly flat, guaranteeing readability.
- **Step 5:** Clean up unused imports and test on arm64 release.

## 4. Risks & Mitigations
- **Risk:** Animations shrinking/growing `LiquidGlass` bounds (e.g., MorphingMailDock).
- **Mitigation:** Ensure layout primitives (`OverflowBox` or `UnconstrainedBox`) prevent UI content from squishing during animations, and ensure `LiquidGlass.auto` handles dynamic bounds properly.
- **Risk:** Unnecessary `LiquidGlassLayer` wrapping the entire screen.
- **Mitigation:** Rely on `LiquidGlass.auto` placed strictly inside the floating chrome components to maintain minimal pixel footprint.
