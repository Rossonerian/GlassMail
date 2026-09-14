# Performance

`benchmark` contains Macrobenchmark cold-start, warm-start, and inbox-scroll scenarios using release-like compilation. Run on a physical device or emulator after seeding 10,000 debug messages:

```bash
./gradlew --max-workers=2 --no-parallel --priority=low :benchmark:connectedCheck
```

No device measurements are recorded yet. Debug-frame timings are intentionally not treated as performance results. Measure Material, `TRANSPARENT`, `BLUR`, and `LIQUID` before selecting a default quality; downgrade when the 60 Hz frame budget is exceeded.

The P0 UI keeps scrolling mail rows on flat tonal surfaces; live glass remains bounded to floating chrome and the command palette. No 10,000-row device run or frame-time claim is made in this handoff.

Current environment blocker: packaging the benchmark target requires a JDK that contains `jlink`; the configured Java 21 directory does not.
