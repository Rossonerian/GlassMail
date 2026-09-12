package com.glassmail.designsystem.glass

import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.asComposeRenderEffect
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.unit.IntSize
import android.graphics.RenderEffect
import android.graphics.RuntimeShader
import android.graphics.Shader
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring

/** Public quality contract. The renderer is deliberately isolated from feature modules. */
enum class GlassQuality { LIQUID, BLUR, TRANSPARENT }

/** Applies tactile press compression outside the shader so interaction remains cheap and predictable. */
@Composable
fun Modifier.glassPress(interactionSource: MutableInteractionSource): Modifier {
    val pressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) .975f else 1f,
        animationSpec = spring(stiffness = 700f, dampingRatio = .72f),
        label = "glassPressScale",
    )
    return graphicsLayer {
        scaleX = scale
        scaleY = scale
        translationY = if (pressed) 1.5f else 0f
    }
}

@Composable
fun GlassSurface(
    quality: GlassQuality,
    modifier: Modifier = Modifier,
    shape: Shape = RectangleShape,
    content: @Composable BoxScope.() -> Unit,
) {
    // RuntimeShader compilation is device/driver-dependent. A material failure must never
    // take down the application route using it; null selects the transparent fallback.
    val shader = androidx.compose.runtime.remember(quality) {
        if (quality != GlassQuality.LIQUID) {
            null
        } else {
            runCatching { RuntimeShader(LENS_SHADER) }
                .onFailure { error ->
                    Log.w(GLASS_LOG_TAG, "LIQUID shader unavailable; using transparent material", error)
                }
                .getOrNull()
        }
    }
    var size by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf(IntSize.Zero) }
    val tint = when (quality) {
        GlassQuality.LIQUID -> Color.White.copy(alpha = .18f)
        GlassQuality.BLUR -> Color.White.copy(alpha = .14f)
        GlassQuality.TRANSPARENT -> Color.White.copy(alpha = .08f)
    }
    val effect = androidx.compose.runtime.remember(quality, size, shader) {
        runCatching {
            when (quality) {
                GlassQuality.LIQUID -> if (size == IntSize.Zero || shader == null) null else {
                    shader.setFloatUniform("resolution", size.width.toFloat(), size.height.toFloat())
                    RenderEffect.createRuntimeShaderEffect(shader, "content").asComposeRenderEffect()
                }
                GlassQuality.BLUR -> RenderEffect.createBlurEffect(18f, 18f, Shader.TileMode.CLAMP).asComposeRenderEffect()
                GlassQuality.TRANSPARENT -> null
            }
        }.onFailure { error ->
            Log.w(GLASS_LOG_TAG, "$quality effect unavailable; using transparent material", error)
        }.getOrNull()
    }
    Box(
        modifier
            .onSizeChanged { size = it }
            .graphicsLayer { renderEffect = effect }
            .clip(shape)
            .background(tint),
        content = content,
    )
}

// AGSL screen-space rounded-lens approximation. Android supplies the composited layer as content.
private const val LENS_SHADER = """
uniform shader content;
uniform float2 resolution;
float sdRoundRect(float2 p, float2 b, float r) { float2 q = abs(p) - b + r; return min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r; }
half4 main(float2 p) {
  float2 uv = p / resolution;
  float2 centered = p - resolution * .5;
  float d = sdRoundRect(centered, resolution * .5, min(resolution.x,resolution.y)*.12);
  float edge = smoothstep(24.0, 0.0, abs(d));
  // Android's AGSL implementation does not guarantee derivative intrinsics on every driver.
  // The normalized local position is a stable rounded-lens direction for this approximation.
  float2 normal = normalize(centered + float2(.0001, .0001));
  float2 refracted = p + normal * edge * 5.0;
  half4 sampled = content.eval(refracted);
  float rim = smoothstep(8.0, 0.0, abs(d));
  return sampled + half4(rim*.12, rim*.14, rim*.18, 0);
}
"""

private const val GLASS_LOG_TAG = "GlassMailGlass"
