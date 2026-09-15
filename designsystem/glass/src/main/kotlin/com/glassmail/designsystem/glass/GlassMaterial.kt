package com.glassmail.designsystem.glass

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.graphics.Bitmap
import android.graphics.PixelCopy
import android.graphics.Rect
import android.graphics.RenderEffect
import android.graphics.RuntimeShader
import android.graphics.Shader
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Rect as ComposeRect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.asComposeRenderEffect
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import kotlin.math.roundToInt

/** Public quality contract. The renderer is deliberately isolated from feature modules. */
enum class GlassQuality { AUTOMATIC, LIQUID, BLUR, TRANSPARENT }

data class GlassPreferences(
    val reduceTransparency: Boolean = false,
    val reduceMotion: Boolean = false,
)

val LocalGlassPreferences = androidx.compose.runtime.staticCompositionLocalOf { GlassPreferences() }

/** Applies tactile press compression outside the optical layer. */
@Composable
fun Modifier.glassPress(interactionSource: MutableInteractionSource): Modifier {
    val preferences = LocalGlassPreferences.current
    val pressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed && !preferences.reduceMotion) .975f else 1f,
        animationSpec = spring(stiffness = 700f, dampingRatio = .72f),
        label = "glassPressScale",
    )
    return graphicsLayer {
        scaleX = scale
        scaleY = scale
        translationY = if (pressed) 1.5f else 0f
    }
}

/**
 * Bounded optical material. The sampled backdrop is a sibling below [content], therefore text,
 * icons and semantics remain sharp instead of being processed by blur/refraction.
 *
 * PixelCopy captures an equally sized rectangle immediately above the surface. It deliberately
 * avoids recursive self-capture and reuses one bitmap per surface geometry. Callers freeze
 * sampling during a fling and refresh once content settles.
 */
@Composable
fun GlassSurface(
    quality: GlassQuality,
    modifier: Modifier = Modifier,
    shape: Shape = RectangleShape,
    backdropSampling: Boolean = false,
    backdropKey: Any? = Unit,
    backdropFrozen: Boolean = false,
    content: @Composable BoxScope.() -> Unit,
) {
    val preferences = LocalGlassPreferences.current
    val requestedQuality = if (preferences.reduceTransparency) GlassQuality.TRANSPARENT else quality
    val preferredQuality = if (requestedQuality == GlassQuality.AUTOMATIC) GlassQuality.LIQUID else requestedQuality
    val liquidShader = remember(preferredQuality) {
        if (preferredQuality != GlassQuality.LIQUID) null
        else runCatching { RuntimeShader(LENS_SHADER) }
            .onFailure { Log.w(GLASS_LOG_TAG, "LIQUID shader unavailable; using blur", it) }
            .getOrNull()
    }
    val actualQuality = if (preferredQuality == GlassQuality.LIQUID && liquidShader == null) GlassQuality.BLUR else preferredQuality
    val view = LocalView.current
    val activity = remember(view.context) { view.context.findActivity() }
    var sourceRect by remember { mutableStateOf<Rect?>(null) }
    var sampleBitmap by remember { mutableStateOf<Bitmap?>(null) }
    var sampledBackdrop by remember { mutableStateOf<androidx.compose.ui.graphics.ImageBitmap?>(null) }
    var requestInFlight by remember { mutableStateOf(false) }
    val samplingEnabled = backdropSampling && actualQuality != GlassQuality.TRANSPARENT && !backdropFrozen && activity != null

    LaunchedEffect(samplingEnabled, sourceRect, backdropKey, actualQuality) {
        val rect = sourceRect ?: return@LaunchedEffect
        if (!samplingEnabled || requestInFlight || rect.width() <= 0 || rect.height() <= 0) return@LaunchedEffect
        val bitmap = sampleBitmap?.takeIf { it.width == rect.width() && it.height == rect.height() }
            ?: Bitmap.createBitmap(rect.width(), rect.height(), Bitmap.Config.ARGB_8888).also { sampleBitmap = it }
        requestInFlight = true
        runCatching {
            PixelCopy.request(activity!!.window, rect, bitmap, { result ->
                requestInFlight = false
                if (result == PixelCopy.SUCCESS) sampledBackdrop = bitmap.asImageBitmap()
            }, Handler(Looper.getMainLooper()))
        }.onFailure {
            requestInFlight = false
            Log.w(GLASS_LOG_TAG, "Bounded backdrop sample unavailable", it)
        }
    }

    val tint = when {
        preferences.reduceTransparency -> MaterialTheme.colorScheme.surface.copy(alpha = .98f)
        actualQuality == GlassQuality.LIQUID -> MaterialTheme.colorScheme.surface.copy(alpha = .48f)
        actualQuality == GlassQuality.BLUR -> MaterialTheme.colorScheme.surface.copy(alpha = .58f)
        else -> MaterialTheme.colorScheme.surface.copy(alpha = .78f)
    }
    val backdropEffect = remember(actualQuality, liquidShader, sampledBackdrop) {
        if (sampledBackdrop == null) null else runCatching {
            val blur = RenderEffect.createBlurEffect(14f, 14f, Shader.TileMode.CLAMP)
            when (actualQuality) {
                GlassQuality.LIQUID -> liquidShader?.let { shader ->
                    RenderEffect.createChainEffect(
                        RenderEffect.createRuntimeShaderEffect(shader, "content"),
                        blur,
                    ).asComposeRenderEffect()
                } ?: blur.asComposeRenderEffect()
                GlassQuality.BLUR -> blur.asComposeRenderEffect()
                GlassQuality.TRANSPARENT, GlassQuality.AUTOMATIC -> null
            }
        }.onFailure { Log.w(GLASS_LOG_TAG, "Backdrop effect unavailable; retaining sampled tint", it) }.getOrNull()
    }

    Box(
        modifier
            .onGloballyPositioned { coordinates ->
                if (!backdropSampling) return@onGloballyPositioned
                val bounds: ComposeRect = coordinates.boundsInWindow()
                val width = bounds.width.roundToInt().coerceAtLeast(1)
                val height = bounds.height.roundToInt().coerceAtLeast(1)
                val left = bounds.left.roundToInt().coerceAtLeast(0)
                val top = (bounds.top - height - 8.dp.value * view.resources.displayMetrics.density).roundToInt().coerceAtLeast(0)
                sourceRect = Rect(left, top, (left + width).coerceAtMost(view.width), (top + height).coerceAtMost(view.height))
            }
            .shadow(if (preferences.reduceTransparency) 8.dp else 18.dp, shape, clip = false)
            .clip(shape)
            .border(1.dp, MaterialTheme.colorScheme.onSurface.copy(alpha = if (preferences.reduceTransparency) .16f else .14f), shape),
    ) {
        // Backdrop layer — all optical work is contained here.
        Box(Modifier.fillMaxSize().background(tint)) {
            sampledBackdrop?.let { image ->
                Image(
                    bitmap = image,
                    contentDescription = null,
                    modifier = Modifier.fillMaxSize().graphicsLayer { renderEffect = backdropEffect },
                )
            }
            Box(Modifier.fillMaxSize().background(tint))
            Box(
                Modifier.fillMaxSize().background(
                    Brush.verticalGradient(
                        0f to Color.White.copy(alpha = if (preferences.reduceTransparency) .02f else .10f),
                        .20f to Color.Transparent,
                        1f to Color.Black.copy(alpha = if (preferences.reduceTransparency) .02f else .10f),
                    ),
                ),
            )
        }
        // Foreground layer — intentionally sharp.
        content()
    }
}

private fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

private const val LENS_SHADER = """
uniform shader content;
uniform float2 resolution;
float roundedEdge(float2 p, float2 size) {
  float2 c = p - size * .5;
  float2 q = abs(c) - size * .5 + min(size.x, size.y) * .28;
  float sd = min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - min(size.x, size.y) * .28;
  return smoothstep(30.0, 0.0, abs(sd));
}
half4 main(float2 p) {
  float2 center = p - resolution * .5;
  float distance = length(center) / max(min(resolution.x, resolution.y), 1.0);
  float edge = roundedEdge(p, resolution) * smoothstep(.48, .08, distance);
  float2 direction = normalize(center + float2(.001, .001));
  float2 refracted = p + direction * edge * 3.2;
  half4 color = content.eval(refracted);
  float luminance = dot(color.rgb, half3(.2126, .7152, .0722));
  color.rgb = mix(half3(luminance), color.rgb, 1.14);
  float highlight = edge * .10;
  color.rgb += half3(highlight * .78, highlight * .92, highlight);
  return color;
}
"""

private const val GLASS_LOG_TAG = "GlassMailGlass"
