@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class, kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package com.glassmail.app

import android.content.Context
import android.content.Intent
import android.app.Activity
import android.widget.Toast
import androidx.core.content.FileProvider
import androidx.compose.foundation.clickable
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.Alignment
import androidx.compose.runtime.derivedStateOf
import androidx.compose.material3.Button
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.IconButton
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Archive
import androidx.compose.material.icons.outlined.AttachFile
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material.icons.outlined.MarkEmailRead
import androidx.compose.material.icons.outlined.MarkEmailUnread
import androidx.compose.material.icons.outlined.MoreVert
import androidx.compose.material.icons.outlined.MoreHoriz
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Clear
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Terminal
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.navArgument
import com.glassmail.designsystem.glass.GlassQuality
import com.glassmail.designsystem.glass.GlassSurface
import com.glassmail.designsystem.glass.GlassPreferences
import com.glassmail.designsystem.glass.LocalGlassPreferences
import com.glassmail.designsystem.AmbientCanvas
import com.glassmail.designsystem.GlassMailPalette
import com.glassmail.designsystem.GlassMailTheme
import com.glassmail.designsystem.MorphingDock
import com.glassmail.domain.mail.MailAccount
import com.glassmail.domain.mail.MailListItem
import com.glassmail.domain.mail.MailMutation
import com.glassmail.domain.mail.MailRepository
import com.glassmail.domain.mail.MailDraft
import com.glassmail.domain.mail.MailAttachment
import com.glassmail.domain.mail.AttachmentRepository
import com.glassmail.domain.mail.DraftRepository
import com.glassmail.domain.mail.ReceivedMailHeaders
import com.glassmail.domain.mail.forwardSubject
import com.glassmail.domain.mail.referencesForReply
import com.glassmail.domain.mail.replyAllRecipients
import com.glassmail.domain.mail.replyRecipients
import com.glassmail.domain.mail.replySubject
import java.util.UUID
import com.glassmail.sync.AccountSyncScheduler
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

@Composable
fun GlassMailApp(graph: AppGraph, notificationMessageId: StateFlow<String?> = MutableStateFlow(null)) {
    val vm: AppViewModel = viewModel(factory = AppViewModel.factory(graph.context, graph.mailRepository, graph.syncScheduler, graph.appearancePreferences, graph.draftRepository, graph.credentialStore))
    val accounts by vm.accounts.collectAsStateWithLifecycle()
    val appearance by vm.appearance.collectAsStateWithLifecycle()
    val drafts by vm.drafts.collectAsStateWithLifecycle()
    val navController = rememberNavController()
    var paletteOpen by remember { mutableStateOf(false) }
    val currentRoute by navController.currentBackStackEntryAsState()
    val notificationId by notificationMessageId.collectAsStateWithLifecycle()
    val route = currentRoute?.destination?.route
    val dark = when (appearance.theme) {
        ThemeChoice.DARK -> true
        ThemeChoice.LIGHT -> false
        ThemeChoice.SYSTEM -> androidx.compose.foundation.isSystemInDarkTheme()
    }
    val ambient = when {
        route == ROUTE_SEARCH -> GlassMailPalette.Updates
        route == ROUTE_SETTINGS -> GlassMailPalette.Personal
        route?.startsWith(ROUTE_READER) == true -> GlassMailPalette.Personal
        else -> GlassMailPalette.Priority
    }
    fun openCompose(seed: MailDraft? = null) {
        val account = accounts.firstOrNull() ?: return
        val draft = seed ?: MailDraft(UUID.randomUUID().toString(), account.accountId)
        vm.saveDraft(draft)
        navController.navigate("$ROUTE_COMPOSE/${draft.draftId}")
    }
    BackHandler(enabled = paletteOpen) { paletteOpen = false }
    androidx.compose.runtime.LaunchedEffect(accounts.isEmpty()) {
        val current = navController.currentBackStackEntry?.destination?.route
        if (accounts.isEmpty() && current != ROUTE_SETUP) {
            navController.navigate(ROUTE_SETUP) { popUpTo(ROUTE_INBOX) { inclusive = true } }
        } else if (accounts.isNotEmpty() && current == ROUTE_SETUP) {
            navController.navigate(ROUTE_INBOX) { popUpTo(ROUTE_SETUP) { inclusive = true } }
        }
    }
    androidx.compose.runtime.LaunchedEffect(notificationId, accounts.isNotEmpty()) {
        notificationId?.takeIf { accounts.isNotEmpty() }?.let { navController.navigate("$ROUTE_READER/$it") }
    }
    GlassMailTheme(dark = dark, ambient = ambient) {
    val view = LocalView.current
    SideEffect {
        (view.context as? Activity)?.window?.let { window ->
            WindowCompat.getInsetsController(window, view).apply {
                isAppearanceLightStatusBars = !dark
                isAppearanceLightNavigationBars = !dark
            }
        }
    }
    androidx.compose.runtime.CompositionLocalProvider(LocalGlassPreferences provides GlassPreferences(appearance.reduceTransparency, appearance.reduceMotion)) {
    AmbientCanvas(ambient, dark = dark) { Box(Modifier.fillMaxSize()) { NavHost(navController = navController, startDestination = ROUTE_INBOX) {
        composable(ROUTE_SETUP) { AccountSetupRoute(graph) }
        composable(ROUTE_INBOX) {
            InboxScreen(vm, accounts.firstOrNull(),
                open = { navController.navigate("$ROUTE_READER/$it") },
                search = { navController.navigate(ROUTE_SEARCH) },
                settings = { navController.navigate(ROUTE_SETTINGS) },
                openPalette = { paletteOpen = true },
                compose = { openCompose() },
            )
        }
        composable(ROUTE_SEARCH) {
            SearchScreen(
                vm = vm,
                account = accounts.firstOrNull(),
                open = { navController.navigate("$ROUTE_READER/$it") },
                back = { navController.popBackStack() },
                openPalette = { paletteOpen = true },
            )
        }
        composable(ROUTE_SETTINGS) {
            SettingsScreen(graph, vm, accounts.firstOrNull(), { navController.popBackStack() }, { paletteOpen = true })
        }
        composable("$ROUTE_COMPOSE/{draftId}") { entry ->
            ComposeRoute(graph, accounts.firstOrNull(), entry.arguments?.getString("draftId")?.takeUnless { it == "new" }, { navController.popBackStack() })
        }
        composable(
            route = "$ROUTE_READER/{messageId}",
            arguments = listOf(navArgument("messageId") { type = NavType.StringType }),
        ) { entry ->
            ReaderScreen(vm, accounts.firstOrNull(), entry.arguments?.getString("messageId").orEmpty(), appearance.glassQuality, { navController.popBackStack() }, { paletteOpen = true }, { draft -> openCompose(draft) }, { attachment -> vm.downloadAttachment(attachment) })
        }
    }
    if (paletteOpen) {
        val selected = if (route?.startsWith(ROUTE_READER) == true) vm.readerUiState.collectAsStateWithLifecycle().value.selected else null
        val actions = buildList {
            add(CommandPaletteAction("inbox", "Inbox", "Open Priority inbox") { paletteOpen = false; navController.navigate(ROUTE_INBOX) })
            add(CommandPaletteAction("search", "Search", "Search cached mail") { paletteOpen = false; navController.navigate(ROUTE_SEARCH) })
            add(CommandPaletteAction("settings", "Settings", "Appearance and account") { paletteOpen = false; navController.navigate(ROUTE_SETTINGS) })
            add(CommandPaletteAction("refresh", "Refresh", "Synchronize the current account") { paletteOpen = false; vm.refresh() })
            add(CommandPaletteAction("compose", "Compose", "Write a new message") { paletteOpen = false; openCompose() })
            drafts.forEach { draft ->
                add(CommandPaletteAction("draft-${draft.draftId}", "Draft: ${draft.subject.ifBlank { "(no subject)" }}", "Resume saved draft") { paletteOpen = false; navController.navigate("$ROUTE_COMPOSE/${draft.draftId}") })
            }
            selected?.let { message ->
                val target = message.toListItem()
                add(CommandPaletteAction("message-read", if (message.unread) "Mark read" else "Mark unread", "Current message") { paletteOpen = false; vm.mutation(target, "read") })
                add(CommandPaletteAction("message-star", if (message.starred) "Unstar" else "Star", "Current message") { paletteOpen = false; vm.mutation(target, "star") })
                add(CommandPaletteAction("message-archive", "Archive", "Remove from Inbox") { paletteOpen = false; vm.mutation(target, "archive") })
                add(CommandPaletteAction("message-delete", "Delete", "Move current message to trash", destructive = true) { paletteOpen = false; vm.mutation(target, "delete") })
            }
        }
        CommandPalette(actions, appearance.glassQuality, onDismiss = { paletteOpen = false })
    }
    } }
    }
}
}

private const val ROUTE_SETUP = "setup"
private const val ROUTE_INBOX = "inbox"
private const val ROUTE_SEARCH = "search"
private const val ROUTE_SETTINGS = "settings"
private const val ROUTE_READER = "reader"
private const val ROUTE_COMPOSE = "compose"

class AppViewModel(
    private val context: Context,
    private val repository: MailRepository,
    private val syncScheduler: AccountSyncScheduler,
    private val appearancePreferences: AppearancePreferences,
    private val draftRepository: DraftRepository,
    private val credentialStore: com.glassmail.core.security.CredentialStore,
) : ViewModel() {
    private val _appearance = MutableStateFlow(appearancePreferences.read())
    val appearance: StateFlow<AppearanceSettings> = _appearance
    val accounts: StateFlow<List<MailAccount>> = repository.observeAccounts().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    private val accountId = accounts.map { it.firstOrNull()?.accountId }.stateIn(viewModelScope, SharingStarted.Eagerly, null)
    val drafts: StateFlow<List<MailDraft>> = accountId.flatMapLatest { id -> if (id == null) kotlinx.coroutines.flow.flowOf(emptyList()) else draftRepository.observeDrafts(id) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    private val inboxItems = accountId.flatMapLatest { id -> if (id == null) kotlinx.coroutines.flow.flowOf(emptyList()) else repository.observeInbox(id) }
    val inboxUiState: StateFlow<InboxUiState> = combine(accounts, inboxItems) { availableAccounts, messages ->
        InboxUiState(account = availableAccounts.firstOrNull(), messages = messages)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), InboxUiState())
    private val searchQuery = MutableStateFlow("")
    val searchUiState: StateFlow<SearchUiState> = combine(accountId, searchQuery) { id, query -> id to query }
        .flatMapLatest { (id, query) ->
            if (id == null || query.isBlank()) kotlinx.coroutines.flow.flowOf(SearchUiState(query = query))
            else repository.search(id, query).map { SearchUiState(query = query, messages = it) }
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), SearchUiState())
    private val readerMessageId = MutableStateFlow<String?>(null)
    val readerUiState: StateFlow<ReaderUiState> = readerMessageId.flatMapLatest { messageId ->
        if (messageId == null) kotlinx.coroutines.flow.flowOf(ReaderUiState())
        else combine(repository.observeMessage(messageId), repository.observeThread(messageId)) { selected, thread ->
            ReaderUiState(selected = selected, thread = thread)
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ReaderUiState())
    fun mutation(item: MailListItem, type: String) = viewModelScope.launch { repository.applyMutation(when (type) { "star" -> MailMutation.Star(accounts.value.first().accountId, item.messageId, null, !item.starred); "read" -> MailMutation.MarkRead(accounts.value.first().accountId, item.messageId, null, item.unread); "archive" -> MailMutation.Archive(accounts.value.first().accountId, item.messageId, "${accounts.value.first().accountId}:INBOX"); else -> MailMutation.Delete(accounts.value.first().accountId, item.messageId, null) }) }
    fun setLabel(messageId: String, label: String, add: Boolean) = viewModelScope.launch {
        accounts.value.firstOrNull()?.let { repository.applyMutation(MailMutation.Label(it.accountId, messageId, null, label, add)) }
    }
    fun seed(n: Int) = viewModelScope.launch { repository.seedDebugMailbox(n) }
    fun clear() = viewModelScope.launch { repository.clearDebugMailbox() }
    fun removeAccount() = viewModelScope.launch {
        accounts.value.firstOrNull()?.let {
            syncScheduler.cancel(it.accountId)
            repository.removeAccount(it.accountId)
        }
    }
    fun refresh() = viewModelScope.launch { accounts.value.firstOrNull()?.let { repository.synchronize(it.accountId) } }
    fun setSearchQuery(query: String) { searchQuery.value = query }
    fun selectReaderMessage(messageId: String) { readerMessageId.value = messageId }
    fun updateAppearance(update: (AppearanceSettings) -> AppearanceSettings) {
        _appearance.value = update(_appearance.value)
        appearancePreferences.write(_appearance.value)
    }
    fun saveDraft(draft: MailDraft) = viewModelScope.launch { draftRepository.saveDraft(draft) }
    fun downloadAttachment(attachment: MailAttachment) = viewModelScope.launch {
        val account = accounts.value.firstOrNull() ?: return@launch
        val transfer = repository as? AttachmentRepository ?: return@launch
        transfer.downloadAttachment(account.accountId, attachment.attachmentId).onSuccess { file ->
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", java.io.File(file.filePath))
            runCatching {
                context.startActivity(Intent(Intent.ACTION_VIEW, uri).apply {
                    setDataAndType(uri, file.mimeType)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                })
            }.onFailure { Toast.makeText(context, "No app can open this attachment", Toast.LENGTH_LONG).show() }
        }.onFailure { Toast.makeText(context, "Attachment download failed", Toast.LENGTH_LONG).show() }
    }
    fun updateCredential(accountId: String, credential: CharArray) = viewModelScope.launch { credentialStore.store(accountId, credential); refresh() }
    companion object {
        fun factory(context: Context, repository: MailRepository, syncScheduler: AccountSyncScheduler, preferences: AppearancePreferences, draftRepository: DraftRepository, credentialStore: com.glassmail.core.security.CredentialStore) = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST") override fun <T: ViewModel> create(modelClass: Class<T>) = AppViewModel(context, repository, syncScheduler, preferences, draftRepository, credentialStore) as T
        }
    }
}

private fun com.glassmail.domain.mail.MailMessage.toListItem() = MailListItem(messageId, threadId, sender, subject, preview, sentAtEpochMillis, unread, starred, labels, attachments.isNotEmpty())

/** Immutable Room-derived inbox state; Compose never owns a second mail list. */
data class InboxUiState(
    val account: MailAccount? = null,
    val messages: List<MailListItem> = emptyList(),
)

data class SearchUiState(
    val query: String = "",
    val messages: List<MailListItem> = emptyList(),
)

data class ReaderUiState(
    val selected: com.glassmail.domain.mail.MailMessage? = null,
    val thread: List<com.glassmail.domain.mail.MailMessage> = emptyList(),
)

@Composable private fun InboxScreen(vm: AppViewModel, account: MailAccount?, open: (String) -> Unit, search: () -> Unit, settings: () -> Unit, openPalette: () -> Unit, compose: () -> Unit) {
    val state by vm.inboxUiState.collectAsStateWithLifecycle()
    val selectedAccount = state.account ?: account
    val rows = state.messages
    val listState = rememberLazyListState()
    val compact by remember { derivedStateOf { listState.firstVisibleItemIndex > 0 || listState.firstVisibleItemScrollOffset > 56 } }
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {
                        Text("GlassMail", style = MaterialTheme.typography.titleLarge)
                        if (!compact) Text("Priority", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                },
                actions = {
                    IconButton(openPalette) { Icon(Icons.Outlined.MoreHoriz, contentDescription = "Open command palette") }
                    IconButton(search) { Icon(Icons.Outlined.Search, contentDescription = "Search mail") }
                    IconButton(settings) { Icon(Icons.Outlined.Settings, contentDescription = "Open settings") }
                },
            )
        },
        floatingActionButton = { androidx.compose.material3.FloatingActionButton(onClick = compose) { Text("+") } },
        bottomBar = { MorphingDock(compact, 0) { if (it == 1) search() else if (it == 2) settings() } },
    ) { padding ->
        if (selectedAccount == null) Column(Modifier.fillMaxSize().padding(padding).padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) { Text("No account yet"); Button({ vm.seed(100) }) { Text("Seed debug mailbox") } }
        else if (rows.isEmpty()) Column(Modifier.fillMaxSize().padding(padding).padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) { Text("Inbox is empty", style = MaterialTheme.typography.titleLarge); Text(syncStatus(selectedAccount.syncState)); Button({ vm.refresh() }) { Text("Refresh") } }
        else LazyColumn(Modifier.fillMaxSize().padding(padding), state = listState) { items(rows, key = { it.messageId }, contentType = { "mail" }) { row -> MailRow(row, open, vm) } }
    }
}

@Composable private fun MailRow(row: MailListItem, open: (String) -> Unit, vm: AppViewModel) {
    var menuOpen by remember(row.messageId) { mutableStateOf(false) }
    Row(
        Modifier.fillMaxWidth().clickable { open(row.messageId) }.padding(horizontal = 20.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(row.sender, style = if (row.unread) MaterialTheme.typography.titleSmall else MaterialTheme.typography.bodyLarge, maxLines = 1)
            Text(row.subject, style = MaterialTheme.typography.bodyLarge, maxLines = 1)
            Text(row.preview, maxLines = 1, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (row.labels.isNotEmpty()) Text(row.labels.joinToString(), style = MaterialTheme.typography.labelSmall, maxLines = 1, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(timeLabel(row.sentAtEpochMillis), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (row.starred) Icon(Icons.Outlined.Star, contentDescription = "Starred", tint = MaterialTheme.colorScheme.primary)
                if (row.hasAttachment) Icon(Icons.Outlined.AttachFile, contentDescription = "Has attachment", tint = MaterialTheme.colorScheme.onSurfaceVariant)
                Box {
                    IconButton(onClick = { menuOpen = true }) { Icon(Icons.Outlined.MoreVert, contentDescription = "Message actions") }
                    DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                        DropdownMenuItem(
                            text = { Text(if (row.unread) "Mark read" else "Mark unread") },
                            leadingIcon = { Icon(if (row.unread) Icons.Outlined.MarkEmailRead else Icons.Outlined.MarkEmailUnread, contentDescription = null) },
                            onClick = { menuOpen = false; vm.mutation(row, "read") },
                        )
                        DropdownMenuItem(
                            text = { Text(if (row.starred) "Unstar" else "Star") },
                            leadingIcon = { Icon(if (row.starred) Icons.Outlined.Star else Icons.Outlined.StarBorder, contentDescription = null) },
                            onClick = { menuOpen = false; vm.mutation(row, "star") },
                        )
                        DropdownMenuItem(
                            text = { Text("Archive") },
                            leadingIcon = { Icon(Icons.Outlined.Archive, contentDescription = null) },
                            onClick = { menuOpen = false; vm.mutation(row, "archive") },
                        )
                        DropdownMenuItem(
                            text = { Text("Delete") },
                            leadingIcon = { Icon(Icons.Outlined.DeleteOutline, contentDescription = null) },
                            onClick = { menuOpen = false; vm.mutation(row, "delete") },
                        )
                    }
                }
            }
        }
    }
}

private fun timeLabel(epochMillis: Long?): String = epochMillis?.let { java.time.Instant.ofEpochMilli(it)
    .atZone(java.time.ZoneId.systemDefault())
    .toLocalTime()
    .toString()
    .take(5) } ?: "—"

@Composable private fun ReaderScreen(vm: AppViewModel, account: MailAccount?, id: String, quality: GlassQuality, back: () -> Unit, openPalette: () -> Unit, compose: (MailDraft) -> Unit, download: (MailAttachment) -> Unit) {
    BackHandler(onBack = back)
    androidx.compose.runtime.LaunchedEffect(id) { vm.selectReaderMessage(id) }
    val state by vm.readerUiState.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()
    val collapsed by remember { derivedStateOf { listState.firstVisibleItemIndex > 0 || listState.firstVisibleItemScrollOffset > 160 } }
    val subject = state.selected?.subject ?: "Message"
    val decay by remember { derivedStateOf { if (listState.firstVisibleItemIndex > 0) 0f else (1f - listState.firstVisibleItemScrollOffset / 160f).coerceIn(0f, 1f) } }
    val readerTint = state.selected?.sender?.let(::senderAmbient) ?: Color.Transparent
    var labelDialogOpen by remember { mutableStateOf(false) }
    val neutral = if (androidx.compose.foundation.isSystemInDarkTheme()) GlassMailPalette.DarkBase else GlassMailPalette.LightBase
    val chroma = lerp(neutral, readerTint, decay * .10f)
    Scaffold(
        bottomBar = {
            if (account != null && state.selected != null) {
                GlassSurface(
                    quality = quality,
                    modifier = Modifier.fillMaxWidth().navigationBarsPadding(),
                    shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
                ) {
                    Row(
                        Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceEvenly,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        TextButton(onClick = { compose(replyDraft(state.selected!!, account, false)) }) { Text("Reply") }
                        TextButton(onClick = { compose(replyDraft(state.selected!!, account, true)) }) { Text("Reply all") }
                        TextButton(onClick = { compose(forwardDraft(state.selected!!, account)) }) { Text("Forward") }
                    }
                }
            }
        },
        topBar = {
            TopAppBar(
                title = { Text(if (collapsed) subject.take(36) else "Conversation", maxLines = 1) },
                navigationIcon = { IconButton(back) { Icon(Icons.Outlined.ArrowBack, contentDescription = "Back") } },
                actions = { IconButton(openPalette) { Icon(Icons.Outlined.MoreHoriz, contentDescription = "Open command palette") } },
            )
        },
    ) { padding ->
        LazyColumn(
            Modifier.fillMaxSize().background(chroma).padding(padding).navigationBarsPadding().padding(horizontal = 20.dp),
            state = listState,
            contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = if (account != null && state.selected != null) 88.dp else 24.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            val messages = state.thread.ifEmpty { listOfNotNull(state.selected) }
            items(messages, key = { it.messageId }, contentType = { "threadMessage" }) { item ->
                Column(Modifier.fillMaxWidth().padding(vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(item.subject, style = MaterialTheme.typography.headlineSmall, maxLines = 3)
                    Text(item.sender, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
                    Text(item.preview, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(item.body ?: item.preview, style = MaterialTheme.typography.bodyLarge)
                    if (item.messageId == state.selected?.messageId && item.attachments.isNotEmpty()) {
                        item.attachments.forEach { attachment ->
                            Button(onClick = { download(attachment) }, modifier = Modifier.fillMaxWidth()) {
                                Text(if (attachment.downloadState == "AVAILABLE") "Open ${attachment.fileName ?: "attachment"}" else "Download ${attachment.fileName ?: "attachment"}")
                            }
                        }
                    }
                    if (item.messageId == state.selected?.messageId) {
                        TextButton(onClick = { labelDialogOpen = true }) { Text("Labels: ${item.labels.ifEmpty { listOf("none") }.joinToString()}") }
                    }
                    if (item.html) Text("Remote content blocked · HTML shown as safe text", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
    if (labelDialogOpen && state.selected != null) {
        val choices = (state.selected!!.labels + listOf("Work", "Travel", "Personal")).distinct()
        AlertDialog(
            onDismissRequest = { labelDialogOpen = false },
            title = { Text("Labels") },
            text = { Column { choices.forEach { label ->
                val applied = label in state.selected!!.labels
                TextButton(onClick = { vm.setLabel(state.selected!!.messageId, label, !applied) }) { Text(if (applied) "✓ $label" else "+ $label") }
            } } },
            confirmButton = { TextButton({ labelDialogOpen = false }) { Text("Done") } },
        )
    }
}

@Composable private fun SearchScreen(vm: AppViewModel, account: MailAccount?, open: (String) -> Unit, back: () -> Unit, openPalette: () -> Unit) {
    BackHandler(onBack = back)
    val state by vm.searchUiState.collectAsStateWithLifecycle()
    Scaffold { padding ->
        Column(Modifier.fillMaxSize().padding(padding).imePadding().navigationBarsPadding()) {
            Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                IconButton(back) { Icon(Icons.Outlined.ArrowBack, contentDescription = "Back") }
                Text("Search", style = MaterialTheme.typography.titleLarge)
                Spacer(Modifier.weight(1f))
                IconButton(openPalette) { Icon(Icons.Outlined.Terminal, contentDescription = "Open command palette") }
            }
            TextField(
                value = state.query,
                onValueChange = vm::setSearchQuery,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp).clip(RoundedCornerShape(16.dp)),
                label = { Text("Search mail & commands…") },
                leadingIcon = { Icon(Icons.Outlined.Search, contentDescription = null) },
                trailingIcon = { if (state.query.isNotBlank()) IconButton({ vm.setSearchQuery("") }) { Icon(Icons.Outlined.Clear, contentDescription = "Clear search") } },
                singleLine = true,
                colors = TextFieldDefaults.colors(
                    unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = .32f),
                    focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = .5f),
                ),
            )
            when {
                state.query.isBlank() -> Text("Search cached sender, subject, and preview text", Modifier.padding(20.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
                state.messages.isEmpty() -> Text("No cached mail matches this search", Modifier.padding(20.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
                else -> LazyColumn(Modifier.fillMaxWidth(), contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 24.dp)) { items(state.messages, key = { it.messageId }, contentType = { "searchMail" }) { MailRow(it, open, vm) } }
            }
        }
    }
}

@Composable private fun SettingsScreen(graph: AppGraph, vm: AppViewModel, account: MailAccount?, back: () -> Unit, openPalette: () -> Unit) {
    BackHandler(onBack = back)
    val appearance by vm.appearance.collectAsStateWithLifecycle()
    var credentialDialogOpen by remember { mutableStateOf(false) }
    var credentialText by remember { mutableStateOf("") }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings") },
                navigationIcon = { IconButton(back) { Icon(Icons.Outlined.ArrowBack, contentDescription = "Back") } },
                actions = { IconButton(openPalette) { Icon(Icons.Outlined.MoreHoriz, contentDescription = "Open command palette") } },
            )
        },
    ) { padding ->
        LazyColumn(Modifier.fillMaxSize().padding(padding).padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(account?.email ?: "No account", style = MaterialTheme.typography.titleMedium, maxLines = 1)
                    Text(account?.syncState ?: "Add an account to sync mail", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
                }
            }
            item { SettingsActionRow("Manual refresh", "Sync cached mailbox now") { vm.refresh() } }
            item { SettingsActionRow("Remove account", "Delete local mailbox and credentials", destructive = true) { vm.removeAccount() } }
            if (account != null) item { SettingsActionRow("Update Gmail App Password", "Replace the secure account credential") { credentialDialogOpen = true } }
            item { Text("Appearance", style = MaterialTheme.typography.titleLarge) }
            item { ChoiceSection("Theme", ThemeChoice.entries, appearance.theme) { choice -> vm.updateAppearance { it.copy(theme = choice) } } }
            item { ChoiceSection("Glass quality", GlassQuality.entries, appearance.glassQuality) { choice -> vm.updateAppearance { it.copy(glassQuality = choice) } } }
            item {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("Accessibility", style = MaterialTheme.typography.titleMedium)
                    PreferenceRow("Reduce Transparency", appearance.reduceTransparency) { vm.updateAppearance { it.copy(reduceTransparency = !it.reduceTransparency) } }
                    PreferenceRow("Reduce Motion", appearance.reduceMotion) { vm.updateAppearance { it.copy(reduceMotion = !it.reduceMotion) } }
                    PreferenceRow("Notification previews", appearance.showNotificationPreviews) { vm.updateAppearance { it.copy(showNotificationPreviews = !it.showNotificationPreviews) } }
                }
            }
            item { GlassSurface(appearance.glassQuality, Modifier.fillMaxWidth()) { Text("Glass preview", Modifier.padding(16.dp)) } }
            if (BuildConfig.DEBUG) {
                item { Text("Debug fixtures", style = MaterialTheme.typography.titleMedium) }
                item { Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) { listOf(10, 100, 1000, 10000).forEach { Button({ vm.seed(it) }, modifier = Modifier.weight(1f)) { Text("$it") } } } }
                item { Button({ vm.clear() }, modifier = Modifier.fillMaxWidth()) { Text("Clear debug mailbox") } }
            }
        }
    }
    if (credentialDialogOpen && account != null) {
        AlertDialog(
            onDismissRequest = { credentialDialogOpen = false; credentialText = "" },
            title = { Text("Update credential") },
            text = { OutlinedTextField(credentialText, { credentialText = it }, label = { Text("Google App Password") }, visualTransformation = PasswordVisualTransformation(), singleLine = true) },
            confirmButton = { TextButton(enabled = credentialText.isNotBlank(), onClick = { val chars = credentialText.toCharArray(); credentialText = ""; credentialDialogOpen = false; vm.updateCredential(account.accountId, chars) }) { Text("Store securely") } },
            dismissButton = { TextButton(onClick = { credentialDialogOpen = false; credentialText = "" }) { Text("Cancel") } },
        )
    }
}

@Composable
private fun <T> ChoiceSection(title: String, choices: List<T>, selected: T, onSelect: (T) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, style = MaterialTheme.typography.titleMedium)
        choices.forEach { choice ->
            PreferenceRow(choice.toString().replace('_', ' '), choice == selected) { onSelect(choice) }
        }
    }
}

@Composable
private fun PreferenceRow(title: String, selected: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(if (selected) MaterialTheme.colorScheme.surfaceVariant else Color.Transparent)
            .clickable(onClick = onClick)
            .semantics { stateDescription = if (selected) "Selected" else "Not selected" }
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface)
        Spacer(Modifier.weight(1f))
        Text(if (selected) "✓" else "", color = MaterialTheme.colorScheme.primary)
    }
}

@Composable
private fun SettingsActionRow(title: String, description: String, destructive: Boolean = false, onClick: () -> Unit) {
    Column(Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).clickable(onClick = onClick).padding(horizontal = 4.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(title, color = if (destructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface)
                Text(description, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
            }
            Icon(Icons.Outlined.ChevronRight, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        androidx.compose.material3.HorizontalDivider(color = MaterialTheme.colorScheme.onSurface.copy(alpha = .08f))
    }
}

private fun senderAmbient(sender: String): Color = when ((sender.hashCode() and Int.MAX_VALUE) % 4) {
    0 -> GlassMailPalette.Personal.first
    1 -> GlassMailPalette.Work.first
    2 -> GlassMailPalette.Updates.first
    else -> GlassMailPalette.Newsletters.first
}

private fun syncStatus(state: String): String = if (state.contains("offline", ignoreCase = true) || state.contains("network", ignoreCase = true)) {
    "Offline — showing cached mail"
} else state

private fun replyDraft(message: com.glassmail.domain.mail.MailMessage, account: MailAccount, all: Boolean): MailDraft {
    val headers = ReceivedMailHeaders(replyTo = listOf(message.sender), messageId = message.messageId)
    val recipients = if (all) replyAllRecipients(headers, account.email) else replyRecipients(message, account.email)
    return MailDraft(
        UUID.randomUUID().toString(), account.accountId, to = recipients,
        subject = replySubject(message.subject),
        body = "\n\n— Original message —\n${message.body ?: message.preview}",
        inReplyTo = message.messageId,
        references = referencesForReply(message.messageId, headers.references),
    )
}

private fun forwardDraft(message: com.glassmail.domain.mail.MailMessage, account: MailAccount): MailDraft = MailDraft(
    UUID.randomUUID().toString(), account.accountId,
    subject = forwardSubject(message.subject),
    body = "\n\n— Forwarded message —\nFrom: ${message.sender}\nSubject: ${message.subject}\n\n${message.body ?: message.preview}",
)
