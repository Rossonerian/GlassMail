package com.glassmail.app

import android.app.Application
import com.glassmail.core.database.GlassMailDatabase
import com.glassmail.core.imap.GmailImapClient
import com.glassmail.core.imap.GmailSmtpMailSender
import com.glassmail.core.imap.Rfc822MessageEncoder
import com.glassmail.core.imap.SmtpCredentialProvider
import com.glassmail.core.security.AndroidKeystoreCredentialStore
import com.glassmail.data.mail.ImapMailRepository
import com.glassmail.domain.mail.MailRepository
import com.glassmail.domain.mail.DraftRepository
import com.glassmail.domain.mail.MailDraft
import com.glassmail.domain.mail.OutgoingAttachment
import com.glassmail.domain.mail.OutgoingMail
import com.glassmail.domain.mail.estimatedOutgoingMessageBytes
import com.glassmail.domain.mail.SyncAccountUseCase
import com.glassmail.sync.SyncRuntime
import com.glassmail.sync.AccountSyncScheduler
import com.glassmail.sync.IdleRuntime
import com.glassmail.sync.IdleSessionProvider
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

class GlassMailApplication : Application() {
    lateinit var graph: AppGraph
        private set

    override fun onCreate() {
        super.onCreate()
        graph = AppGraph(this)
        // Startup sync is unique per account, so repeated process creation cannot create
        // concurrent same-account sessions. This scope only performs this one observation.
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            graph.mailRepository.observeAccounts().first().forEach { account ->
                graph.syncScheduler.enqueueStartup(account.accountId)
                graph.syncScheduler.schedulePeriodic(account.accountId)
            }
        }
    }
}

class AppGraph(application: Application) {
    val context = application.applicationContext
    val contentResolver = application.contentResolver
    val appearancePreferences = AppearancePreferences(application)
    private val notificationCoordinator = NotificationCoordinator(application, appearancePreferences)
    private val database = GlassMailDatabase.create(application)
    val credentialStore = AndroidKeystoreCredentialStore(application)
    private val imapClient = GmailImapClient()
    private val repositoryImpl = ImapMailRepository(
        database = database,
        credentialStore = credentialStore,
        imapClient = imapClient,
        attachmentRoot = java.io.File(application.filesDir, "mail-cache"),
        onNewMessages = notificationCoordinator::onNewMessages,
    )
    val mailRepository: MailRepository = repositoryImpl
    val draftRepository: DraftRepository = repositoryImpl
    val syncAccountUseCase = SyncAccountUseCase(mailRepository)
    val syncScheduler = AccountSyncScheduler(application)
    val mailSender = GmailSmtpMailSender(object : SmtpCredentialProvider {
        override suspend fun <T> withCredential(accountId: String, block: suspend (CharArray) -> T): T? = credentialStore.withCredential(accountId, block)
    }, imapClient = imapClient)

    suspend fun syncRemoteDraft(draft: MailDraft): Result<Unit> = runCatching {
        val account = mailRepository.observeAccounts().first().firstOrNull { it.accountId == draft.accountId }
            ?: error("Draft account is unavailable")
        val attachments = draft.attachments.map { attachment ->
            val uri = android.net.Uri.parse(attachment.uri)
            OutgoingAttachment(attachment.fileName, attachment.mimeType, attachment.sizeBytes) {
                contentResolver.openInputStream(uri) ?: error("Draft attachment is unavailable")
            }
        }
        val outgoing = OutgoingMail(
            operationId = draft.draftId,
            accountId = account.accountId,
            from = account.email,
            to = draft.to,
            cc = draft.cc,
            bcc = draft.bcc,
            subject = draft.subject,
            body = draft.body,
            inReplyTo = draft.inReplyTo,
            references = draft.references,
            attachments = attachments,
        )
        require(estimatedOutgoingMessageBytes(outgoing) <= 24L * 1024 * 1024) { "Draft exceeds the message size limit" }
        val raw = Rfc822MessageEncoder.encode(outgoing)
        credentialStore.withCredential(account.accountId) { password ->
            imapClient.replaceRemoteDraft(account.email, password, draft.draftId, raw)
        } ?: error("IMAP credentials are unavailable")
    }

    init {
        SyncRuntime.install(mailRepository)
        IdleRuntime.install(object : IdleSessionProvider {
            override suspend fun accounts() = mailRepository.observeAccounts().first()

            override suspend fun idle(accountId: String) {
                val account = mailRepository.observeAccounts().first().firstOrNull { it.accountId == accountId } ?: return
                val connected = credentialStore.withCredential(accountId) { password ->
                    imapClient.idle(account.email, password) { syncScheduler.enqueueManual(accountId) }
                }
                if (connected == null) error("IMAP credentials are unavailable")
            }

            override fun enqueueSync(accountId: String) = syncScheduler.enqueueManual(accountId)
        })
    }
}
