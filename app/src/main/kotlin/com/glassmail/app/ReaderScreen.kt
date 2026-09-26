@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.glassmail.app

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
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
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.ExpandMore
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
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import java.io.ByteArrayInputStream
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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.URL
import javax.net.ssl.HttpsURLConnection

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
    val messages = state.thread.ifEmpty { listOfNotNull(state.selected) }.map { message ->
        state.selected?.takeIf { it.messageId == message.messageId } ?: message
    }
    var expandedMessageKeys by rememberSaveable(id) { mutableStateOf("") }
    val expandedMessageIds = remember(expandedMessageKeys) { expandedMessageKeys.split('\n').filter(String::isNotBlank).toSet() }
    LaunchedEffect(messages.lastOrNull()?.messageId) {
        if (expandedMessageKeys.isBlank()) messages.lastOrNull()?.messageId?.let { expandedMessageKeys = it }
    }
    val participantCount = remember(messages) { messages.map { it.sender.lowercase() }.distinct().size.coerceAtLeast(1) }
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
    var threadActionsOpen by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val coroutineScope = androidx.compose.runtime.rememberCoroutineScope()
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
                title = if (collapsed) subject else "Conversation",
                subtitle = "${messages.size} ${if (messages.size == 1) "message" else "messages"} · $participantCount ${if (participantCount == 1) "participant" else "participants"}",
                quality = quality,
                navigationIcon = {
                    IconButton(onClick = back) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    Box {
                        IconButton(onClick = { threadActionsOpen = true }) {
                            Icon(Icons.Outlined.MoreHoriz, contentDescription = "Conversation actions")
                        }
                        DropdownMenu(expanded = threadActionsOpen, onDismissRequest = { threadActionsOpen = false }) {
                            DropdownMenuItem(text = { Text("Archive conversation") }, onClick = { threadActionsOpen = false; vm.threadMutation(messages.map { it.messageId }, "archive") })
                            DropdownMenuItem(text = { Text("Mute conversation") }, onClick = { threadActionsOpen = false; vm.threadMutation(messages.map { it.messageId }, "archive") })
                            DropdownMenuItem(text = { Text(if (messages.any { it.starred }) "Unstar conversation" else "Star conversation") }, onClick = { threadActionsOpen = false; vm.threadMutation(messages.map { it.messageId }, "star") })
                            DropdownMenuItem(text = { Text("Delete conversation", color = MaterialTheme.colorScheme.error) }, onClick = { threadActionsOpen = false; vm.threadMutation(messages.map { it.messageId }, "delete") })
                            DropdownMenuItem(text = { Text("Command palette") }, onClick = { threadActionsOpen = false; openPalette() })
                        }
                    }
                },
            )
        },
        bottomBar = {
            if (account != null && state.selected != null && !collapsed) {
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
            contentPadding = PaddingValues(start = 0.dp, end = 0.dp, top = GlassSpacing.md, bottom = if (account != null && state.selected != null && !collapsed) 110.dp else 24.dp),
            verticalArrangement = Arrangement.spacedBy(GlassSpacing.md),
        ) {
            items(
                items = messages,
                key = { it.messageId },
                contentType = { "threadMessage" },
            ) { item ->
                val expanded = item.messageId in expandedMessageIds
                val friendlyName = remember(item.sender) { parseSenderDisplayName(item.sender) }
                GlassSurface(
                    material = GlassPresets.Card,
                    tierOverride = com.glassmail.designsystem.glass.GlassTier.LIGHT,
                    backdropSampling = false,
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(GlassSpacing.md),
                        verticalArrangement = Arrangement.spacedBy(GlassSpacing.md),
                    ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(GlassRadius.md))
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                            ) {
                                expandedMessageKeys = (if (expanded) expandedMessageIds - item.messageId else expandedMessageIds + item.messageId).joinToString("\n")
                                if (!expanded && item.body == null) vm.loadMessageBody(item.messageId)
                            }
                            .padding(vertical = GlassSpacing.xs),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(friendlyName, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurface)
                            Text(
                                text = "${timeLabel(item.sentAtEpochMillis)} · ${item.subject.ifBlank { "(No subject)" }}",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                            if (!expanded && item.preview.isNotBlank()) {
                                Text(item.preview, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 2, overflow = TextOverflow.Ellipsis)
                            }
                        }
                        Icon(
                            if (expanded) Icons.Outlined.ExpandMore else Icons.Outlined.ChevronRight,
                            contentDescription = if (expanded) "Collapse message" else "Expand message",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    if (expanded) {
                    Text(
                        text = item.subject.ifBlank { "(No subject)" },
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.SemiBold),
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    val emailAddress = remember(item.sender) {
                        if (item.sender.contains('<') && item.sender.contains('>')) {
                            item.sender.substringAfter('<').substringBefore('>').trim()
                        } else null
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.Top,
                    ) {
                        Column(modifier = Modifier.weight(1f).padding(end = GlassSpacing.sm)) {
                            Text(
                                text = friendlyName,
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.onSurface,
                            )
                            if (emailAddress != null && emailAddress != friendlyName) {
                                Text(
                                    text = "<$emailAddress>",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                        Text(
                            text = timeLabel(item.sentAtEpochMillis),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }

                    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))

                    if (!item.listUnsubscribe.isNullOrBlank()) {
                        Row(
                            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(GlassRadius.md))
                                .background(MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.45f))
                                .padding(start = GlassSpacing.md, end = GlassSpacing.xs, top = GlassSpacing.xs, bottom = GlassSpacing.xs),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text("This looks like a newsletter.", Modifier.weight(1f), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurface)
                            TextButton(onClick = {
                                coroutineScope.launch {
                                    val result = runCatching { runUnsubscribe(context, item.listUnsubscribe.orEmpty(), item.listUnsubscribePost) }
                                    val message = when (result.getOrDefault(UnsubscribeResult.FAILED)) {
                                        UnsubscribeResult.REQUEST_SENT -> "Unsubscribe request sent"
                                        UnsubscribeResult.OPENED_EMAIL -> "Review and send the unsubscribe email"
                                        UnsubscribeResult.FAILED -> "Could not complete unsubscribe"
                                    }
                                    android.widget.Toast.makeText(context, message, android.widget.Toast.LENGTH_LONG).show()
                                }
                            }) { Text("Unsubscribe") }
                        }
                    }

                    // Message body with distraction-free typography and WCAG AAA contrast
                    val bodyContent = item.body ?: item.preview
                    if (bodyContent.isNotBlank() && item.html && item.body != null) {
                        HtmlMessageBody(
                            html = bodyContent,
                            textColor = MaterialTheme.colorScheme.onSurface.toArgb(),
                            modifier = Modifier.padding(vertical = GlassSpacing.xs),
                        )
                    } else if (bodyContent.isNotBlank()) {
                        Text(
                            text = bodyContent,
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.padding(vertical = GlassSpacing.xs),
                        )
                        if (item.body == null) {
                            Text(
                                text = "Loading complete message…",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.padding(top = GlassSpacing.xs),
                            )
                        }
                    } else {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = GlassSpacing.lg),
                            horizontalArrangement = Arrangement.spacedBy(GlassSpacing.sm),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            androidx.compose.material3.CircularProgressIndicator(
                                modifier = Modifier.size(18.dp),
                                strokeWidth = 2.dp,
                                color = MaterialTheme.colorScheme.primary,
                            )
                            Text(
                                text = "Loading message body…",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }

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

private enum class UnsubscribeResult { REQUEST_SENT, OPENED_EMAIL, FAILED }

private suspend fun runUnsubscribe(context: android.content.Context, header: String, postHeader: String?): UnsubscribeResult {
    val targets = Regex("<([^>]+)>").findAll(header).map { it.groupValues[1].trim() }.toList()
    val httpsTarget = targets.firstOrNull { it.startsWith("https://", ignoreCase = true) }
    if (httpsTarget != null && postHeader?.contains("list-unsubscribe=one-click", ignoreCase = true) == true) {
        return withContext(Dispatchers.IO) {
            val connection = URL(httpsTarget).openConnection() as? HttpsURLConnection ?: return@withContext UnsubscribeResult.FAILED
            try {
                connection.connectTimeout = 10_000
                connection.readTimeout = 10_000
                connection.instanceFollowRedirects = false
                connection.requestMethod = "POST"
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
                connection.setRequestProperty("User-Agent", "GlassMail/1.0")
                connection.outputStream.use { it.write("List-Unsubscribe=One-Click".toByteArray(Charsets.UTF_8)) }
                if (connection.responseCode in 200..299) UnsubscribeResult.REQUEST_SENT else UnsubscribeResult.FAILED
            } finally {
                connection.disconnect()
            }
        }
    }
    val mailtoTarget = targets.firstOrNull { it.startsWith("mailto:", ignoreCase = true) } ?: return UnsubscribeResult.FAILED
    val intent = android.content.Intent(android.content.Intent.ACTION_SENDTO, android.net.Uri.parse(mailtoTarget)).apply {
        putExtra(android.content.Intent.EXTRA_SUBJECT, "Unsubscribe")
        putExtra(android.content.Intent.EXTRA_TEXT, "Please unsubscribe me from this mailing list.")
        addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    return runCatching {
        context.startActivity(android.content.Intent.createChooser(intent, "Unsubscribe from this list").addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK))
        UnsubscribeResult.OPENED_EMAIL
    }.getOrDefault(UnsubscribeResult.FAILED)
}

@Composable
private fun HtmlMessageBody(
    html: String,
    textColor: Int,
    modifier: Modifier = Modifier,
) {
    val density = LocalDensity.current
    var measuredHeightDp by remember(html) { mutableIntStateOf(0) }
    val sanitized = remember(html) { stripTrackingPixels(html) }
    val documentKey = remember(html, textColor) { "$textColor:$html" }
    val document = remember(documentKey) {
        """
        <!doctype html>
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'; font-src data:;">
        <style>
          html, body { margin: 0; padding: 0; background: transparent; color: #${textColor.toUInt().toString(16).takeLast(6)}; }
          body { font: 16px/1.65 sans-serif; overflow-wrap: anywhere; }
          img { max-width: 100%; height: auto; }
          table { max-width: 100%; }
          pre { white-space: pre-wrap; }
        </style></head><body>${sanitized.first}</body></html>
        """.trimIndent()
    }
    Column(modifier = modifier.fillMaxWidth()) {
    AndroidView(
        factory = { context ->
            WebView(context).apply {
                setBackgroundColor(android.graphics.Color.TRANSPARENT)
                settings.javaScriptEnabled = false
                settings.blockNetworkLoads = true
                settings.loadsImagesAutomatically = false
                settings.allowFileAccess = false
                settings.allowContentAccess = false
                settings.domStorageEnabled = false
                settings.setSupportMultipleWindows(false)
                webViewClient = object : WebViewClient() {
                    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean = true

                    override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): android.webkit.WebResourceResponse? =
                        if (request.url.scheme == "data" || request.url.scheme == "about") null
                        else android.webkit.WebResourceResponse("text/plain", "UTF-8", ByteArrayInputStream(ByteArray(0)))

                    override fun onPageFinished(view: WebView, url: String?) {
                        view.evaluateJavascript("Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)") { result ->
                            val heightPx = result?.trim('"')?.toFloatOrNull()?.toInt() ?: return@evaluateJavascript
                            measuredHeightDp = (heightPx / density.density).toInt().coerceIn(120, 12_000)
                        }
                    }
                }
                tag = documentKey
                loadDataWithBaseURL("about:blank", document, "text/html", "UTF-8", null)
            }
        },
        update = { webView ->
            if (webView.tag != documentKey) {
                webView.tag = documentKey
                measuredHeightDp = 0
                webView.loadDataWithBaseURL("about:blank", document, "text/html", "UTF-8", null)
            }
        },
        modifier = Modifier
            .fillMaxWidth()
            .height((measuredHeightDp.takeIf { it > 0 } ?: 420).dp),
    )
        if (sanitized.second > 0) {
            Text(
                "${sanitized.second} tracking pixel${if (sanitized.second == 1) "" else "s"} blocked · remote images stay disabled",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(top = GlassSpacing.xs),
            )
        }
    }
}

private fun stripTrackingPixels(html: String): Pair<String, Int> {
    var count = 0
    val imageTag = Regex("<img\\b[^>]*>", RegexOption.IGNORE_CASE)
    val trackers = listOf("mailtrack", "open-tracking", "email-tracker", "pixel.gif", "track.gif", "analytics")
    val cleaned = imageTag.replace(html) { match ->
        val tag = match.value
        val width = Regex("\\bwidth\\s*=\\s*['\"]?(\\d+)", RegexOption.IGNORE_CASE).find(tag)?.groupValues?.get(1)?.toIntOrNull()
        val height = Regex("\\bheight\\s*=\\s*['\"]?(\\d+)", RegexOption.IGNORE_CASE).find(tag)?.groupValues?.get(1)?.toIntOrNull()
        val style = Regex("\\bstyle\\s*=\\s*['\"]([^'\"]*)['\"]", RegexOption.IGNORE_CASE).find(tag)?.groupValues?.get(1).orEmpty()
        val tinyStyle = Regex("(?:width|height)\\s*:\\s*[01](?:px|pt|em|rem)?", RegexOption.IGNORE_CASE).containsMatchIn(style)
        val source = Regex("\\bsrc\\s*=\\s*['\"]?([^'\"\\s>]+)", RegexOption.IGNORE_CASE).find(tag)?.groupValues?.get(1).orEmpty().lowercase()
        val tracker = width?.let { it <= 2 } == true || height?.let { it <= 2 } == true || tinyStyle || trackers.any { it in source }
        if (tracker) {
            count++
            ""
        } else tag
    }
    return cleaned to count
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
