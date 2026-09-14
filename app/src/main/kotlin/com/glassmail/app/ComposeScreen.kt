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
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.background
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.AttachFile
import androidx.compose.material.icons.outlined.Close
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
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
    draftId: String?,
    back: () -> Unit,
) {
    BackHandler(onBack = back)
    if (account == null) {
        Column(Modifier.fillMaxSize().padding(24.dp)) { Text("No account is available for composing mail.") }
        return
    }
    val vm: ComposeViewModel = androidx.lifecycle.viewmodel.compose.viewModel(
        key = draftId ?: "new",
        factory = ComposeViewModel.factory(graph.draftRepository, graph.mailSender, account, draftId, graph.contentResolver),
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
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("New message") },
                navigationIcon = { IconButton(back) { Icon(Icons.Outlined.ArrowBack, contentDescription = "Back") } },
                actions = {
                    TextButton(enabled = state.status != DraftStatus.SENDING, onClick = vm::send) {
                        Text(if (state.status == DraftStatus.SENDING) "Sending…" else "Send")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            Modifier.fillMaxSize().padding(padding).imePadding().navigationBarsPadding().padding(20.dp).verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(0.dp),
        ) {
            ComposeLine("To", draft.to.joinToString(", "), vm::updateTo, "Required · separate addresses with commas")
            ComposeLine("Cc", draft.cc.joinToString(", "), vm::updateCc, "Optional")
            ComposeLine("Bcc", draft.bcc.joinToString(", "), vm::updateBcc, "Optional")
            ComposeLine("Subject", draft.subject, vm::updateSubject, "Optional")
            Spacer(Modifier.padding(top = 12.dp))
            Text("Message", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            BasicTextField(
                value = draft.body,
                onValueChange = vm::updateBody,
                modifier = Modifier.fillMaxWidth().heightIn(min = 260.dp).semantics { contentDescription = "Message body" },
                textStyle = MaterialTheme.typography.bodyLarge.copy(color = MaterialTheme.colorScheme.onSurface),
                minLines = 10,
                decorationBox = { inner ->
                    if (draft.body.isBlank()) Text("Write your message…", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    inner()
                },
            )
            HorizontalDivider(color = MaterialTheme.colorScheme.onSurface.copy(alpha = .10f))
            TextButton(onClick = { picker.launch(arrayOf("*/*")) }, modifier = Modifier.padding(top = 8.dp)) {
                Icon(Icons.Outlined.AttachFile, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text("Add attachment")
            }
            draft.attachments.forEach { attachment ->
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = .28f)).padding(start = 12.dp),
                    verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                ) {
                    Icon(Icons.Outlined.AttachFile, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Column(Modifier.weight(1f).padding(horizontal = 10.dp, vertical = 8.dp)) {
                        Text(attachment.fileName, maxLines = 1, style = MaterialTheme.typography.bodyMedium)
                        Text(attachment.mimeType, maxLines = 1, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    IconButton(onClick = { vm.removeAttachment(attachment.uri) }) { Icon(Icons.Outlined.Close, contentDescription = "Remove ${attachment.fileName}") }
                }
            }
            state.error?.let { Text(it, Modifier.padding(top = 12.dp), color = MaterialTheme.colorScheme.error) }
            Text(if (state.status == DraftStatus.SENDING) "Sending…" else if (state.status == DraftStatus.SENT) "Sent" else "Draft saved locally", Modifier.padding(top = 12.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
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
    val status: DraftStatus = DraftStatus.DRAFT,
    val error: String? = null,
)

class ComposeViewModel(
    private val drafts: DraftRepository,
    private val sender: MailSender,
    private val account: MailAccount,
    draftId: String?,
    private val contentResolver: android.content.ContentResolver,
) : ViewModel() {
    private val id = draftId ?: UUID.randomUUID().toString()
    private val _state = MutableStateFlow(ComposeUiState(MailDraft(id, account.accountId)))
    val state: StateFlow<ComposeUiState> = _state.asStateFlow()
    private var saveJob: Job? = null

    init {
        if (draftId != null) viewModelScope.launch {
            drafts.observeDraft(draftId).first { it != null }?.let { loaded -> _state.value = ComposeUiState(loaded, loaded.status) }
        }
    }

    fun updateTo(value: String) = update { it.copy(to = normalizeAddresses(value), status = DraftStatus.DRAFT) }
    fun updateCc(value: String) = update { it.copy(cc = normalizeAddresses(value), status = DraftStatus.DRAFT) }
    fun updateBcc(value: String) = update { it.copy(bcc = normalizeAddresses(value), status = DraftStatus.DRAFT) }
    fun updateSubject(value: String) = update { it.copy(subject = value.take(MAX_SUBJECT), status = DraftStatus.DRAFT) }
    fun updateBody(value: String) = update { it.copy(body = value.take(MAX_BODY), status = DraftStatus.DRAFT) }
    fun addAttachments(value: List<DraftAttachment>) = update { it.copy(attachments = (it.attachments + value).distinctBy(DraftAttachment::uri), status = DraftStatus.DRAFT) }
    fun removeAttachment(uri: String) = update { it.copy(attachments = it.attachments.filterNot { attachment -> attachment.uri == uri }, status = DraftStatus.DRAFT) }

    fun send() {
        val current = _state.value
        if (current.status == DraftStatus.SENDING) return
        if (!validateAddresses(current.draft.to + current.draft.cc + current.draft.bcc)) {
            _state.value = current.copy(error = "Enter at least one valid recipient.")
            return
        }
        viewModelScope.launch {
            val sending = current.draft.copy(status = DraftStatus.SENDING, updatedAtEpochMillis = System.currentTimeMillis())
            _state.value = ComposeUiState(sending, DraftStatus.SENDING)
            drafts.saveDraft(sending)
            val outgoingAttachments = sending.attachments.mapNotNull { attachment ->
                val available = runCatching { contentResolver.openInputStream(android.net.Uri.parse(attachment.uri))?.use { true } ?: false }.getOrDefault(false)
                if (!available) return@mapNotNull null
                com.glassmail.domain.mail.OutgoingAttachment(attachment.fileName, attachment.mimeType, attachment.sizeBytes, { contentResolver.openInputStream(android.net.Uri.parse(attachment.uri)) ?: error("Attachment is unavailable") })
            }
            when (val result = sender.send(account, OutgoingMail(sending.draftId, account.accountId, account.email, sending.to, sending.cc, sending.bcc, sending.subject, sending.body, sending.inReplyTo, sending.references, outgoingAttachments))) {
                SendMailResult.Sent -> {
                    val sent = sending.copy(status = DraftStatus.SENT, updatedAtEpochMillis = System.currentTimeMillis())
                    drafts.saveDraft(sent)
                    _state.value = ComposeUiState(sent, DraftStatus.SENT)
                }
                is SendMailResult.Failed -> {
                    val failed = sending.copy(status = DraftStatus.FAILED, updatedAtEpochMillis = System.currentTimeMillis())
                    drafts.saveDraft(failed)
                    _state.value = ComposeUiState(failed, DraftStatus.FAILED, result.error.userMessage())
                }
            }
        }
    }

    private fun update(transform: (MailDraft) -> MailDraft) {
        val next = transform(_state.value.draft).copy(updatedAtEpochMillis = System.currentTimeMillis())
        _state.value = ComposeUiState(next, DraftStatus.DRAFT)
        saveJob?.cancel()
        saveJob = viewModelScope.launch {
            delay(AUTOSAVE_DELAY_MILLIS)
            drafts.saveDraft(next)
        }
    }

    companion object {
        private const val AUTOSAVE_DELAY_MILLIS = 400L
        private const val MAX_SUBJECT = 998
        private const val MAX_BODY = 2_000_000
        fun factory(drafts: DraftRepository, sender: MailSender, account: MailAccount, draftId: String?, contentResolver: android.content.ContentResolver) = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST") override fun <T : ViewModel> create(modelClass: Class<T>): T = ComposeViewModel(drafts, sender, account, draftId, contentResolver) as T
        }
    }
}

private fun SendMailError.userMessage(): String = when (this) {
    SendMailError.Authentication -> "Authentication required. Update the account credential and try again."
    SendMailError.Network -> "Could not reach Gmail. The draft is saved; try Send again when online."
    SendMailError.Protocol -> "Gmail rejected this message. The draft is saved for correction."
    SendMailError.InvalidMessage -> "Check recipients and message details."
}
