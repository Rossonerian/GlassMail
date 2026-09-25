@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.glassmail.app

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.Forward
import androidx.compose.material.icons.automirrored.outlined.Label
import androidx.compose.material.icons.automirrored.outlined.Reply
import androidx.compose.material.icons.automirrored.outlined.ReplyAll
import androidx.compose.material.icons.outlined.AttachFile
import androidx.compose.material.icons.outlined.MoreHoriz
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.glassmail.designsystem.GlassMailPalette
import com.glassmail.designsystem.GlassRadius
import com.glassmail.designsystem.GlassSpacing
import com.glassmail.designsystem.glass.GlassPresets
import com.glassmail.designsystem.glass.GlassQuality
import com.glassmail.designsystem.glass.GlassSurface
import com.glassmail.domain.mail.MailAccount
import com.glassmail.domain.mail.MailAttachment
import com.glassmail.domain.mail.MailDraft
import com.glassmail.domain.mail.MailMessage

@Composable
fun ReaderScreen(
    vm: AppViewModel,
    account: MailAccount?,
    id: String,
    quality: GlassQuality,
    back: () -> Unit,
    openPalette: () -> Unit,
    compose: (MailDraft) -> Unit,
    download: (MailAttachment) -> Unit,
    modifier: Modifier = Modifier,
) {
    BackHandler(onBack = back)
    LaunchedEffect(id) { vm.selectReaderMessage(id) }

    val state by vm.readerUiState.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()
    val collapsed by remember {
        derivedStateOf { listState.firstVisibleItemIndex > 0 || listState.firstVisibleItemScrollOffset > 160 }
    }
    val subject = state.selected?.subject?.ifBlank { "(No subject)" } ?: "Message"
    val decay by remember {
        derivedStateOf {
            if (listState.firstVisibleItemIndex > 0) 0f
            else (1f - listState.firstVisibleItemScrollOffset / 160f).coerceIn(0f, 1f)
        }
    }
    val readerTint = state.selected?.sender?.let(::senderAmbient) ?: Color.Transparent
    var labelDialogOpen by remember { mutableStateOf(false) }
    val appearance by vm.appearance.collectAsStateWithLifecycle()
    val isDark = when (appearance.theme) {
        ThemeChoice.DARK -> true
        ThemeChoice.LIGHT -> false
        ThemeChoice.SYSTEM -> isSystemInDarkTheme()
    }
    val neutral = if (isDark) GlassMailPalette.DarkBase else GlassMailPalette.LightBase
    val chroma = lerp(neutral, readerTint, decay * 0.08f)

    Scaffold(
        containerColor = chroma,
        topBar = {
            GlassMailTopCapsule(
                title = if (collapsed) subject else "Message",
                subtitle = if (collapsed) null else state.selected?.sender,
                quality = quality,
                navigationIcon = {
                    IconButton(onClick = back) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = openPalette) {
                        Icon(Icons.Outlined.MoreHoriz, contentDescription = "Open command palette")
                    }
                },
            )
        },
        bottomBar = {
            if (account != null && state.selected != null) {
                // Floating glass action bar for reading view
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .navigationBarsPadding()
                        .padding(horizontal = GlassSpacing.md, vertical = GlassSpacing.sm),
                    contentAlignment = Alignment.Center,
                ) {
                    GlassSurface(
                        material = GlassPresets.BottomBar.copy(cornerRadius = GlassRadius.dock, opacity = 0.42f),
                        shape = RoundedCornerShape(GlassRadius.dock),
                        backdropSampling = false,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(58.dp),
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(horizontal = GlassSpacing.sm),
                            horizontalArrangement = Arrangement.SpaceEvenly,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            TextButton(
                                onClick = { compose(replyDraft(state.selected!!, account, false)) },
                            ) {
                                Icon(Icons.AutoMirrored.Outlined.Reply, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(Modifier.width(GlassSpacing.xs))
                                Text("Reply", style = MaterialTheme.typography.labelLarge)
                            }

                            TextButton(
                                onClick = { compose(replyDraft(state.selected!!, account, true)) },
                            ) {
                                Icon(Icons.AutoMirrored.Outlined.ReplyAll, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(Modifier.width(GlassSpacing.xs))
                                Text("Reply all", style = MaterialTheme.typography.labelLarge)
                            }

                            TextButton(
                                onClick = { compose(forwardDraft(state.selected!!, account)) },
                            ) {
                                Icon(Icons.AutoMirrored.Outlined.Forward, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(Modifier.width(GlassSpacing.xs))
                                Text("Forward", style = MaterialTheme.typography.labelLarge)
                            }
                        }
                    }
                }
            }
        },
        modifier = modifier.fillMaxSize(),
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            state = listState,
            contentPadding = PaddingValues(start = GlassSpacing.md, end = GlassSpacing.md, top = GlassSpacing.md, bottom = if (account != null && state.selected != null) 110.dp else 24.dp),
            verticalArrangement = Arrangement.spacedBy(GlassSpacing.md),
        ) {
            val messages = state.thread.ifEmpty { listOfNotNull(state.selected) }
            items(
                items = messages,
                key = { it.messageId },
                contentType = { "threadMessage" },
            ) { item ->
                GlassSurface(
                    material = GlassPresets.Card,
                    tierOverride = com.glassmail.designsystem.glass.GlassTier.LIGHT,
                    backdropSampling = false,
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(GlassSpacing.lg),
                        verticalArrangement = Arrangement.spacedBy(GlassSpacing.md),
                    ) {
                    Text(
                        text = item.subject.ifBlank { "(No subject)" },
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.SemiBold),
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = item.sender,
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Text(
                            text = timeLabel(item.sentAtEpochMillis),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }

                    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))

                    // Message body with distraction-free typography and WCAG AAA contrast
                    Text(
                        text = item.body ?: item.preview,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.padding(vertical = GlassSpacing.xs),
                    )

                    // Attachments list
                    if (item.messageId == state.selected?.messageId && item.attachments.isNotEmpty()) {
                        Spacer(Modifier.height(GlassSpacing.xs))
                        Text(
                            "Attachments (${item.attachments.size})",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.primary,
                        )
                        item.attachments.forEach { attachment ->
                            ReaderAttachmentRow(attachment = attachment, onAction = download)
                        }
                    }

                    // Labels bar
                    if (item.messageId == state.selected?.messageId) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .heightIn(min = 48.dp)
                                .clip(RoundedCornerShape(GlassRadius.xs))
                                .clickable(
                                    role = androidx.compose.ui.semantics.Role.Button,
                                    onClickLabel = "Edit labels",
                                    onClick = { labelDialogOpen = true },
                                )
                                .padding(vertical = GlassSpacing.xs),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(GlassSpacing.xs),
                        ) {
                            Icon(Icons.AutoMirrored.Outlined.Label, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(16.dp))
                            Text("Labels:", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(
                                item.labels.filterNot { it.equals("INBOX", true) }.ifEmpty { listOf("None") }.joinToString(" · "),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.primary,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }

                    if (item.html) {
                        Text(
                            "Remote tracking content blocked · Rendered as safe plain text",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
                        )
                    }
                    }
                }
            }
        }
    }

    if (labelDialogOpen && state.selected != null) {
        val choices = (state.selected!!.labels + listOf("Work", "Travel", "Personal", "Follow Up")).distinct()
        AlertDialog(
            onDismissRequest = { labelDialogOpen = false },
            title = { Text("Message Labels") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(GlassSpacing.xs)) {
                    choices.forEach { label ->
                        val applied = label in state.selected!!.labels
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(8.dp))
                                .clickable { vm.setLabel(state.selected!!.messageId, label, !applied) }
                                .padding(horizontal = 12.dp, vertical = 8.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(label, style = MaterialTheme.typography.bodyMedium)
                            Text(
                                if (applied) "Remove" else "Add",
                                color = if (applied) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary,
                                style = MaterialTheme.typography.labelMedium,
                            )
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { labelDialogOpen = false }) {
                    Text("Done")
                }
            },
        )
    }
}

@Composable
private fun ReaderAttachmentRow(
    attachment: MailAttachment,
    onAction: (MailAttachment) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .clip(RoundedCornerShape(GlassRadius.md))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.42f))
            .padding(horizontal = GlassSpacing.md, vertical = GlassSpacing.xs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            Icons.Outlined.AttachFile,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(20.dp),
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = GlassSpacing.md),
        ) {
            Text(
                attachment.fileName ?: "Attachment",
                style = MaterialTheme.typography.titleSmall,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                attachment.mimeType ?: "application/octet-stream",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        OutlinedButton(
            onClick = { onAction(attachment) },
            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp),
        ) {
            Text(if (attachment.downloadState == "AVAILABLE") "Open" else "Download")
        }
    }
}
