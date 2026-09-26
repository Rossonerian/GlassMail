package com.glassmail.designsystem

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.glassmail.designsystem.glass.BackdropSource
import com.glassmail.designsystem.glass.GlassPresets
import com.glassmail.designsystem.glass.GlassQuality
import com.glassmail.designsystem.glass.GlassSurface
import com.glassmail.designsystem.glass.LocalGlassPreferences
import com.glassmail.designsystem.glass.LocalBackdropSource

/** Three always-visible actions with a spring lens that follows Square's continuous dock motion. */
@Composable
fun MorphingDock(
    selectedIndex: Int,
    quality: GlassQuality,
    onSelect: (Int) -> Unit,
    onCompose: () -> Unit,
    onInboxHold: () -> Unit = {},
    collapseFraction: () -> Float = { 0f },
    backdropSource: BackdropSource = LocalBackdropSource.current,
    modifier: Modifier = Modifier,
) {
    val reduceMotion = LocalGlassPreferences.current.reduceMotion
    val rawCollapse = collapseFraction().coerceIn(0f, 1f)
    val collapseProgress by animateFloatAsState(
        targetValue = if (reduceMotion) 0f else rawCollapse,
        animationSpec = spring(
            stiffness = Spring.StiffnessMediumLow,
            dampingRatio = 0.85f,
        ),
        label = "dockCollapseProgress",
    )
    val dockHeight by animateDpAsState(
        targetValue = androidx.compose.ui.unit.lerp(78.dp, 52.dp, collapseProgress),
        animationSpec = spring(
            stiffness = Spring.StiffnessMediumLow,
            dampingRatio = 0.85f,
        ),
        label = "dockHeight",
    )
    val dockWidth by animateDpAsState(
        targetValue = androidx.compose.ui.unit.lerp(356.dp, 216.dp, collapseProgress),
        animationSpec = spring(
            stiffness = Spring.StiffnessMediumLow,
            dampingRatio = 0.85f,
        ),
        label = "dockWidth",
    )
    val dockCornerRadius = androidx.compose.ui.unit.lerp(GlassRadius.dock, 26.dp, collapseProgress)
    val lensCornerRadius = androidx.compose.ui.unit.lerp(GlassRadius.innerLens, 20.dp, collapseProgress)

    Box(
        modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = 10.dp)
            .padding(bottom = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        GlassSurface(
            material = GlassPresets.Navigation.copy(
                opacity = 0.88f,
                tint = MaterialTheme.colorScheme.surface,
            ),
            tierOverride = quality,
            shape = RoundedCornerShape(dockCornerRadius),
            modifier = Modifier
                .width(dockWidth)
                .height(dockHeight),
            backdropSampling = true,
            backdropSource = backdropSource,
        ) {
            BoxWithConstraints(Modifier.fillMaxSize().padding(4.dp)) {
                val slotWidth = maxWidth / 3
                val lensTarget = if (selectedIndex == 1) maxWidth - slotWidth else 0.dp
                val lensOffset by animateDpAsState(
                    targetValue = lensTarget,
                    animationSpec = if (reduceMotion) tween(0) else spring(
                        stiffness = Spring.StiffnessMediumLow,
                        dampingRatio = 0.86f,
                    ),
                    label = "dockSelectionLens",
                )

                Box(
                    Modifier
                        .offset(x = lensOffset)
                        .width(slotWidth)
                        .fillMaxHeight()
                        .padding(2.dp)
                        .clip(RoundedCornerShape(lensCornerRadius))
                        .background(MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.82f)),
                )

                Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
                    DockTab(
                        label = "Inbox",
                        icon = Icons.Outlined.Inbox,
                        selected = selectedIndex == 0,
                        onClick = { onSelect(0) },
                        onLongClick = onInboxHold,
                        collapseProgress = collapseProgress,
                        modifier = Modifier.weight(1f),
                    )
                    ComposeAction(
                        onClick = onCompose,
                        collapseProgress = collapseProgress,
                        modifier = Modifier.weight(1f),
                    )
                    DockTab(
                        label = "Settings",
                        icon = Icons.Outlined.Settings,
                        selected = selectedIndex == 1,
                        onClick = { onSelect(1) },
                        collapseProgress = collapseProgress,
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

@Composable
@OptIn(ExperimentalFoundationApi::class)
private fun DockTab(
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    selected: Boolean,
    onClick: () -> Unit,
    onLongClick: (() -> Unit)? = null,
    collapseProgress: Float = 0f,
    modifier: Modifier = Modifier,
) {
    val labelHeight = ((1f - collapseProgress) * 16).dp
    Column(
        modifier = modifier
            .fillMaxHeight()
            .clip(RoundedCornerShape(GlassRadius.innerLens))
            .combinedClickable(
                onClick = onClick,
                onLongClick = onLongClick,
                onLongClickLabel = if (onLongClick == null) null else "Scroll to newest messages",
            )
            .semantics(mergeDescendants = true) {
                contentDescription = label
                role = Role.Tab
                this.selected = selected
                stateDescription = if (selected) "Selected" else "Not selected"
            },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = androidx.compose.foundation.layout.Arrangement.Center,
    ) {
        val iconBoxSize = androidx.compose.ui.unit.lerp(38.dp, 34.dp, collapseProgress)
        Box(Modifier.size(iconBoxSize), contentAlignment = Alignment.Center) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(24.dp),
                tint = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (collapseProgress < 0.98f) {
            Box(
                modifier = Modifier
                    .height(labelHeight)
                    .graphicsLayer {
                        alpha = (1f - collapseProgress * 2.2f).coerceIn(0f, 1f)
                    },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = label,
                    color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.labelSmall,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
private fun ComposeAction(
    onClick: () -> Unit,
    collapseProgress: Float = 0f,
    modifier: Modifier = Modifier,
) {
    val labelHeight = ((1f - collapseProgress) * 16).dp
    val composeCircleSize = androidx.compose.ui.unit.lerp(42.dp, 36.dp, collapseProgress)
    val composeIconSize = androidx.compose.ui.unit.lerp(22.dp, 20.dp, collapseProgress)
    Column(
        modifier = modifier
            .fillMaxHeight()
            .clickable(onClick = onClick)
            .semantics(mergeDescendants = true) {
                contentDescription = "Compose email"
                role = Role.Button
            },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = androidx.compose.foundation.layout.Arrangement.Center,
    ) {
        Box(
            modifier = Modifier
                .size(composeCircleSize)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.primary),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Outlined.Edit,
                contentDescription = null,
                modifier = Modifier.size(composeIconSize),
                tint = MaterialTheme.colorScheme.onPrimary,
            )
        }
        if (collapseProgress < 0.98f) {
            Box(
                modifier = Modifier
                    .height(labelHeight)
                    .graphicsLayer {
                        alpha = (1f - collapseProgress * 2.2f).coerceIn(0f, 1f)
                    },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "Compose",
                    color = MaterialTheme.colorScheme.primary,
                    style = MaterialTheme.typography.labelSmall,
                    maxLines = 1,
                )
            }
        }
    }
}
