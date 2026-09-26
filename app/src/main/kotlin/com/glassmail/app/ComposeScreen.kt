@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.glassmail.app

import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.background
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.Send
import androidx.compose.material.icons.outlined.AttachFile
import androidx.compose.material.icons.outlined.Close
import com.glassmail.designsystem.GlassRadius
import com.glassmail.designsystem.GlassSpacing
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.glassmail.domain.mail.DraftRepository
import com.glassmail.domain.mail.DraftAttachment
import com.glassmail.domain.mail.DraftStatus
import com.glassmail.domain.mail.MailAccount
import com.glassmail.domain.mail.MailDraft
import com.glassmail.domain.mail.MailSender
import com.glassmail.domain.mail.OutgoingMail
import com.glassmail.domain.mail.SendMailError
import com.glassmail.domain.mail.SendMailResult
import com.glassmail.domain.mail.normalizeAddresses
import com.glassmail.domain.mail.validateAddresses
import java.util.UUID
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay

@Composable
fun ComposeRoute(
    graph: AppGraph,
    account: MailAccount?,
    quality: com.glassmail.designsystem.glass.GlassQuality,
    draftId: String?,
    back: () -> Unit,
) {
    BackHandler(onBack = back)
    if (account == null) {
        androidx.compose.material3.Surface(
            modifier = Modifier.fillMaxSize(),
            color = MaterialTheme.colorScheme.background,
        ) {
            Column(Modifier.fillMaxSize().padding(24.dp)) {
                Text(
                    "No account is available for composing mail.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }
        }
        return
    }
    val vm: ComposeViewModel = androidx.lifecycle.viewmodel.compose.viewModel(
        key = draftId ?: "new",
        factory = ComposeViewModel.factory(graph.draftRepository, account, draftId, graph.context, graph.contentResolver, graph.appearancePreferences.read().sendDelaySeconds),
    )
    val state by vm.state.collectAsStateWithLifecycle()
    val draft = state.draft
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        val attachments = uris.mapNotNull { uri ->
            runCatching {
                graph.contentResolver.takePersistableUriPermission(uri, android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val name = graph.contentResolver.query(uri, arrayOf(android.provider.OpenableColumns.DISPLAY_NAME, android.provider.OpenableColumns.SIZE), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) to if (cursor.isNull(1)) -1L else cursor.getLong(1) else null
            } ?: ((uri.lastPathSegment ?: "attachment") to -1L)
            DraftAttachment(uri.toString(), name.first, graph.contentResolver.getType(uri) ?: "application/octet-stream", name.second)
        }
        vm.addAttachments(attachments)
    }
    var showCcBcc by rememberSaveable { mutableStateOf(state.rawCc.isNotBlank() || state.rawBcc.isNotBlank()) }

    Scaffold(
        topBar = {
            GlassMailTopCapsule(
                title = "Compose",
                subtitle = when (state.status) {
                    DraftStatus.QUEUED -> if (state.undoCountdownSeconds > 0) "Sending in ${state.undoCountdownSeconds}s · tap to undo" else "Sending…"
                    DraftStatus.SENDING -> "Sending…"
                    DraftStatus.SENT -> "Sent"
                    DraftStatus.FAILED -> "Send failed · draft saved"
                    DraftStatus.UNCERTAIN -> "Check Sent before retrying"
                    else -> "Draft saved locally"
                },
                quality = quality,
                navigationIcon = { IconButton(back) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Back") } },
                actions = {
                    Button(
                        enabled = state.status != DraftStatus.SENDING && state.status != DraftStatus.SENT && (state.status != DraftStatus.QUEUED || state.undoCountdownSeconds > 0),
                        onClick = if (state.status == DraftStatus.QUEUED) vm::cancelQueuedSend else vm::send,
                        shape = RoundedCornerShape(GlassRadius.innerLens),
                        colors = androidx.compose.material3.ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.primary,
                            contentColor = MaterialTheme.colorScheme.onPrimary,
                        ),
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 6.dp),
                    ) {
                        Icon(
                            Icons.AutoMirrored.Outlined.Send,
                            contentDescription = null,
                            modifier = Modifier.size(16.dp),
                        )
                        Spacer(Modifier.width(6.dp))
                        Text(
                            when {
                                state.status == DraftStatus.QUEUED && state.undoCountdownSeconds > 0 -> "Undo ${state.undoCountdownSeconds}"
                                state.status == DraftStatus.SENDING || state.status == DraftStatus.QUEUED -> "Sending…"
                                state.status == DraftStatus.SENT -> "Sent"
                                state.status == DraftStatus.FAILED -> "Try again"
                                state.status == DraftStatus.UNCERTAIN -> "Retry send"
                                else -> "Send"
                            },
                            style = MaterialTheme.typography.labelLarge,
                        )
                    }
                },
            )
        },
        contentWindowInsets = WindowInsets(0),
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .imePadding()
                .navigationBarsPadding()
                .padding(horizontal = 20.dp, vertical = 12.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(0.dp),
        ) {
            if (state.status == DraftStatus.QUEUED && state.undoCountdownSeconds > 0) {
                Row(
                    Modifier.fillMaxWidth().padding(bottom = 10.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                ) {
                    Text("Email will send in ${state.undoCountdownSeconds} seconds", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.primary)
                    OutlinedButton(onClick = vm::cancelQueuedSend) { Text("Undo send") }
                }
            }
            // Recipient field with inline Cc/Bcc toggle
            Column(Modifier.fillMaxWidth()) {
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(vertical = 4.dp),
                    verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                ) {
                    Text(
                        "To",
                        modifier = Modifier.width(56.dp),
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    BasicTextField(
                        value = state.rawTo,
                        onValueChange = vm::updateTo,
                        modifier = Modifier.weight(1f).semantics { contentDescription = "To" },
                        cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                        singleLine = true,
                        textStyle = MaterialTheme.typography.bodyLarge.copy(color = MaterialTheme.colorScheme.onSurface),
                        decorationBox = { inner ->
                            if (state.rawTo.isBlank()) {
                                Text(
                                    "Recipients (comma separated)",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = .72f),
                                )
                            }
                            inner()
                        },
                    )
                    if (!showCcBcc) {
                        TextButton(
                            onClick = { showCcBcc = true },
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                        ) {
                            Text(
                                "Cc/Bcc",
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.primary,
                            )
                        }
                    }
                }
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
            }

            if (showCcBcc) {
                ComposeLine("Cc", state.rawCc, vm::updateCc, "Optional")
                ComposeLine("Bcc", state.rawBcc, vm::updateBcc, "Optional")
            }

            ComposeLine("Subject", draft.subject, vm::updateSubject, "Subject")

            Spacer(Modifier.height(16.dp))
            Text(
                "Message",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(6.dp))
            BasicTextField(
                value = draft.body,
                onValueChange = vm::updateBody,
                modifier = Modifier.fillMaxWidth().heightIn(min = 220.dp).semantics { contentDescription = "Message body" },
                cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                textStyle = MaterialTheme.typography.bodyLarge.copy(color = MaterialTheme.colorScheme.onSurface),
                minLines = 8,
                decorationBox = { inner ->
                    if (draft.body.isBlank()) {
                        Text("Write your message here…", style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f))
                    }
                    inner()
                },
            )
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))

            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = { picker.launch(arrayOf("*/*")) },
                shape = RoundedCornerShape(GlassRadius.chip),
                modifier = Modifier.padding(vertical = 4.dp),
            ) {
                Icon(Icons.Outlined.AttachFile, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text("Add attachment", style = MaterialTheme.typography.labelMedium)
            }

            draft.attachments.forEach { attachment ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp)
                        .clip(RoundedCornerShape(GlassRadius.md))
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = .45f))
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                ) {
                    Icon(Icons.Outlined.AttachFile, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp))
                    Column(Modifier.weight(1f).padding(horizontal = 10.dp)) {
                        Text(attachment.fileName, maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodyMedium)
                        Text(attachment.mimeType, maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    IconButton(onClick = { vm.removeAttachment(attachment.uri) }) {
                        Icon(Icons.Outlined.Close, contentDescription = "Remove ${attachment.fileName}")
                    }
                }
            }

            state.error?.let {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 12.dp)
                        .clip(RoundedCornerShape(GlassRadius.md))
                        .background(MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.6f))
                        .padding(12.dp),
                ) {
                    Text(
                        it,
                        color = MaterialTheme.colorScheme.onErrorContainer,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
        }
    }
}

@Composable
private fun ComposeLine(label: String, value: String, onValueChange: (String) -> Unit, hint: String) {
    Column(Modifier.fillMaxWidth()) {
        Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(vertical = 8.dp), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
            Text(label, modifier = Modifier.width(64.dp), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                modifier = Modifier.weight(1f).semantics { contentDescription = label },
                cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                singleLine = true,
                textStyle = MaterialTheme.typography.bodyLarge.copy(color = MaterialTheme.colorScheme.onSurface),
                decorationBox = { inner ->
                    if (value.isBlank()) Text(hint, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = .72f))
                    inner()
                },
            )
        }
        HorizontalDivider(color = MaterialTheme.colorScheme.onSurface.copy(alpha = .10f))
    }
}

data class ComposeUiState(
    val draft: MailDraft,
    val rawTo: String = draft.to.joinToString(", "),
    val rawCc: String = draft.cc.joinToString(", "),
    val rawBcc: String = draft.bcc.joinToString(", "),
    val status: DraftStatus = DraftStatus.DRAFT,
    val error: String? = null,
    val undoCountdownSeconds: Int = 0,
)

class ComposeViewModel(
    private val drafts: DraftRepository,
    private val account: MailAccount,
    draftId: String?,
    private val context: android.content.Context,
    private val contentResolver: android.content.ContentResolver,
    private val sendDelaySeconds: Int,
) : ViewModel() {
    private val id = draftId ?: UUID.randomUUID().toString()
    private val _state = MutableStateFlow(ComposeUiState(MailDraft(id, account.accountId)))
    val state: StateFlow<ComposeUiState> = _state.asStateFlow()
    private var saveJob: Job? = null
    private var countdownJob: Job? = null

    init {
        if (draftId != null) viewModelScope.launch {
            var initialized = false
            drafts.observeDraft(draftId).collect { loaded ->
                if (loaded == null) return@collect
                val current = _state.value
                if (!initialized) {
                    initialized = true
                    _state.value = ComposeUiState(
                        draft = loaded,
                        rawTo = loaded.to.joinToString(", "),
                        rawCc = loaded.cc.joinToString(", "),
                        rawBcc = loaded.bcc.joinToString(", "),
                        status = loaded.status,
                    )
                    if (loaded.status == DraftStatus.QUEUED) startCountdown(loaded.updatedAtEpochMillis)
                } else if (loaded.status in setOf(DraftStatus.SENDING, DraftStatus.SENT, DraftStatus.FAILED, DraftStatus.UNCERTAIN) && current.status != loaded.status) {
                    countdownJob?.cancel()
                    _state.value = current.copy(draft = loaded, status = loaded.status, undoCountdownSeconds = 0,
                        error = if (loaded.status == DraftStatus.UNCERTAIN) "Delivery status is unknown. Check Sent mail before retrying to avoid duplicates." else null)
                }
            }
        }
    }

    fun updateTo(value: String) {
        _state.value = _state.value.copy(rawTo = value)
        update { it.copy(to = normalizeAddresses(value), status = DraftStatus.DRAFT) }
    }

    fun updateCc(value: String) {
        _state.value = _state.value.copy(rawCc = value)
        update { it.copy(cc = normalizeAddresses(value), status = DraftStatus.DRAFT) }
    }

    fun updateBcc(value: String) {
        _state.value = _state.value.copy(rawBcc = value)
        update { it.copy(bcc = normalizeAddresses(value), status = DraftStatus.DRAFT) }
    }

    fun updateSubject(value: String) = update { it.copy(subject = value.take(MAX_SUBJECT), status = DraftStatus.DRAFT) }
    fun updateBody(value: String) = update { it.copy(body = value.take(MAX_BODY), status = DraftStatus.DRAFT) }
    fun addAttachments(value: List<DraftAttachment>) = update { it.copy(attachments = (it.attachments + value).distinctBy(DraftAttachment::uri), status = DraftStatus.DRAFT) }
    fun removeAttachment(uri: String) = update { it.copy(attachments = it.attachments.filterNot { attachment -> attachment.uri == uri }, status = DraftStatus.DRAFT) }

    fun send() {
        val current = _state.value
        if (current.status == DraftStatus.QUEUED) return cancelQueuedSend()
        if (current.status == DraftStatus.SENDING || current.status == DraftStatus.SENT) return
        if (!validateAddresses(current.draft.to + current.draft.cc + current.draft.bcc)) {
            _state.value = current.copy(error = "Enter at least one valid recipient.")
            return
        }
        viewModelScope.launch {
            val now = System.currentTimeMillis()
            val queued = current.draft.copy(status = DraftStatus.QUEUED, updatedAtEpochMillis = now)
            RemoteDraftSyncWorker.cancel(context, queued.draftId)
            drafts.saveDraft(queued)
            runCatching { DelayedSendWorker.enqueue(context, queued.draftId, sendDelaySeconds) }
                .onFailure {
                    val failed = queued.copy(status = DraftStatus.FAILED)
                    drafts.saveDraft(failed)
                    _state.value = current.copy(draft = failed, status = DraftStatus.FAILED, error = "Could not queue this email. Try again.")
                    return@launch
                }
            _state.value = current.copy(draft = queued, status = DraftStatus.QUEUED, undoCountdownSeconds = sendDelaySeconds)
            startCountdown(now)
        }
    }

    fun cancelQueuedSend() {
        val current = _state.value
        if (current.status != DraftStatus.QUEUED || current.undoCountdownSeconds <= 0) return
        countdownJob?.cancel()
        DelayedSendWorker.cancel(context, current.draft.draftId)
        val restored = current.draft.copy(status = DraftStatus.DRAFT, updatedAtEpochMillis = System.currentTimeMillis())
        _state.value = current.copy(draft = restored, status = DraftStatus.DRAFT, undoCountdownSeconds = 0, error = null)
        viewModelScope.launch { drafts.saveDraft(restored) }
        RemoteDraftSyncWorker.enqueue(context, restored.draftId)
    }

    private fun startCountdown(queuedAt: Long) {
        countdownJob?.cancel()
        countdownJob = viewModelScope.launch {
            while (true) {
                val remaining = ((queuedAt + sendDelaySeconds * 1_000L - System.currentTimeMillis() + 999) / 1_000L).toInt().coerceAtLeast(0)
                _state.value = _state.value.copy(undoCountdownSeconds = remaining)
                if (remaining == 0) break
                delay(250)
            }
        }
    }

    private fun update(transform: (MailDraft) -> MailDraft) {
        val current = _state.value
        if (current.status == DraftStatus.QUEUED) {
            countdownJob?.cancel()
            DelayedSendWorker.cancel(context, current.draft.draftId)
        }
        val next = transform(current.draft).copy(updatedAtEpochMillis = System.currentTimeMillis())
        _state.value = current.copy(draft = next, status = DraftStatus.DRAFT, error = null, undoCountdownSeconds = 0)
        saveJob?.cancel()
        saveJob = viewModelScope.launch {
            delay(AUTOSAVE_DELAY_MILLIS)
            drafts.saveDraft(next)
            if (next.status == DraftStatus.DRAFT) RemoteDraftSyncWorker.enqueue(context, next.draftId)
        }
    }

    companion object {
        private const val AUTOSAVE_DELAY_MILLIS = 400L
        private const val MAX_SUBJECT = 998
        private const val MAX_BODY = 2_000_000
        fun factory(drafts: DraftRepository, account: MailAccount, draftId: String?, context: android.content.Context, contentResolver: android.content.ContentResolver, sendDelaySeconds: Int) = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST") override fun <T : ViewModel> create(modelClass: Class<T>): T = ComposeViewModel(drafts, account, draftId, context, contentResolver, sendDelaySeconds) as T
        }
    }
}

private fun SendMailError.userMessage(): String = when (this) {
    SendMailError.Authentication -> "Authentication required. Update the account credential and try again."
    SendMailError.Network -> "Could not reach Gmail. The draft is saved; try Send again when online."
    SendMailError.Protocol -> "Gmail rejected this message. The draft is saved for correction."
    SendMailError.InvalidMessage -> "Check recipients and message details."
}
