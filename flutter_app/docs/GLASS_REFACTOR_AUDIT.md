# Glass Refactor Audit

## Obsolete Files Removed
- During the Flutter migration, the original Kotlin `GlassSurface` and `GlassProvider` were entirely dropped.
- In this refactoring pass, we successfully removed the `apple_liquid_glass` facade package dependency and now point directly to `liquid_glass_renderer` at Git SHA `ad3bcff2`.

## Current State
- The app successfully compiles.
- All floating surfaces (Dock, Command Palette, Top Capsule) use the unified `GlassMailGlass` abstraction.
- The layers are properly decoupled (no full-screen wrapping).
- Interactions (squash & stretch, glow) are applied locally to controls without breaking accessibility fallbacks.
