# GlassMail Design Implementation

## Implementation Status

| Feature / Component | Module / Route | Specification & Design Token Integration | Status |
|---|---|---|---|
| Upstream Glass Renderer | `liquid_glass_renderer` | Pinned to git ref `ad3bcff2`. Replaces obsolete Kotlin AGSL shaders. | Complete |
| Performance Tiering | `GlassMailGlass` | `GlassMailTier` mapping FULL (LiquidGlass), BALANCED, LITE (FakeGlass), OFF. | Complete |
| Design Tokens | `GlassMaterial` | Material presets (blur, opacity, refraction, dispersion, specularIntensity) | Complete |
| Optical Lab Sandbox | `glass_lab_screen.dart` | Real-time parameter sliders, test backdrops, material presets | Complete |
| Morphing Dock | `MorphingMailDock` | Animated `OverflowBox` bounds, interactive `GlassGlow` and `LiquidStretch`. | Complete |
| Modular Inbox Screen | `inbox_screen.dart` | `GlassMailTopCapsule`, flat `MailRow` list, responsive safe areas | Complete |
| Modular Reader Screen | `reader_screen.dart` | Flat distraction-free reading canvas, floating glass action dock | Complete |
| Modular Search Screen | `search_screen.dart` | Instant FTS search, suggestion chips, flat results | Complete |
| Modular Settings Screen | `settings_screen.dart` | Theme, Quality, Accessibility controls | Complete |
| Command Palette | `command_palette.dart` | Modal overlay with `GlassPresets.dialog`, interactive glass | Complete |
| Flat Canvas Enforcement | All Screens | Message rows, compose canvas, reader body remain 100% flat; glass only on floating chrome | Complete |
| Accessibility & Fallback | `GlassMailGlass` | Auto-fallback to `GlassTier.off` on `reduceTransparency`, accessible semantics | Complete |

## Design Decisions & Guardrails
1. **Never Blur Reading Text**:
   - The mail reading body and composing editor never apply backdrop filters or refraction shaders. They rest on high-contrast, clean surfaces with AAA contrast ratios.
2. **Interactive Glass**:
   - Floating controls use `GlassGlow` for touch-responsive illumination and `LiquidStretch` for organic physical squash and stretch on interaction.
3. **Physical Optical Coherence**:
   - GlassMail defines its own standard `GlassMaterial` settings (dispersion, refraction, specular angle, etc.) to ensure aesthetic coherence, mapped natively into `LiquidGlassSettings`.
   - `LiquidGlassLayer` bounds are kept as tight as possible around Chrome UI (like Dock and Capsule) instead of blanketing the entire screen, strictly following upstream performance guidelines.

