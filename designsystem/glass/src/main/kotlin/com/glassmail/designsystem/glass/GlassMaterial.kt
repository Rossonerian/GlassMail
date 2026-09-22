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
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlin.math.roundToInt

/**
 * Rendering tiers bounding GPU shader cost based on device capability and accessibility settings.
 */
enum class GlassTier {
    /** Full optical pipeline: live backdrop + gaussian blur + AGSL refraction + dispersion + specular rim. */
    FULL,
    /** Balanced pipeline: live backdrop + blur + refraction + simplified highlight. */
    BALANCED,
    /** Lite pipeline: blur + tint + simplified rim without expensive dispersion. */
    LITE,
    /** Accessibility fallback: mostly opaque tonal surface with high contrast and no distortion. */
    ACCESSIBILITY,
}

/** Public quality contract preserved for backwards compatibility with preferences. */
enum class GlassQuality { AUTOMATIC, LIQUID, BLUR, TRANSPARENT }

data class GlassPreferences(
    val reduceTransparency: Boolean = false,
    val reduceMotion: Boolean = false,
    val preferredTier: GlassTier? = null,
)

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
 * Samples the live [BackdropSource] recorded by an enclosing [GlassProvider], applying
 * hardware-accelerated AGSL rounded-lens refraction, chromatic dispersion, and gaussian blur.
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
    val effectiveTier = when {
        preferences.reduceTransparency -> GlassTier.ACCESSIBILITY
        tierOverride != null -> tierOverride
        preferences.preferredTier != null -> preferences.preferredTier
        else -> GlassTier.FULL
    }

    val density = LocalDensity.current
    var surfaceBoundsInWindow by remember { mutableStateOf<androidx.compose.ui.geometry.Rect?>(null) }

    val liquidShader = remember(effectiveTier) {
        if (effectiveTier != GlassTier.FULL && effectiveTier != GlassTier.BALANCED) null
        else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            runCatching { RuntimeShader(PHYSICAL_LENS_SHADER) }
                .onFailure { Log.w(GLASS_LOG_TAG, "AGSL runtime shader failed to initialize", it) }
                .getOrNull()
        } else null
    }

    val surfaceWidthPx = surfaceBoundsInWindow?.width ?: 0f
    val surfaceHeightPx = surfaceBoundsInWindow?.height ?: 0f
    val cornerRadiusPx = with(density) { material.cornerRadius.toPx() }

    val resolvedTint = if (material.tint != Color.Unspecified) {
        material.tint.copy(alpha = material.opacity)
    } else {
        MaterialTheme.colorScheme.surface.copy(
            alpha = when (effectiveTier) {
                GlassTier.ACCESSIBILITY -> 0.98f
                GlassTier.LITE -> 0.68f
                GlassTier.BALANCED -> 0.54f
                GlassTier.FULL -> material.opacity
            },
        )
    }

    // Configure shader uniforms dynamically as layout geometry changes
    if (liquidShader != null && surfaceWidthPx > 0f && surfaceHeightPx > 0f) {
        liquidShader.setFloatUniform("resolution", surfaceWidthPx, surfaceHeightPx)
        liquidShader.setFloatUniform("cornerRadius", cornerRadiusPx)
        liquidShader.setFloatUniform("refraction", if (effectiveTier == GlassTier.FULL) material.refraction else material.refraction * 0.7f)
        liquidShader.setFloatUniform("dispersion", if (effectiveTier == GlassTier.FULL) material.dispersion else 0.0f)
        liquidShader.setFloatUniform("rimLight", material.rimLight)
        liquidShader.setFloatUniform("specularIntensity", material.specularIntensity)
        liquidShader.setFloatUniform("specularAngle", material.specularAngle)
        liquidShader.setFloatUniform("highlightFalloff", material.highlightFalloff)
        liquidShader.setFloatUniform(
            "tintColor",
            resolvedTint.red,
            resolvedTint.green,
            resolvedTint.blue,
            resolvedTint.alpha,
        )
        liquidShader.setFloatUniform("luminanceAdaptation", material.luminanceAdaptation)
    }

    val blurRadiusPx = with(density) { material.blur.toPx() }.coerceAtLeast(1f)
    val opticalRenderEffect = remember(effectiveTier, liquidShader, blurRadiusPx, surfaceWidthPx, surfaceHeightPx, material, resolvedTint) {
        if (effectiveTier == GlassTier.ACCESSIBILITY || surfaceWidthPx <= 0f || surfaceHeightPx <= 0f) null
        else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            runCatching {
                val blur = RenderEffect.createBlurEffect(blurRadiusPx, blurRadiusPx, Shader.TileMode.CLAMP)
                when (effectiveTier) {
                    GlassTier.FULL, GlassTier.BALANCED -> liquidShader?.let { shader ->
                        RenderEffect.createChainEffect(
                            RenderEffect.createRuntimeShaderEffect(shader, "content"),
                            blur,
                        ).asComposeRenderEffect()
                    } ?: blur.asComposeRenderEffect()
                    GlassTier.LITE -> blur.asComposeRenderEffect()
                    GlassTier.ACCESSIBILITY -> null
                }
            }.onFailure { Log.w(GLASS_LOG_TAG, "RenderEffect failed", it) }.getOrNull()
        } else null
    }

    val relativeOffset by remember(surfaceBoundsInWindow, backdropSource.providerOffsetInWindow) {
        derivedStateOf {
            val bounds = surfaceBoundsInWindow ?: return@derivedStateOf Offset.Zero
            Offset(
                x = bounds.left - backdropSource.providerOffsetInWindow.x,
                y = bounds.top - backdropSource.providerOffsetInWindow.y,
            )
        }
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
        if (effectiveTier != GlassTier.ACCESSIBILITY && backdropSampling && backdropSource.layer != null) {
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
        if (effectiveTier != GlassTier.ACCESSIBILITY) {
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
    val tier = when (quality) {
        GlassQuality.AUTOMATIC -> GlassTier.FULL
        GlassQuality.LIQUID -> GlassTier.FULL
        GlassQuality.BLUR -> GlassTier.LITE
        GlassQuality.TRANSPARENT -> GlassTier.ACCESSIBILITY
    }
    val material = when (quality) {
        GlassQuality.AUTOMATIC, GlassQuality.LIQUID -> GlassPresets.Toolbar
        GlassQuality.BLUR -> GlassPresets.Toolbar.copy(refraction = 0f, dispersion = 0f)
        GlassQuality.TRANSPARENT -> GlassPresets.Toolbar.copy(opacity = 0.78f, refraction = 0f, dispersion = 0f, blur = 0.dp)
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

// =========================================================================
// PHYSICAL AGSL SHADER IMPLEMENTATION (Phase 1)
// =========================================================================

private const val PHYSICAL_LENS_SHADER = """
uniform shader content;
uniform float2 resolution;
uniform float cornerRadius;
uniform float refraction;
uniform float dispersion;
uniform float rimLight;
uniform float specularIntensity;
uniform float specularAngle;
uniform float highlightFalloff;
uniform float4 tintColor;
uniform float luminanceAdaptation;

float roundedBoxSDF(float2 p, float2 size, float r) {
    float2 d = abs(p - size * 0.5) - size * 0.5 + float2(r, r);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - r;
}

half4 main(float2 p) {
    float r = clamp(cornerRadius, 0.0, min(resolution.x, resolution.y) * 0.5);
    float dist = roundedBoxSDF(p, resolution, r);

    // Discard pixels strictly outside rounded boundary
    if (dist > 1.5) {
        return half4(0.0);
    }

    // Edge proximity factor (smooth decay over 28px inward)
    float edgeDist = abs(dist);
    float edgeFactor = smoothstep(28.0, 0.0, edgeDist);

    // Directional vector away from center for physical lens distortion
    float2 center = resolution * 0.5;
    float2 fromCenter = p - center;
    float centerDist = length(fromCenter);
    float2 normal = normalize(fromCenter + float2(0.0001, 0.0001));

    // Refractive displacement magnitude (stronger near corners and perimeter)
    float dispMag = (edgeFactor * 0.75 + 0.25 * (centerDist / max(center.x, 1.0))) * refraction * 10.0;
    float2 dispVector = normal * dispMag;

    // Chromatic dispersion (per-channel chromatic offset)
    float dispAmount = dispersion * 3.0 * edgeFactor;
    float2 pR = clamp(p + dispVector + normal * dispAmount, float2(0.0), resolution);
    float2 pG = clamp(p + dispVector, float2(0.0), resolution);
    float2 pB = clamp(p + dispVector - normal * dispAmount, float2(0.0), resolution);

    half4 colorR = content.eval(pR);
    half4 colorG = content.eval(pG);
    half4 colorB = content.eval(pB);
    half4 baseColor = half4(colorR.r, colorG.g, colorB.b, colorG.a);

    // Environmental tint blend
    half3 tinted = mix(baseColor.rgb, tintColor.rgb, tintColor.a);

    // Dynamic luminance adaptation for contrast safety
    if (luminanceAdaptation > 0.0) {
        float lum = dot(baseColor.rgb, half3(0.2126, 0.7152, 0.0722));
        float adapt = (lum - 0.5) * luminanceAdaptation;
        tinted = clamp(tinted - half3(adapt * 0.12), 0.0, 1.0);
    }

    // Directional specular rim highlight
    float2 lightDir = float2(cos(specularAngle), sin(specularAngle));
    float rimAlignment = max(dot(-normal, lightDir), 0.0);
    float specular = pow(rimAlignment, max(highlightFalloff, 1.0)) * specularIntensity * edgeFactor;

    // Perimeter ambient rim glow
    float rim = edgeFactor * rimLight * 0.22;

    half3 finalRgb = tinted + half3(rim + specular);
    float alpha = smoothstep(1.0, -1.0, dist);
    return half4(finalRgb, baseColor.a * alpha);
}
"""

private const val GLASS_LOG_TAG = "GlassMailGlass"
