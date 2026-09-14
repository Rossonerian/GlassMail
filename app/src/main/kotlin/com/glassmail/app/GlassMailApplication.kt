package com.glassmail.app

import android.app.Application
import com.glassmail.core.database.GlassMailDatabase
import com.glassmail.core.imap.GmailImapClient
import com.glassmail.core.imap.GmailSmtpMailSender
import com.glassmail.core.imap.SmtpCredentialProvider
import com.glassmail.core.security.AndroidKeystoreCredentialStore
import com.glassmail.data.mail.ImapMailRepository
import com.glassmail.domain.mail.MailRepository
import com.glassmail.domain.mail.DraftRepository
import com.glassmail.domain.mail.SyncAccountUseCase
import com.glassmail.sync.SyncRuntime
import com.glassmail.sync.AccountSyncScheduler
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
    private val repositoryImpl = ImapMailRepository(
        database = database,
        credentialStore = credentialStore,
        imapClient = GmailImapClient(),
        attachmentRoot = java.io.File(application.filesDir, "mail-cache"),
        onNewMessages = notificationCoordinator::onNewMessages,
    )
    val mailRepository: MailRepository = repositoryImpl
    val draftRepository: DraftRepository = repositoryImpl
    val syncAccountUseCase = SyncAccountUseCase(mailRepository)
    val syncScheduler = AccountSyncScheduler(application)
    val mailSender = GmailSmtpMailSender(object : SmtpCredentialProvider {
        override suspend fun <T> withCredential(accountId: String, block: suspend (CharArray) -> T): T? = credentialStore.withCredential(accountId, block)
    })

    init {
        SyncRuntime.install(mailRepository)
    }
}
