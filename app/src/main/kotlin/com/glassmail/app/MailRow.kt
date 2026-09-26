package com.glassmail.app

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import com.glassmail.domain.mail.MailListItem
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Archive
import androidx.compose.material.icons.outlined.AttachFile
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material.icons.outlined.MarkEmailRead
import androidx.compose.material.icons.outlined.MarkEmailUnread
import androidx.compose.material.icons.outlined.MoreVert
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.glassmail.designsystem.GlassRadius
import com.glassmail.designsystem.GlassSpacing
import com.glassmail.designsystem.glass.GlassPresets
import com.glassmail.designsystem.glass.GlassSurface
import com.glassmail.designsystem.glass.GlassTier
import java.time.Instant
import java.time.ZoneId

/**
 * Minimalist, high-contrast liquid glass email list row.
 * Uses the LIGHT rendering tier for bounded per-surface blur cost during scrolling
 * when rendering 15+ cards on-screen simultaneously.
 */
@Composable
fun MailRow(
    row: MailListItem,
    open: (String) -> Unit,
    vm: AppViewModel,
    modifier: Modifier = Modifier,
) {
    var menuOpen by remember(row.messageId) { mutableStateOf(false) }
    val appearance by vm.appearance.collectAsStateWithLifecycle()
    val timestamp = remember(row.sentAtEpochMillis) { timeLabel(row.sentAtEpochMillis) }

    val displayName = remember(row.sender) { parseSenderDisplayName(row.sender) }

    GlassSurface(
        material = GlassPresets.Card,
        modifier = modifier.fillMaxWidth(),
        tierOverride = GlassTier.LIGHT,
        backdropSampling = false,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 80.dp)
                .pointerInput(row.messageId, appearance.shortSwipeLeft, appearance.longSwipeLeft, appearance.shortSwipeRight, appearance.longSwipeRight) {
                    var horizontalDistance = 0f
                    val shortThreshold = 64.dp.toPx()
                    val longThreshold = 144.dp.toPx()
                    detectHorizontalDragGestures(
                        onHorizontalDrag = { change, dragAmount ->
                            horizontalDistance += dragAmount
                            change.consume()
                        },
                        onDragEnd = {
                            val distance = horizontalDistance
                            horizontalDistance = 0f
                            val action = when {
                                distance <= -longThreshold -> appearance.longSwipeLeft
                                distance <= -shortThreshold -> appearance.shortSwipeLeft
                                distance >= longThreshold -> appearance.longSwipeRight
                                distance >= shortThreshold -> appearance.shortSwipeRight
                                else -> null
                            }
                            action?.let { vm.mutation(row, it.asMutationType()) }
                        },
                        onDragCancel = { horizontalDistance = 0f },
                    )
                }
                .clickable(
                    onClickLabel = "Open message",
                    onClick = { open(row.messageId) },
                )
                .padding(horizontal = GlassSpacing.base, vertical = GlassSpacing.md),
            horizontalArrangement = Arrangement.spacedBy(GlassSpacing.md),
            verticalAlignment = Alignment.Top,
        ) {
            // Unread subtle sage indicator dot
            Box(
                modifier = Modifier
                    .padding(top = 6.dp)
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(
                        if (row.unread) MaterialTheme.colorScheme.primary else Color.Transparent,
                    ),
            )

            // Message metadata and preview column
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(3.dp),
            ) {
                Text(
                    text = displayName,
                    style = MaterialTheme.typography.titleMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    color = if (row.unread) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = row.subject.ifBlank { "(No subject)" },
                    style = MaterialTheme.typography.titleSmall,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    color = if (row.unread) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
                )
                if (row.messageCount > 1) {
                    Text(
                        text = "${row.messageCount} messages · ${row.participantCount} participants",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
                if (row.preview.isNotBlank()) {
                    Text(
                        text = row.preview,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                val visibleLabel = row.labels.firstOrNull { !it.equals("INBOX", ignoreCase = true) }
                if (visibleLabel != null || row.hasAttachment) {
                    Row(
                        modifier = Modifier.padding(top = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(GlassSpacing.xs),
                    ) {
                        if (row.hasAttachment) {
                            Icon(
                                Icons.Outlined.AttachFile,
                                contentDescription = "Has attachment",
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(15.dp),
                            )
                        }
                        visibleLabel?.let { label ->
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(6.dp))
                                    .background(MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.6f))
                                    .padding(horizontal = 7.dp, vertical = 2.dp),
                            ) {
                                Text(
                                    text = label,
                                    style = MaterialTheme.typography.labelSmall,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                                )
                            }
                        }
                    }
                }
            }

            // Timestamp and actions column
            Column(
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = timestamp,
                    style = MaterialTheme.typography.labelSmall,
                    color = if (row.unread) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(
                        onClick = { vm.mutation(row, "star") },
                        modifier = Modifier.size(48.dp),
                    ) {
                        Icon(
                            if (row.starred) Icons.Outlined.Star else Icons.Outlined.StarBorder,
                            contentDescription = if (row.starred) "Unstar" else "Star",
                            tint = if (row.starred) Color(0xFFE5A93C) else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                            modifier = Modifier.size(20.dp),
                        )
                    }

                    Box {
                        IconButton(
                            onClick = { menuOpen = true },
                            modifier = Modifier.size(48.dp),
                        ) {
                            Icon(
                                Icons.Outlined.MoreVert,
                                contentDescription = "Message actions",
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(20.dp),
                            )
                        }

                        DropdownMenu(
                            expanded = menuOpen,
                            onDismissRequest = { menuOpen = false },
                        ) {
                            DropdownMenuItem(
                                text = { Text(if (row.unread) "Mark as read" else "Mark as unread") },
                                leadingIcon = {
                                    Icon(
                                        if (row.unread) Icons.Outlined.MarkEmailRead else Icons.Outlined.MarkEmailUnread,
                                        contentDescription = null,
                                    )
                                },
                                onClick = {
                                    menuOpen = false
                                    vm.mutation(row, "read")
                                },
                            )
                            DropdownMenuItem(
                                text = { Text(if (row.starred) "Unstar" else "Star") },
                                leadingIcon = {
                                    Icon(
                                        if (row.starred) Icons.Outlined.StarBorder else Icons.Outlined.Star,
                                        contentDescription = null,
                                    )
                                },
                                onClick = {
                                    menuOpen = false
                                    vm.mutation(row, "star")
                                },
                            )
                            DropdownMenuItem(
                                text = { Text("Archive") },
                                leadingIcon = { Icon(Icons.Outlined.Archive, contentDescription = null) },
                                onClick = {
                                    menuOpen = false
                                    vm.mutation(row, "archive")
                                },
                            )
                            DropdownMenuItem(
                                text = { Text("Delete", color = MaterialTheme.colorScheme.error) },
                                leadingIcon = { Icon(Icons.Outlined.DeleteOutline, contentDescription = null, tint = MaterialTheme.colorScheme.error) },
                                onClick = {
                                    menuOpen = false
                                    vm.mutation(row, "delete")
                                },
                            )
                        }
                    }
                }
            }
        }
    }
}

private fun SwipeAction.asMutationType(): String = when (this) {
    SwipeAction.MARK_READ -> "read"
    SwipeAction.ARCHIVE -> "archive"
    SwipeAction.DELETE -> "delete"
    SwipeAction.STAR -> "star"
}

fun timeLabel(epochMillis: Long?): String = epochMillis?.let {
    val zonedDateTime = Instant.ofEpochMilli(it).atZone(ZoneId.systemDefault())
    val today = java.time.LocalDate.now(ZoneId.systemDefault())
    val messageDate = zonedDateTime.toLocalDate()
    if (messageDate == today) {
        zonedDateTime.toLocalTime().toString().take(5)
    } else if (messageDate.year == today.year) {
        val formatter = java.time.format.DateTimeFormatter.ofPattern("MMM d", java.util.Locale.US)
        zonedDateTime.format(formatter)
    } else {
        val formatter = java.time.format.DateTimeFormatter.ofPattern("MM/dd/yy", java.util.Locale.US)
        zonedDateTime.format(formatter)
    }
} ?: "—"

fun parseSenderDisplayName(sender: String): String {
    if (sender.contains('<') && sender.contains('>')) {
        val name = sender.substringBefore('<').trim().removeSurrounding("\"").trim()
        if (name.isNotBlank()) return name
        val email = sender.substringAfter('<').substringBefore('>').trim()
        if (email.isNotBlank()) return email
    }
    return sender
}
