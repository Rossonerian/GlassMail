package com.glassmail.app

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Search
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.glassmail.designsystem.GlassRadius
import com.glassmail.designsystem.GlassSpacing
import com.glassmail.designsystem.glass.GlassQuality
import com.glassmail.designsystem.glass.GlassSurface

@Composable
fun GlassMailTopCapsule(
    title: String,
    subtitle: String? = null,
    quality: GlassQuality,
    modifier: Modifier = Modifier,
    navigationIcon: (@Composable () -> Unit)? = null,
    actions: @Composable () -> Unit = {},
) {
    GlassSurface(
        quality = quality,
        modifier = modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(horizontal = GlassSpacing.md, vertical = GlassSpacing.xs),
        shape = RoundedCornerShape(GlassRadius.card),
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = 56.dp)
                .padding(horizontal = GlassSpacing.sm),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            CompositionLocalProvider(LocalContentColor provides MaterialTheme.colorScheme.onSurfaceVariant) {
                navigationIcon?.invoke()
            }
            Column(
                Modifier
                    .weight(1f)
                    .padding(horizontal = if (navigationIcon == null) GlassSpacing.sm else GlassSpacing.xs),
                verticalArrangement = Arrangement.Center,
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.SemiBold),
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                subtitle?.let {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            Row(
                horizontalArrangement = Arrangement.spacedBy(0.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                CompositionLocalProvider(LocalContentColor provides MaterialTheme.colorScheme.onSurfaceVariant) {
                    actions()
                }
            }
        }
    }
}

@Composable
fun GlassMailSearchCapsule(
    quality: GlassQuality,
    placeholder: String,
    onClick: () -> Unit,
    shortcut: String? = null,
    modifier: Modifier = Modifier,
) {
    GlassSurface(
        quality = quality,
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .semantics { role = Role.Button },
        shape = RoundedCornerShape(GlassRadius.lg),
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = GlassSpacing.base, vertical = GlassSpacing.md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Outlined.Search,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(20.dp),
            )
            Spacer(Modifier.width(GlassSpacing.md))
            Text(
                placeholder,
                Modifier.weight(1f),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            shortcut?.let {
                Text(
                    it,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.labelSmall,
                    modifier = Modifier.padding(start = GlassSpacing.sm),
                )
            }
        }
    }
}

@Composable
fun FlatMetadata(
    text: String,
    modifier: Modifier = Modifier,
    color: Color = MaterialTheme.colorScheme.onSurfaceVariant,
) {
    Text(
        text = text,
        modifier = modifier,
        color = color,
        style = MaterialTheme.typography.labelSmall,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
    )
}

fun senderAmbient(sender: String): Color = when ((sender.hashCode() and Int.MAX_VALUE) % 4) {
    0 -> com.glassmail.designsystem.GlassMailPalette.Personal.first
    1 -> com.glassmail.designsystem.GlassMailPalette.Work.first
    2 -> com.glassmail.designsystem.GlassMailPalette.Updates.first
    else -> com.glassmail.designsystem.GlassMailPalette.Newsletters.first
}

fun syncStatus(state: String): String = when (state.uppercase()) {
    "IDLE", "READY" -> "Synced · waiting for new mail"
    "CONNECTING" -> "Connecting to Gmail…"
    "SYNCING" -> "Syncing your mailbox…"
    "ERROR_AUTHENTICATION" -> "Google rejected the App Password. Update it in Settings, then sync again."
    "ERROR_NETWORK" -> "Could not reach Gmail. Check your connection and sync again."
    "ERROR_PROTOCOL" -> "Gmail returned an unexpected response. Check IMAP access and retry."
    "ERROR_MISSINGCREDENTIAL" -> "App Password is missing. Update it in Settings, then sync again."
    else -> when {
        state.contains("offline", ignoreCase = true) -> "Offline · showing cached mail"
        state.contains("network", ignoreCase = true) -> "Could not reach Gmail. Check your connection and sync again."
        state.startsWith("ERROR_", ignoreCase = true) -> "Sync failed. Check the account settings and retry."
        else -> "Waiting to sync your mailbox"
    }
}

fun replyDraft(
    message: com.glassmail.domain.mail.MailMessage,
    account: com.glassmail.domain.mail.MailAccount,
    all: Boolean,
): com.glassmail.domain.mail.MailDraft {
    val headers = com.glassmail.domain.mail.ReceivedMailHeaders(replyTo = listOf(message.sender), messageId = message.messageId)
    val recipients = if (all) com.glassmail.domain.mail.replyAllRecipients(headers, account.email) else com.glassmail.domain.mail.replyRecipients(message, account.email)
    return com.glassmail.domain.mail.MailDraft(
        java.util.UUID.randomUUID().toString(),
        account.accountId,
        to = recipients,
        subject = com.glassmail.domain.mail.replySubject(message.subject),
        body = "\n\n— Original message —\n${message.body ?: message.preview}",
        inReplyTo = message.messageId,
        references = com.glassmail.domain.mail.referencesForReply(message.messageId, headers.references),
    )
}

fun forwardDraft(
    message: com.glassmail.domain.mail.MailMessage,
    account: com.glassmail.domain.mail.MailAccount,
): com.glassmail.domain.mail.MailDraft = com.glassmail.domain.mail.MailDraft(
    java.util.UUID.randomUUID().toString(),
    account.accountId,
    subject = com.glassmail.domain.mail.forwardSubject(message.subject),
    body = "\n\n— Forwarded message —\nFrom: ${message.sender}\nSubject: ${message.subject}\n\n${message.body ?: message.preview}",
)
