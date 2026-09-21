package com.glassmail.app

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
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
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.glassmail.designsystem.GlassSpacing
import java.time.Instant
import java.time.ZoneId

/**
 * High-contrast, flat email list row.
 * In accordance with strict UI guidelines, message rows remain completely flat
 * and non-distorting for readability, while liquid glass is reserved for floating chrome.
 */
@Composable
fun MailRow(
    row: MailListItem,
    open: (String) -> Unit,
    vm: AppViewModel,
    modifier: Modifier = Modifier,
) {
    var menuOpen by remember(row.messageId) { mutableStateOf(false) }

    Column(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 76.dp)
                .clickable { open(row.messageId) }
                .padding(horizontal = GlassSpacing.md, vertical = GlassSpacing.sm),
            horizontalArrangement = Arrangement.spacedBy(GlassSpacing.md),
            verticalAlignment = Alignment.Top,
        ) {
            // Unread vertical accent indicator
            if (row.unread) {
                Box(
                    modifier = Modifier
                        .width(4.dp)
                        .height(48.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(MaterialTheme.colorScheme.primary),
                )
            } else {
                Spacer(modifier = Modifier.width(4.dp))
            }

            // Message metadata and preview column
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = row.sender,
                    style = if (row.unread) MaterialTheme.typography.titleMedium else MaterialTheme.typography.bodyMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    color = if (row.unread) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = row.subject.ifBlank { "(No subject)" },
                    style = if (row.unread) MaterialTheme.typography.bodyLarge else MaterialTheme.typography.bodyMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = row.preview,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )

                val visibleLabel = row.labels.firstOrNull { !it.equals("INBOX", ignoreCase = true) }
                if (visibleLabel != null || row.hasAttachment) {
                    Row(
                        modifier = Modifier.padding(top = 2.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(GlassSpacing.xs),
                    ) {
                        if (row.hasAttachment) {
                            Icon(
                                Icons.Outlined.AttachFile,
                                contentDescription = "Has attachment",
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(14.dp),
                            )
                        }
                        visibleLabel?.let { label ->
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(4.dp))
                                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f))
                                    .padding(horizontal = 6.dp, vertical = 2.dp),
                            ) {
                                Text(
                                    text = label,
                                    style = MaterialTheme.typography.labelSmall,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                    color = MaterialTheme.colorScheme.primary,
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
                    text = timeLabel(row.sentAtEpochMillis),
                    style = MaterialTheme.typography.labelSmall,
                    color = if (row.unread) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(
                        onClick = { vm.mutation(row, "star") },
                        modifier = Modifier.size(36.dp),
                    ) {
                        Icon(
                            if (row.starred) Icons.Outlined.Star else Icons.Outlined.StarBorder,
                            contentDescription = if (row.starred) "Unstar" else "Star",
                            tint = if (row.starred) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                            modifier = Modifier.size(18.dp),
                        )
                    }

                    Box {
                        IconButton(
                            onClick = { menuOpen = true },
                            modifier = Modifier.size(36.dp),
                        ) {
                            Icon(
                                Icons.Outlined.MoreVert,
                                contentDescription = "Message actions",
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(18.dp),
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
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f))
    }
}

fun timeLabel(epochMillis: Long?): String = epochMillis?.let {
    Instant.ofEpochMilli(it)
        .atZone(ZoneId.systemDefault())
        .toLocalTime()
        .toString()
        .take(5)
} ?: "—"
