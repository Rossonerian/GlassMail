package com.glassmail.designsystem.glass

import android.util.Log
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.layer.GraphicsLayer
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import java.util.concurrent.atomic.AtomicLong

/** One shared recorded background and its live window position. */
class BackdropSource(
    val layer: GraphicsLayer? = null,
    providerOffsetInWindow: Offset = Offset.Zero,
) {
    private val offsetState = mutableStateOf(providerOffsetInWindow)
    private val recordedFrameCount = AtomicLong(0)

    val providerOffsetInWindow: Offset get() = offsetState.value

    /** Diagnostic count; reading it does not participate in Compose invalidation. */
    val recaptureCount: Long get() = recordedFrameCount.get()

    internal fun updateProviderOffset(offset: Offset) {
        if (offsetState.value != offset) offsetState.value = offset
    }

    internal fun recordFrame() {
        val count = recordedFrameCount.incrementAndGet()
        if (Log.isLoggable(BACKDROP_LOG_TAG, Log.DEBUG)) {
            Log.d(BACKDROP_LOG_TAG, "backdrop recorded frame=$count")
        }
    }
}

private const val BACKDROP_LOG_TAG = "GlassBackdrop"

val LocalBackdropSource = staticCompositionLocalOf { BackdropSource() }

/** Identifies the layer currently being recorded so only self-sampling is disabled. */
val LocalBackdropCaptureSource = staticCompositionLocalOf<BackdropSource?> { null }

/**
 * Allocates the per-screen capture. Pass the returned object to both [BackdropProvider]
 * and any glass layers drawn above it. The same GraphicsLayer is shared by every sampler.
 */
@Composable
fun rememberGlassBackdrop(): BackdropSource {
    val layer = rememberGraphicsLayer()
    return remember(layer) { BackdropSource(layer) }
}

/** Records only this provider's content. Glass samplers must be placed in a sibling layer. */
@Composable
fun BackdropProvider(
    backdrop: BackdropSource,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val layer = requireNotNull(backdrop.layer) { "BackdropProvider requires a GraphicsLayer" }
    Box(
        modifier = modifier
            .onGloballyPositioned { coordinates ->
                val bounds = coordinates.boundsInWindow()
                backdrop.updateProviderOffset(Offset(bounds.left, bounds.top))
            }
            .drawWithContent {
                layer.record { this@drawWithContent.drawContent() }
                backdrop.recordFrame()
                drawLayer(layer)
            },
    ) {
        CompositionLocalProvider(
            LocalBackdropSource provides backdrop,
            LocalBackdropCaptureSource provides backdrop,
        ) {
            content()
        }
    }
}

/** Compatibility wrapper for screens that do not need to pass the source to a sibling. */
@Composable
fun GlassProvider(
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable () -> Unit,
) {
    if (!enabled) {
        content()
        return
    }
    val backdrop = rememberGlassBackdrop()
    BackdropProvider(backdrop = backdrop, modifier = modifier, content = content)
}
