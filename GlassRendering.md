# Glass rendering

`GlassSurface` exposes `AUTOMATIC`, `LIQUID`, `BLUR`, and `TRANSPARENT` quality choices without changing layout. Automatic currently selects the bounded blur path. The current `LIQUID` path applies an Android `RuntimeShader`/AGSL rounded-lens render effect to its composited content layer, with a bounded SDF edge displacement and rim highlight. `BLUR` uses a framework hardware `RenderEffect` blur fallback; `TRANSPARENT` has no render effect and retains stable tint styling. Reduce Transparency overrides every quality to a near-opaque tonal surface.

This is an independent implementation; no Square or AndroidLiquidGlass source was copied. It is not yet a full backdrop-recorder implementation: it cannot sample arbitrary sibling content behind a surface. Benchmark the quality choices on a device before selecting a shipping default.
