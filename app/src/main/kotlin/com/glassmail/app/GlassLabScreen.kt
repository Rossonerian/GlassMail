@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.glassmail.app

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Speed
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.glassmail.designsystem.GlassRadius
import com.glassmail.designsystem.GlassSpacing
import com.glassmail.designsystem.glass.BackdropSource
import com.glassmail.designsystem.glass.GlassMaterial
import com.glassmail.designsystem.glass.GlassPresets
import com.glassmail.designsystem.glass.GlassQuality
import com.glassmail.designsystem.glass.GlassSurface
import com.glassmail.designsystem.glass.GlassTier
import com.glassmail.designsystem.glass.LocalGlassPreferences

enum class LabPreset(val title: String, val material: GlassMaterial) {
    Capsule("Capsule", GlassPresets.Toolbar),
    FloatingDock("Dock", GlassPresets.BottomBar),
    Navigation("Navigation", GlassPresets.Navigation),
    ModalDialog("Modal", GlassPresets.Dialog),
    ActionSheet("Sheet", GlassPresets.Sheet),
}

enum class LabBackdrop(val title: String) {
    Vibrant("Art Gradient"),
    DenseText("Dense Text"),
    Grid("Geometric Grid"),
    Oled("OLED Pure Black"),
}

@Composable
fun GlassLabScreen(
    quality: GlassQuality,
    back: () -> Unit,
    modifier: Modifier = Modifier,
) {
    BackHandler(onBack = back)

    var selectedPreset by remember { mutableStateOf(LabPreset.FloatingDock) }
    var selectedBackdrop by remember { mutableStateOf(LabBackdrop.Vibrant) }

    // Live custom optical parameters
    var blurRadius by remember { mutableFloatStateOf(selectedPreset.material.blur.value) }
    var refraction by remember { mutableFloatStateOf(selectedPreset.material.refraction) }
    var dispersion by remember { mutableFloatStateOf(selectedPreset.material.dispersion) }
    var rimLight by remember { mutableFloatStateOf(selectedPreset.material.rimLight) }
    var specularIntensity by remember { mutableFloatStateOf(selectedPreset.material.specularIntensity) }
    var specularAngle by remember { mutableFloatStateOf(selectedPreset.material.specularAngle) }
    var luminanceAdaptation by remember { mutableFloatStateOf(selectedPreset.material.luminanceAdaptation) }
    var opacity by remember { mutableFloatStateOf(selectedPreset.material.opacity) }
    var cornerRadius by remember { mutableFloatStateOf(selectedPreset.material.cornerRadius.value) }

    // Synchronize sliders when preset is changed
    fun applyPreset(preset: LabPreset) {
        selectedPreset = preset
        val m = preset.material
        blurRadius = m.blur.value
        refraction = m.refraction
        dispersion = m.dispersion
        rimLight = m.rimLight
        specularIntensity = m.specularIntensity
        specularAngle = m.specularAngle
        luminanceAdaptation = m.luminanceAdaptation
        opacity = m.opacity
        cornerRadius = m.cornerRadius.value
    }

    val activeMaterial = remember(
        blurRadius, refraction, dispersion, rimLight, specularIntensity,
        specularAngle, luminanceAdaptation, opacity, cornerRadius,
    ) {
        GlassMaterial(
            blur = blurRadius.dp,
            refraction = refraction,
            dispersion = dispersion,
            rimLight = rimLight,
            specularIntensity = specularIntensity,
            specularAngle = specularAngle,
            luminanceAdaptation = luminanceAdaptation,
            opacity = opacity,
            cornerRadius = cornerRadius.dp,
        )
    }

    // Frame timing diagnostic (throttled to avoid continuous 100% recomposition overhead)
    var lastFrameDeltaMs by remember { mutableLongStateOf(16L) }
    LaunchedEffect(Unit) {
        var lastTime = 0L
        var lastUpdate = 0L
        while (true) {
            withFrameMillis { now ->
                if (lastTime > 0L) {
                    val delta = (now - lastTime).coerceIn(1L, 100L)
                    if (now - lastUpdate >= 500L) {
                        lastFrameDeltaMs = delta
                        lastUpdate = now
                    }
                }
                lastTime = now
            }
        }
    }

    Scaffold(
        topBar = {
            GlassMailTopCapsule(
                title = "Glass Optical Lab",
                subtitle = "AGSL GPU Shader Sandbox · Quality: $quality",
                quality = quality,
                navigationIcon = {
                    IconButton(onClick = back) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { applyPreset(selectedPreset) }) {
                        Icon(Icons.Outlined.Refresh, contentDescription = "Reset to preset defaults")
                    }
                },
            )
        },
        contentWindowInsets = WindowInsets(0),
        modifier = modifier.fillMaxSize(),
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .navigationBarsPadding(),
            contentPadding = PaddingValues(horizontal = GlassSpacing.base, vertical = GlassSpacing.md),
            verticalArrangement = Arrangement.spacedBy(GlassSpacing.lg),
        ) {
            // Section 1: Live Interactive Viewport with selected Backdrop
            item {
                Text(
                    "OPTICAL VIEWPORT & SAMPLE",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.primary,
                )
                Spacer(Modifier.height(GlassSpacing.xs))
                val labBackdropLayer = rememberGraphicsLayer()
                var labOffset by remember { mutableStateOf(Offset.Zero) }
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(260.dp)
                        .clip(RoundedCornerShape(GlassRadius.card))
                        .border(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f), RoundedCornerShape(GlassRadius.card))
                        .onGloballyPositioned { coords ->
                            val b = coords.boundsInWindow()
                            labOffset = Offset(b.left, b.top)
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    // Isolated backdrop layer recorded without self-sampling recursion
                    Box(
                        modifier = Modifier
                            .matchParentSize()
                            .drawWithContent {
                                labBackdropLayer.record {
                                    this@drawWithContent.drawContent()
                                }
                                drawLayer(labBackdropLayer)
                            },
                    ) {
                        LabBackdropSurface(selectedBackdrop)
                    }

                    // Glass Surface Floating over the Backdrop
                    GlassSurface(
                        material = activeMaterial,
                        shape = RoundedCornerShape(cornerRadius.dp),
                        tierOverride = when (quality) {
                            GlassQuality.FULL -> GlassTier.FULL
                            GlassQuality.BALANCED -> GlassTier.BALANCED
                            GlassQuality.LIGHT -> GlassTier.LIGHT
                            GlassQuality.OFF -> GlassTier.OFF
                        },
                        backdropSampling = true,
                        backdropSource = BackdropSource(layer = labBackdropLayer, providerOffsetInWindow = labOffset),
                        modifier = Modifier
                            .fillMaxWidth(0.85f)
                            .padding(GlassSpacing.base),
                    ) {
                        Column(
                            modifier = Modifier.padding(GlassSpacing.base),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(GlassSpacing.xs),
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(GlassSpacing.sm),
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(10.dp)
                                        .clip(CircleShape)
                                        .background(if (lastFrameDeltaMs <= 17L) Color(0xFF22C55E) else Color(0xFFF59E0B)),
                                )
                                Text(
                                    "${selectedPreset.title} Lens Sample",
                                    style = MaterialTheme.typography.titleMedium,
                                    color = MaterialTheme.colorScheme.onSurface,
                                )
                            }
                            Text(
                                "Live AGSL SDF Lens with Chromatic Refraction",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Row(
                                modifier = Modifier.padding(top = GlassSpacing.xs),
                                horizontalArrangement = Arrangement.spacedBy(GlassSpacing.md),
                            ) {
                                Text(
                                    "Frame: ${lastFrameDeltaMs}ms",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                                Text(
                                    "Blur: ${blurRadius.toInt()}dp",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                                Text(
                                    "Refr: ${(refraction * 100).toInt()}%",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
            }

            // Section 2: Backdrop Selection
            item {
                Text(
                    "TEST BACKDROP",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.primary,
                )
                Spacer(Modifier.height(GlassSpacing.xs))
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(GlassSpacing.sm),
                ) {
                    items(LabBackdrop.values()) { backdrop ->
                        FilterChip(
                            selected = selectedBackdrop == backdrop,
                            onClick = { selectedBackdrop = backdrop },
                            label = { Text(backdrop.title) },
                            leadingIcon = if (selectedBackdrop == backdrop) {
                                { Icon(Icons.Outlined.Check, contentDescription = null, modifier = Modifier.size(16.dp)) }
                            } else null,
                        )
                    }
                }
            }

            // Section 3: Preset Selector
            item {
                Text(
                    "MATERIAL PRESET",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.primary,
                )
                Spacer(Modifier.height(GlassSpacing.xs))
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(GlassSpacing.sm),
                ) {
                    items(LabPreset.values()) { preset ->
                        FilterChip(
                            selected = selectedPreset == preset,
                            onClick = { applyPreset(preset) },
                            label = { Text(preset.title) },
                            leadingIcon = if (selectedPreset == preset) {
                                { Icon(Icons.Outlined.Check, contentDescription = null, modifier = Modifier.size(16.dp)) }
                            } else null,
                        )
                    }
                }
            }

            // Section 4: Live Sliders & Tuners
            item {
                Text(
                    "OPTICAL PARAMETERS",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.primary,
                )
                Spacer(Modifier.height(GlassSpacing.xs))

                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(GlassRadius.md))
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f))
                        .padding(GlassSpacing.base),
                    verticalArrangement = Arrangement.spacedBy(GlassSpacing.md),
                ) {
                    LabSlider("Blur Radius", blurRadius, 0f, 64f, "${blurRadius.toInt()} dp") { blurRadius = it }
                    LabSlider("Refraction Strength", refraction, 0f, 1f, "${(refraction * 100).toInt()}%") { refraction = it }
                    LabSlider("Chromatic Dispersion", dispersion, 0f, 1f, "${(dispersion * 100).toInt()}%") { dispersion = it }
                    LabSlider("Ambient Rim Light", rimLight, 0f, 1f, "${(rimLight * 100).toInt()}%") { rimLight = it }
                    LabSlider("Specular Intensity", specularIntensity, 0f, 1f, "${(specularIntensity * 100).toInt()}%") { specularIntensity = it }
                    LabSlider("Specular Light Angle", specularAngle, 0f, 6.283f, "${Math.toDegrees(specularAngle.toDouble()).toInt()}°") { specularAngle = it }
                    LabSlider("Luminance Adaptation", luminanceAdaptation, 0f, 1f, "${(luminanceAdaptation * 100).toInt()}%") { luminanceAdaptation = it }
                    LabSlider("Surface Opacity", opacity, 0.05f, 0.95f, "${(opacity * 100).toInt()}%") { opacity = it }
                    LabSlider("Corner Radius", cornerRadius, 0f, 48f, "${cornerRadius.toInt()} dp") { cornerRadius = it }
                }
            }
        }
    }
}

@Composable
private fun LabSlider(
    label: String,
    value: Float,
    min: Float,
    max: Float,
    displayValue: String,
    onValueChange: (Float) -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface)
            Text(displayValue, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
        }
        Slider(
            value = value,
            onValueChange = onValueChange,
            valueRange = min..max,
            modifier = Modifier.fillMaxWidth(),
            colors = SliderDefaults.colors(
                thumbColor = MaterialTheme.colorScheme.primary,
                activeTrackColor = MaterialTheme.colorScheme.primary,
                inactiveTrackColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.25f),
            ),
        )
    }
}

@Composable
private fun LabBackdropSurface(backdrop: LabBackdrop) {
    when (backdrop) {
        LabBackdrop.Vibrant -> {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.sweepGradient(
                            listOf(
                                Color(0xFF38BDF8),
                                Color(0xFF818CF8),
                                Color(0xFFC084FC),
                                Color(0xFFF472B6),
                                Color(0xFFFB923C),
                                Color(0xFF38BDF8),
                            ),
                        ),
                    ),
            )
        }
        LabBackdrop.DenseText -> {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(GlassSpacing.sm),
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    repeat(12) { i ->
                        Text(
                            "Subject line item #$i — GlassMail local-first zero-copy rendering pipeline and Room persistence cache. High contrast typography verification underneath physical AGSL shader.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }
        }
        LabBackdrop.Grid -> {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color(0xFF0F172A)),
            ) {
                // Diagonal stripes / pattern
                CanvasBackdropGrid()
            }
        }
        LabBackdrop.Oled -> {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black),
            ) {
                Text(
                    "Pure #000000 OLED Canvas",
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White.copy(alpha = 0.4f),
                    modifier = Modifier.align(Alignment.BottomStart).padding(GlassSpacing.sm),
                )
            }
        }
    }
}

@Composable
private fun CanvasBackdropGrid() {
    androidx.compose.foundation.Canvas(modifier = Modifier.fillMaxSize()) {
        val step = 20.dp.toPx()
        var x = 0f
        while (x < size.width) {
            drawLine(
                color = Color.White.copy(alpha = 0.12f),
                start = androidx.compose.ui.geometry.Offset(x, 0f),
                end = androidx.compose.ui.geometry.Offset(x, size.height),
                strokeWidth = 1f,
            )
            x += step
        }
        var y = 0f
        while (y < size.height) {
            drawLine(
                color = Color.White.copy(alpha = 0.12f),
                start = androidx.compose.ui.geometry.Offset(0f, y),
                end = androidx.compose.ui.geometry.Offset(size.width, y),
                strokeWidth = 1f,
            )
            y += step
        }
    }
}
