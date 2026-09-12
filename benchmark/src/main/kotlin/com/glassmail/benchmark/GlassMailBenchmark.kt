package com.glassmail.benchmark

import androidx.benchmark.macro.CompilationMode
import androidx.benchmark.macro.FrameTimingMetric
import androidx.benchmark.macro.MacrobenchmarkScope
import androidx.benchmark.macro.StartupMode
import androidx.benchmark.macro.StartupTimingMetric
import androidx.benchmark.macro.junit4.MacrobenchmarkRule
import org.junit.Rule
import org.junit.Test

class GlassMailBenchmark {
    @get:Rule val benchmarkRule = MacrobenchmarkRule()

    @Test fun coldStartup() = benchmarkRule.measureRepeated(
        packageName = "com.glassmail.app", metrics = listOf(StartupTimingMetric()),
        compilationMode = CompilationMode.Partial(), startupMode = StartupMode.COLD, iterations = 5,
    ) { pressHome(); startActivityAndWait() }

    @Test fun warmStartup() = benchmarkRule.measureRepeated(
        packageName = "com.glassmail.app", metrics = listOf(StartupTimingMetric()),
        compilationMode = CompilationMode.Partial(), startupMode = StartupMode.WARM, iterations = 5,
    ) { pressHome(); startActivityAndWait() }

    @Test fun inboxScroll() = benchmarkRule.measureRepeated(
        packageName = "com.glassmail.app", metrics = listOf(FrameTimingMetric()),
        compilationMode = CompilationMode.Partial(), startupMode = StartupMode.WARM, iterations = 5,
    ) { pressHome(); startActivityAndWait(); device.waitForIdle(); device.swipe(500, 1800, 500, 300, 300) }
}
