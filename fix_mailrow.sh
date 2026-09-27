cat << 'INNER_EOF' > app/src/main/kotlin/com/glassmail/app/MailRow.kt
package com.glassmail.app

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.glassmail.designsystem.GlassSpacing
import java.time.Instant
import java.time.ZoneId

@Composable
fun MailRow(
    row: InboxRow,
    vm: AppViewModel,
    preferences: AppearancePreferences,
    onNavigate: (String) -> Unit,
) {
    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { dismissValue ->
            when (dismissValue) {
                SwipeToDismissBoxValue.StartToEnd -> {
                    vm.mutation(row, preferences.swipeRightAction.asMutationType())
                    true
                }
                SwipeToDismissBoxValue.EndToStart -> {
                    vm.mutation(row, preferences.swipeLeftAction.asMutationType())
                    true
                }
                SwipeToDismissBoxValue.Settled -> false
            }
        },
    )

    SwipeToDismissBox(
        state = dismissState,
        enableDismissFromStartToEnd = true,
        enableDismissFromEndToStart = true,
        backgroundContent = {
            val direction = dismissState.dismissDirection
            val color by animateColorAsState(
                when (dismissState.targetValue) {
                    SwipeToDismissBoxValue.Settled -> MaterialTheme.colorScheme.surfaceVariant
                    SwipeToDismissBoxValue.StartToEnd -> when (preferences.swipeRightAction) {
                        SwipeAction.MARK_READ -> MaterialTheme.colorScheme.primaryContainer
                        SwipeAction.ARCHIVE -> Color(0xFF4CAF50)
                        SwipeAction.DELETE -> MaterialTheme.colorScheme.errorContainer
                        SwipeAction.STAR -> Color(0xFFFFF8E1)
                    }
                    SwipeToDismissBoxValue.EndToStart -> when (preferences.swipeLeftAction) {
                        SwipeAction.MARK_READ -> MaterialTheme.colorScheme.primaryContainer
                        SwipeAction.ARCHIVE -> Color(0xFF4CAF50)
                        SwipeAction.DELETE -> MaterialTheme.colorScheme.errorContainer
                        SwipeAction.STAR -> Color(0xFFFFF8E1)
                    }
                },
                label = "swipeColor",
            )
            val iconScale by animateFloatAsState(
                if (dismissState.targetValue == SwipeToDismissBoxValue.Settled) 0.8f else 1.2f,
                label = "swipeIconScale",
            )

            Box(
                Modifier.fillMaxSize().background(color).padding(horizontal = 24.dp),
                contentAlignment = when (direction) {
                    SwipeToDismissBoxValue.StartToEnd -> Alignment.CenterStart
                    SwipeToDismissBoxValue.EndToStart -> Alignment.CenterEnd
                    SwipeToDismissBoxValue.Settled -> Alignment.Center
                },
            ) {
                if (direction != SwipeToDismissBoxValue.Settled) {
                    val action = if (direction == SwipeToDismissBoxValue.StartToEnd) preferences.swipeRightAction else preferences.swipeLeftAction
                    val icon = when (action) {
                        SwipeAction.MARK_READ -> if (row.unread) Icons.Outlined.MarkEmailRead else Icons.Outlined.MarkEmailUnread
                        SwipeAction.ARCHIVE -> Icons.Outlined.Archive
                        SwipeAction.DELETE -> Icons.Outlined.DeleteOutline
                        SwipeAction.STAR -> if (row.starred) Icons.Outlined.StarBorder else Icons.Outlined.Star
                    }
                    val iconTint = when (action) {
                        SwipeAction.MARK_READ -> MaterialTheme.colorScheme.onPrimaryContainer
                        SwipeAction.ARCHIVE -> Color.White
                        SwipeAction.DELETE -> MaterialTheme.colorScheme.onErrorContainer
                        SwipeAction.STAR -> Color(0xFFF57F17)
                    }
                    Icon(
                        icon,
                        contentDescription = action.name,
                        modifier = Modifier.scale(iconScale),
                        tint = iconTint,
                    )
                }
            }
        },
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.surface)
                .clickable { onNavigate("reader/${row.id}") }
                .padding(horizontal = GlassSpacing.m, vertical = GlassSpacing.s),
            horizontalArrangement = Arrangement.spacedBy(GlassSpacing.m),
            verticalAlignment = Alignment.Top,
        ) {
            var menuOpen by remember { mutableStateOf(false) }
            val displayName = parseSenderDisplayName(row.sender ?: "Unknown")
            val timestamp = timeLabel(row.sentAtEpochMillis)

            // Unread indicator
            Box(
                modifier = Modifier
                    .padding(top = 8.dp)
                    .size(10.dp)
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

// ⚡ Bolt: Extracted DateTimeFormatter instances to static properties to prevent
// object allocation and pattern compilation overhead during list recomposition
private val sameYearFormatter = java.time.format.DateTimeFormatter.ofPattern("MMM d", java.util.Locale.US)
private val olderFormatter = java.time.format.DateTimeFormatter.ofPattern("MM/dd/yy", java.util.Locale.US)

fun timeLabel(epochMillis: Long?): String = epochMillis?.let {
    val zonedDateTime = Instant.ofEpochMilli(it).atZone(ZoneId.systemDefault())
    val today = java.time.LocalDate.now(ZoneId.systemDefault())
    val messageDate = zonedDateTime.toLocalDate()
    if (messageDate == today) {
        zonedDateTime.toLocalTime().toString().take(5)
    } else if (messageDate.year == today.year) {
        zonedDateTime.format(sameYearFormatter)
    } else {
        zonedDateTime.format(olderFormatter)
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
INNER_EOF
