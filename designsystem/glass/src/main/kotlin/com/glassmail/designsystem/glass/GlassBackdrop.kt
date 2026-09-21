package com.glassmail.designsystem.glass

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.layer.GraphicsLayer
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned

/**
 * Encapsulates the live content layer recorded beneath glass surfaces.
 *
 * Glass surfaces read [layer] and sample it relative to [providerOffsetInWindow]
 * so optical effects (refraction, chromatic dispersion, blur) sample the exact
 * content behind each surface rather than an offset or duplicate view.
 */
data class BackdropSource(
    val layer: GraphicsLayer? = null,
    val providerOffsetInWindow: Offset = Offset.Zero,
    val updateKey: Long = 0L,
)

val LocalBackdropSource = staticCompositionLocalOf { BackdropSource() }

/**
 * Root optical container.
 *
 * Records the child content layer into a zero-copy Compose [GraphicsLayer]
 * using [Modifier.drawWithContent]. Floating chrome (top capsules, docks, sheets)
 * rendered outside the provider's recorded content layer can sample this layer
 * without recursive self-capture.
 */
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

    val graphicsLayer = rememberGraphicsLayer()
    var providerOffset by remember { mutableStateOf(Offset.Zero) }
    var updateCount by remember { mutableStateOf(0L) }

    Box(
        modifier = modifier
            .onGloballyPositioned { coordinates ->
                val bounds = coordinates.boundsInWindow()
                providerOffset = Offset(bounds.left, bounds.top)
            }
            .drawWithContent {
                graphicsLayer.record {
                    this@drawWithContent.drawContent()
                }
                drawLayer(graphicsLayer)
                updateCount++
            },
    ) {
        CompositionLocalProvider(
            LocalBackdropSource provides BackdropSource(
                layer = graphicsLayer,
                providerOffsetInWindow = providerOffset,
                updateKey = updateCount,
            ),
        ) {
            content()
        }
    }
}
