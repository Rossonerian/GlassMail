package com.glassmail.designsystem

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import com.glassmail.designsystem.glass.GlassPresets
import com.glassmail.designsystem.glass.GlassQuality
import com.glassmail.designsystem.glass.GlassSurface
import com.glassmail.designsystem.glass.GlassTier
import com.glassmail.designsystem.glass.LocalGlassPreferences
import kotlin.math.roundToInt

private data class DockDestination(val label: String, val icon: androidx.compose.ui.graphics.vector.ImageVector)

/** One centered optical navigation object. Content beneath it is intentionally never boxed out. */
@Composable
fun MorphingDock(
    compact: Boolean,
    selectedIndex: Int,
    quality: GlassQuality,
    onSelect: (Int) -> Unit,
    onCompose: (() -> Unit)? = null,
    backdropKey: Any? = Unit,
    backdropFrozen: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val destinations = if (onCompose == null) {
        listOf(
            DockDestination("Inbox", Icons.Outlined.Inbox),
            DockDestination("Search", Icons.Outlined.Search),
            DockDestination("Settings", Icons.Outlined.Settings),
        )
    } else {
        listOf(
            DockDestination("Inbox", Icons.Outlined.Inbox),
            DockDestination("Search", Icons.Outlined.Search),
            DockDestination("Compose", Icons.Outlined.Edit),
            DockDestination("Settings", Icons.Outlined.Settings),
        )
    }
    val preferences = LocalGlassPreferences.current
    val width by animateDpAsState(
        targetValue = if (compact) 224.dp else 336.dp,
        animationSpec = if (preferences.reduceMotion) tween(100) else spring(stiffness = Spring.StiffnessMediumLow, dampingRatio = .86f),
        label = "floatingDockWidth",
    )
    var dragActive by remember { mutableStateOf(false) }
    var dragOffsetPx by remember { mutableFloatStateOf(0f) }
    var previewIndex by remember { mutableIntStateOf(selectedIndex) }
    val haptics = LocalHapticFeedback.current
    val density = LocalDensity.current

    LaunchedEffect(selectedIndex, dragActive) {
        if (!dragActive) previewIndex = selectedIndex
    }

    Box(
        modifier
            .navigationBarsPadding()
            .padding(bottom = 16.dp)
            .width(width)
            .height(60.dp),
        contentAlignment = Alignment.Center,
    ) {
        GlassSurface(
            material = GlassPresets.BottomBar.copy(cornerRadius = GlassRadius.dock),
            tierOverride = when (quality) {
                GlassQuality.AUTOMATIC -> GlassTier.BALANCED
                GlassQuality.LIQUID -> GlassTier.FULL
                GlassQuality.BLUR -> GlassTier.LITE
                GlassQuality.TRANSPARENT -> GlassTier.ACCESSIBILITY
            },
            shape = RoundedCornerShape(GlassRadius.dock),
            modifier = Modifier.fillMaxSize(),
            backdropSampling = true,
            backdropKey = backdropKey,
            backdropFrozen = backdropFrozen,
        ) {
            BoxWithConstraints(Modifier.fillMaxSize()) {
                val slotWidth = maxWidth / destinations.size
                val slotWidthPx = with(density) { slotWidth.toPx() }
                val maxLensOffset = (slotWidthPx * (destinations.size - 1)).coerceAtLeast(0f)
                val settledOffset by animateDpAsState(
                    targetValue = slotWidth * selectedIndex,
                    animationSpec = if (preferences.reduceMotion) tween(100) else GlassMotion.SpringDock,
                    label = "dockLensSlide",
                )
                val currentOffset = if (dragActive) with(density) { dragOffsetPx.toDp() } else settledOffset
                val draggableState = rememberDraggableState { delta ->
                    if (!dragActive) return@rememberDraggableState
                    dragOffsetPx = (dragOffsetPx + delta).coerceIn(0f, maxLensOffset)
                    val next = nearestDockIndex(dragOffsetPx, slotWidthPx, destinations.lastIndex)
                    if (next != previewIndex) {
                        previewIndex = next
                        if (!preferences.reduceMotion) haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    }
                }
                fun commit(index: Int) {
                    if (onCompose != null && index == 2) onCompose()
                    else onSelect(index)
                }
                Box(
                    Modifier.fillMaxSize()
                        .draggable(
                            state = draggableState,
                            orientation = Orientation.Horizontal,
                            startDragImmediately = false,
                            onDragStarted = {
                                dragActive = true
                                previewIndex = selectedIndex
                                dragOffsetPx = (slotWidthPx * selectedIndex).coerceIn(0f, maxLensOffset)
                            },
                            onDragStopped = {
                                val target = previewIndex
                                dragActive = false
                                if (target != selectedIndex) commit(target)
                            },
                        ),
                ) {
                    // A single physical lens moves inside the stable outer glass body.
                    Box(
                        Modifier.offset(x = currentOffset)
                            .width(slotWidth)
                            .fillMaxHeight()
                            .padding(5.dp)
                            .clip(RoundedCornerShape(GlassRadius.innerLens))
                            .background(MaterialTheme.colorScheme.primary.copy(alpha = if (dragActive) .24f else .18f)),
                    )
                    Row(Modifier.fillMaxSize()) {
                        destinations.forEachIndexed { index, destination ->
                            val visualActive = if (dragActive) index == previewIndex else index == selectedIndex
                            val iconScale by animateFloatAsState(
                                targetValue = if (visualActive) 1.06f else 1f,
                                animationSpec = if (preferences.reduceMotion) tween(80) else GlassMotion.SpringSubtle,
                                label = "dockIconScale$index",
                            )
                            Box(
                                Modifier.width(slotWidth).fillMaxHeight()
                                    .clickable { if (!dragActive && index != selectedIndex) commit(index) }
                                    .semantics {
                                        contentDescription = destination.label
                                        role = Role.Tab
                                        selected = index == selectedIndex
                                        stateDescription = if (index == selectedIndex) "Selected" else "Not selected"
                                    },
                                contentAlignment = Alignment.Center,
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(
                                        destination.icon,
                                        contentDescription = null,
                                        tint = if (visualActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.size(20.dp).scale(iconScale),
                                    )
                                    if (!compact && visualActive) {
                                        Text(
                                            destination.label,
                                            color = MaterialTheme.colorScheme.primary,
                                            style = MaterialTheme.typography.labelMedium,
                                            maxLines = 1,
                                            overflow = TextOverflow.Ellipsis,
                                            modifier = Modifier.padding(start = 4.dp),
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

internal fun nearestDockIndex(offsetPx: Float, slotWidthPx: Float, lastIndex: Int): Int =
    if (slotWidthPx <= 0f) 0 else (offsetPx / slotWidthPx).roundToInt().coerceIn(0, lastIndex)
