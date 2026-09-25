package com.glassmail.designsystem.glass

import android.graphics.RenderEffect
import android.graphics.RuntimeShader
import android.graphics.Shader
import android.os.Build
import android.util.Log
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.asComposeRenderEffect
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlin.math.roundToInt

/** Selects one of the separately implemented glass rendering paths. */
enum class GlassQuality { FULL, BALANCED, LIGHT, OFF }

/** Kept as a source-compatible name for existing material call sites. */
typealias GlassTier = GlassQuality

data class GlassPreferences(
    val reduceTransparency: Boolean = false,
    val reduceMotion: Boolean = false,
    val preferredTier: GlassQuality? = null,
)

/** Resolve the requested tier before any platform-specific shader/effect is created. */
fun resolveGlassQuality(requested: GlassQuality, sdkInt: Int = Build.VERSION.SDK_INT): GlassQuality = when {
    sdkInt < Build.VERSION_CODES.S -> GlassQuality.OFF
    sdkInt < Build.VERSION_CODES.TIRAMISU && requested in setOf(GlassQuality.FULL, GlassQuality.BALANCED) -> GlassQuality.LIGHT
    else -> requested
}

val LocalGlassPreferences = staticCompositionLocalOf { GlassPreferences() }

/**
 * 14-parameter physical glass material model.
 */
data class GlassMaterial(
    val blur: Dp = 18.dp,
    val saturation: Float = 1.05f,
    val tint: Color = Color.Unspecified,
    val opacity: Float = 0.52f,
    val refraction: Float = 0.24f,
    val refractionHeight: Dp = 8.dp,
    val dispersion: Float = 0.16f,
    val rimLight: Float = 0.38f,
    val specularIntensity: Float = 0.46f,
    val specularAngle: Float = -0.785f, // ~ -45 degrees (upper-left key light)
    val highlightFalloff: Float = 4.0f,
    val shadow: Dp = 10.dp,
    val cornerRadius: Dp = 20.dp,
    val innerShadow: Dp = 0.dp,
    val interactionStrength: Float = 0.28f,
    val luminanceAdaptation: Float = 0.35f,
)

/** Named presets sharing a coherent optical and physical foundation. */
object GlassPresets {
    val Navigation = GlassMaterial(
        blur = 20.dp,
        opacity = 0.48f,
        refraction = 0.22f,
        dispersion = 0.14f,
        rimLight = 0.40f,
        specularIntensity = 0.45f,
        shadow = 14.dp,
        cornerRadius = 30.dp,
    )

    val Toolbar = GlassMaterial(
        blur = 16.dp,
        opacity = 0.50f,
        refraction = 0.18f,
        dispersion = 0.12f,
        rimLight = 0.35f,
        specularIntensity = 0.40f,
        shadow = 10.dp,
        cornerRadius = 20.dp,
    )

    val Search = GlassMaterial(
        blur = 16.dp,
        opacity = 0.46f,
        refraction = 0.20f,
        dispersion = 0.15f,
        rimLight = 0.36f,
        specularIntensity = 0.42f,
        shadow = 8.dp,
        cornerRadius = 16.dp,
    )

    val FloatingAction = GlassMaterial(
        blur = 24.dp,
        opacity = 0.54f,
        refraction = 0.32f,
        dispersion = 0.22f,
        rimLight = 0.48f,
        specularIntensity = 0.60f,
        shadow = 18.dp,
        cornerRadius = 28.dp,
    )

    val BottomBar = GlassMaterial(
        blur = 22.dp,
        opacity = 0.52f,
        refraction = 0.24f,
        dispersion = 0.16f,
        rimLight = 0.38f,
        specularIntensity = 0.44f,
        shadow = 16.dp,
        cornerRadius = 24.dp,
    )

    val Sheet = GlassMaterial(
        blur = 28.dp,
        opacity = 0.62f,
        refraction = 0.26f,
        dispersion = 0.18f,
        rimLight = 0.42f,
        specularIntensity = 0.48f,
        shadow = 24.dp,
        cornerRadius = 28.dp,
    )

    val Dialog = GlassMaterial(
        blur = 26.dp,
        opacity = 0.65f,
        refraction = 0.28f,
        dispersion = 0.20f,
        rimLight = 0.45f,
        specularIntensity = 0.50f,
        shadow = 22.dp,
        cornerRadius = 24.dp,
    )

    val Menu = GlassMaterial(
        blur = 18.dp,
        opacity = 0.60f,
        refraction = 0.20f,
        dispersion = 0.12f,
        rimLight = 0.34f,
        specularIntensity = 0.38f,
        shadow = 12.dp,
        cornerRadius = 14.dp,
    )

    val Card = GlassMaterial(
        blur = 12.dp,
        opacity = 0.25f,
        refraction = 0.12f,
        dispersion = 0.08f,
        rimLight = 0.25f,
        specularIntensity = 0.30f,
        shadow = 4.dp,
        cornerRadius = 16.dp,
    )

    val ReaderChrome = GlassMaterial(
        blur = 18.dp,
        opacity = 0.50f,
        refraction = 0.16f,
        dispersion = 0.10f,
        rimLight = 0.32f,
        specularIntensity = 0.35f,
        shadow = 12.dp,
        cornerRadius = 24.dp,
    )

    val ComposeChrome = GlassMaterial(
        blur = 18.dp,
        opacity = 0.50f,
        refraction = 0.16f,
        dispersion = 0.10f,
        rimLight = 0.32f,
        specularIntensity = 0.35f,
        shadow = 12.dp,
        cornerRadius = 20.dp,
    )
}

/**
 * Applies tactile press compression outside the optical layer.
 */
@Composable
fun Modifier.glassPress(
    interactionSource: MutableInteractionSource,
    compressionScale: Float = 0.975f,
): Modifier {
    val preferences = LocalGlassPreferences.current
    val pressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed && !preferences.reduceMotion) compressionScale else 1f,
        animationSpec = spring(stiffness = Spring.StiffnessMediumLow, dampingRatio = 0.76f),
        label = "glassPressScale",
    )
    return graphicsLayer {
        scaleX = scale
        scaleY = scale
        translationY = if (pressed && !preferences.reduceMotion) 1.5f else 0f
    }
}

/**
 * Core optical glass surface.
 *
 * Samples the live [BackdropSource] recorded by a [BackdropProvider] in a separate draw layer,
 * applying hardware-accelerated AGSL rounded-lens refraction or the selected fallback.
 * Sharp content remains on the foreground layer without undergoing optical distortion.
 */
@Composable
fun GlassSurface(
    material: GlassMaterial,
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(material.cornerRadius),
    tierOverride: GlassTier? = null,
    backdropSampling: Boolean = true,
    backdropSource: BackdropSource = LocalBackdropSource.current,
    backdropKey: Any? = Unit,
    backdropFrozen: Boolean = false,
    content: @Composable BoxScope.() -> Unit,
) {
    val preferences = LocalGlassPreferences.current
    val requestedTier = when {
        preferences.reduceTransparency -> GlassQuality.OFF
        tierOverride != null -> tierOverride
        preferences.preferredTier != null -> preferences.preferredTier
        else -> GlassQuality.BALANCED
    }
    val platformTier = resolveGlassQuality(requestedTier)
    val samplingOwnCapture = LocalBackdropCaptureSource.current === backdropSource
    val density = LocalDensity.current
    val context = LocalContext.current
    var surfaceBoundsInWindow by remember { mutableStateOf<androidx.compose.ui.geometry.Rect?>(null) }

    val liquidShader = remember(platformTier, context) {
        val shaderResource = when (platformTier) {
            GlassQuality.FULL -> R.raw.glass_lens_full
            GlassQuality.BALANCED -> R.raw.glass_lens_balanced
            GlassQuality.LIGHT, GlassQuality.OFF -> null
        }
        if (shaderResource == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            null
        } else {
            runCatching {
                val source = context.resources.openRawResource(shaderResource).bufferedReader().use { it.readText() }
                RuntimeShader(source)
            }.onFailure { Log.w(GLASS_LOG_TAG, "AGSL runtime shader failed to initialize", it) }.getOrNull()
        }
    }

    val surfaceWidthPx = surfaceBoundsInWindow?.width ?: 0f
    val surfaceHeightPx = surfaceBoundsInWindow?.height ?: 0f
    val cornerRadiusPx = with(density) { material.cornerRadius.toPx() }
    val refractionHeightPx = with(density) { material.refractionHeight.toPx() }

    val effectiveTier = if (
        liquidShader == null && platformTier in setOf(GlassQuality.FULL, GlassQuality.BALANCED)
    ) GlassQuality.LIGHT else platformTier

    val resolvedTint = if (material.tint != Color.Unspecified) {
        material.tint.copy(alpha = material.opacity)
    } else {
        MaterialTheme.colorScheme.surface.copy(
            alpha = if (preferences.reduceTransparency) 0.98f else when (effectiveTier) {
                GlassQuality.OFF -> 0.78f
                GlassQuality.LIGHT -> 0.68f
                GlassQuality.BALANCED -> 0.54f
                GlassQuality.FULL -> material.opacity
            },
        )
    }

    val relativeOffset by remember(surfaceBoundsInWindow, backdropSource) {
        derivedStateOf {
            val bounds = surfaceBoundsInWindow ?: return@derivedStateOf Offset.Zero
            Offset(
                x = bounds.left - backdropSource.providerOffsetInWindow.x,
                y = bounds.top - backdropSource.providerOffsetInWindow.y,
            )
        }
    }

    // Uniform updates reuse the remembered RuntimeShader; pointer/material changes redraw this
    // glass surface without touching the provider's GraphicsLayer.
    if (liquidShader != null && surfaceWidthPx > 0f && surfaceHeightPx > 0f) {
        liquidShader.setFloatUniform("resolution", surfaceWidthPx, surfaceHeightPx)
        liquidShader.setFloatUniform("offset", relativeOffset.x, relativeOffset.y)
        liquidShader.setFloatUniform("cornerRadius", cornerRadiusPx)
        liquidShader.setFloatUniform("refractionHeight", refractionHeightPx * material.refraction.coerceAtLeast(0f))
        if (effectiveTier == GlassQuality.FULL) {
            liquidShader.setFloatUniform("chromaticAberrationStrength", material.dispersion.coerceAtLeast(0f))
        }
    }

    val blurRadiusPx = with(density) { material.blur.toPx() }.coerceAtLeast(1f)
    val opticalRenderEffect = remember(effectiveTier, liquidShader, blurRadiusPx, surfaceWidthPx, surfaceHeightPx) {
        if (surfaceWidthPx <= 0f || surfaceHeightPx <= 0f || effectiveTier == GlassQuality.OFF) {
            null
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            runCatching {
                val blur = RenderEffect.createBlurEffect(blurRadiusPx, blurRadiusPx, Shader.TileMode.CLAMP)
                when (effectiveTier) {
                    GlassQuality.FULL, GlassQuality.BALANCED -> {
                        val shader = requireNotNull(liquidShader)
                        RenderEffect.createChainEffect(
                            RenderEffect.createRuntimeShaderEffect(shader, "content"),
                            blur,
                        ).asComposeRenderEffect()
                    }
                    GlassQuality.LIGHT -> blur.asComposeRenderEffect()
                    GlassQuality.OFF -> null
                }
            }.onFailure { Log.w(GLASS_LOG_TAG, "RenderEffect failed; glass is using a flat tint", it) }.getOrNull()
        } else null
    }

    Box(
        modifier = modifier
            .onGloballyPositioned { coordinates ->
                surfaceBoundsInWindow = coordinates.boundsInWindow()
            }
            .shadow(
                elevation = if (preferences.reduceTransparency) 4.dp else material.shadow,
                shape = shape,
                clip = false,
            )
            .clip(shape)
            .border(
                width = 1.dp,
                color = MaterialTheme.colorScheme.onSurface.copy(
                    alpha = if (preferences.reduceTransparency) 0.18f else 0.14f,
                ),
                shape = shape,
            ),
    ) {
        // --- Live Optical Backdrop Layer ---
        if (!samplingOwnCapture && backdropSampling && backdropSource.layer != null && effectiveTier != GlassQuality.OFF) {
            Canvas(
                modifier = Modifier
                    .matchParentSize()
                    .graphicsLayer {
                        renderEffect = opticalRenderEffect
                    },
            ) {
                backdropSource.layer?.let { layer ->
                    translate(left = -relativeOffset.x, top = -relativeOffset.y) {
                        drawLayer(layer)
                    }
                }
            }
        }

        // --- Translucent Tint & Specular Gradients ---
        Box(
            Modifier
                .matchParentSize()
                .background(resolvedTint),
        )
        if (effectiveTier != GlassQuality.OFF) {
            Box(
                Modifier
                    .matchParentSize()
                    .background(
                        Brush.verticalGradient(
                            0.0f to Color.White.copy(alpha = 0.12f),
                            0.25f to Color.Transparent,
                            0.80f to Color.Transparent,
                            1.0f to Color.Black.copy(alpha = 0.08f),
                        ),
                    ),
            )
        }

        // --- Foreground Content Layer (Always Sharp) ---
        content()
    }
}

/**
 * Backwards-compatible overload mapping legacy [GlassQuality] to [GlassMaterial].
 */
@Composable
fun GlassSurface(
    quality: GlassQuality,
    modifier: Modifier = Modifier,
    shape: Shape = RectangleShape,
    backdropSampling: Boolean = false,
    backdropSource: BackdropSource = LocalBackdropSource.current,
    backdropKey: Any? = Unit,
    backdropFrozen: Boolean = false,
    content: @Composable BoxScope.() -> Unit,
) {
    val tier = quality
    val material = when (quality) {
        GlassQuality.FULL, GlassQuality.BALANCED -> GlassPresets.Toolbar
        GlassQuality.LIGHT -> GlassPresets.Toolbar.copy(refraction = 0f, dispersion = 0f)
        GlassQuality.OFF -> GlassPresets.Toolbar.copy(opacity = 0.78f, refraction = 0f, dispersion = 0f, blur = 0.dp)
    }
    GlassSurface(
        material = material,
        modifier = modifier,
        shape = shape,
        tierOverride = tier,
        backdropSampling = backdropSampling,
        backdropSource = backdropSource,
        backdropKey = backdropKey,
        backdropFrozen = backdropFrozen,
        content = content,
    )
}

// =========================================================================
// REUSABLE GLASS PRIMITIVES (Phase 2)
// =========================================================================

@Composable
fun GlassButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    material: GlassMaterial = GlassPresets.Toolbar.copy(cornerRadius = 14.dp),
    enabled: Boolean = true,
    interactionSource: MutableInteractionSource = remember { MutableInteractionSource() },
    content: @Composable RowScope.() -> Unit,
) {
    GlassSurface(
        material = material,
        modifier = modifier
            .glassPress(interactionSource)
            .clickable(
                enabled = enabled,
                interactionSource = interactionSource,
                indication = null,
                onClick = onClick,
            )
            .semantics { role = Role.Button },
        shape = RoundedCornerShape(material.cornerRadius),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            content = content,
        )
    }
}

@Composable
fun GlassIconButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    material: GlassMaterial = GlassPresets.Toolbar.copy(cornerRadius = 24.dp),
    enabled: Boolean = true,
    interactionSource: MutableInteractionSource = remember { MutableInteractionSource() },
    content: @Composable () -> Unit,
) {
    GlassSurface(
        material = material,
        modifier = modifier
            .size(44.dp)
            .glassPress(interactionSource)
            .clickable(
                enabled = enabled,
                interactionSource = interactionSource,
                indication = null,
                onClick = onClick,
            )
            .semantics { role = Role.Button },
        shape = CircleShape,
    ) {
        Box(Modifier.matchParentSize(), contentAlignment = Alignment.Center) {
            content()
        }
    }
}

@Composable
fun GlassToolbar(
    modifier: Modifier = Modifier,
    material: GlassMaterial = GlassPresets.Toolbar,
    content: @Composable RowScope.() -> Unit,
) {
    GlassSurface(
        material = material,
        modifier = modifier.fillMaxWidth().heightIn(min = 56.dp),
        shape = RoundedCornerShape(material.cornerRadius),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 56.dp)
                .padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            content = content,
        )
    }
}

@Composable
fun GlassBottomBar(
    modifier: Modifier = Modifier,
    material: GlassMaterial = GlassPresets.BottomBar,
    content: @Composable RowScope.() -> Unit,
) {
    GlassSurface(
        material = material,
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(topStart = material.cornerRadius, topEnd = material.cornerRadius),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            content = content,
        )
    }
}

@Composable
fun GlassSheet(
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    material: GlassMaterial = GlassPresets.Sheet,
    content: @Composable BoxScope.() -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.48f))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onDismiss,
            ),
        contentAlignment = Alignment.BottomCenter,
    ) {
        GlassSurface(
            material = material,
            modifier = modifier
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = {},
                ),
            shape = RoundedCornerShape(topStart = material.cornerRadius, topEnd = material.cornerRadius),
            content = content,
        )
    }
}

@Composable
fun GlassDialog(
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    material: GlassMaterial = GlassPresets.Dialog,
    content: @Composable BoxScope.() -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.52f))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onDismiss,
            ),
        contentAlignment = Alignment.Center,
    ) {
        GlassSurface(
            material = material,
            modifier = modifier
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = {},
                ),
            shape = RoundedCornerShape(material.cornerRadius),
            content = content,
        )
    }
}

@Composable
fun <T> GlassSegmentedControl(
    items: List<T>,
    selectedItem: T,
    onItemSelected: (T) -> Unit,
    modifier: Modifier = Modifier,
    labelProvider: (T) -> String = { it.toString() },
) {
    GlassSurface(
        material = GlassPresets.Toolbar.copy(cornerRadius = 14.dp, opacity = 0.38f),
        modifier = modifier.height(48.dp),
        shape = RoundedCornerShape(14.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            items.forEach { item ->
                val isSelected = item == selectedItem
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(40.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(
                            if (isSelected) MaterialTheme.colorScheme.primaryContainer else Color.Transparent,
                        )
                        .clickable { onItemSelected(item) }
                        .semantics {
                            role = Role.RadioButton
                            stateDescription = if (isSelected) "Selected" else "Not selected"
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = labelProvider(item),
                        style = MaterialTheme.typography.labelMedium,
                        color = if (isSelected) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}

@Composable
fun GlassSwitch(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    val preferences = LocalGlassPreferences.current
    val thumbOffset by animateFloatAsState(
        targetValue = if (checked) 22f else 2f,
        animationSpec = if (preferences.reduceMotion) spring() else spring(stiffness = Spring.StiffnessMedium, dampingRatio = 0.8f),
        label = "glassSwitchThumb",
    )
    Box(
        modifier = modifier
            .width(50.dp)
            .height(28.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(
                if (checked) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f),
            )
            .clickable { onCheckedChange(!checked) }
            .semantics {
                role = Role.Switch
                stateDescription = if (checked) "On" else "Off"
            }
            .padding(horizontal = 2.dp),
        contentAlignment = Alignment.CenterStart,
    ) {
        Box(
            modifier = Modifier
                .graphicsLayer { translationX = thumbOffset * density }
                .size(22.dp)
                .clip(CircleShape)
                .background(Color.White)
                .shadow(2.dp, CircleShape),
        )
    }
}

private const val GLASS_LOG_TAG = "GlassMailGlass"
