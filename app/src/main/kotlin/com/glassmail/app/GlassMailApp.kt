@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class, kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package com.glassmail.app

import androidx.compose.foundation.clickable
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.glassmail.designsystem.glass.GlassQuality
import com.glassmail.designsystem.glass.GlassSurface
import com.glassmail.domain.mail.MailAccount
import com.glassmail.domain.mail.MailListItem
import com.glassmail.domain.mail.MailMutation
import com.glassmail.domain.mail.MailRepository
import com.glassmail.sync.AccountSyncScheduler
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch

@Composable
fun GlassMailApp(graph: AppGraph) {
    val vm: AppViewModel = viewModel(factory = AppViewModel.factory(graph.mailRepository, graph.syncScheduler))
    val accounts by vm.accounts.collectAsStateWithLifecycle()
    val navController = rememberNavController()
    androidx.compose.runtime.LaunchedEffect(accounts.isEmpty()) {
        val current = navController.currentBackStackEntry?.destination?.route
        if (accounts.isEmpty() && current != ROUTE_SETUP) {
            navController.navigate(ROUTE_SETUP) { popUpTo(ROUTE_INBOX) { inclusive = true } }
        } else if (accounts.isNotEmpty() && current == ROUTE_SETUP) {
            navController.navigate(ROUTE_INBOX) { popUpTo(ROUTE_SETUP) { inclusive = true } }
        }
    }
    NavHost(navController = navController, startDestination = ROUTE_INBOX) {
        composable(ROUTE_SETUP) { AccountSetupRoute(graph) }
        composable(ROUTE_INBOX) {
            InboxScreen(vm, accounts.firstOrNull(),
                open = { navController.navigate("$ROUTE_READER/$it") },
                search = { navController.navigate(ROUTE_SEARCH) },
                settings = { navController.navigate(ROUTE_SETTINGS) },
            )
        }
        composable(ROUTE_SEARCH) {
            SearchScreen(
                vm = vm,
                account = accounts.firstOrNull(),
                open = { navController.navigate("$ROUTE_READER/$it") },
                back = { navController.popBackStack() },
            )
        }
        composable(ROUTE_SETTINGS) {
            SettingsScreen(vm, accounts.firstOrNull()) { navController.popBackStack() }
        }
        composable(
            route = "$ROUTE_READER/{messageId}",
            arguments = listOf(navArgument("messageId") { type = NavType.StringType }),
        ) { entry ->
            ReaderScreen(vm, entry.arguments?.getString("messageId").orEmpty()) { navController.popBackStack() }
        }
    }
}

private const val ROUTE_SETUP = "setup"
private const val ROUTE_INBOX = "inbox"
private const val ROUTE_SEARCH = "search"
private const val ROUTE_SETTINGS = "settings"
private const val ROUTE_READER = "reader"

class AppViewModel(
    private val repository: MailRepository,
    private val syncScheduler: AccountSyncScheduler,
) : ViewModel() {
    val accounts: StateFlow<List<MailAccount>> = repository.observeAccounts().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    private val accountId = accounts.map { it.firstOrNull()?.accountId }.stateIn(viewModelScope, SharingStarted.Eagerly, null)
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
    companion object {
        fun factory(repository: MailRepository, syncScheduler: AccountSyncScheduler) = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST") override fun <T: ViewModel> create(modelClass: Class<T>) = AppViewModel(repository, syncScheduler) as T
        }
    }
}

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

@Composable private fun InboxScreen(vm: AppViewModel, account: MailAccount?, open: (String) -> Unit, search: () -> Unit, settings: () -> Unit) {
    val state by vm.inboxUiState.collectAsStateWithLifecycle()
    val selectedAccount = state.account ?: account
    val rows = state.messages
    Scaffold(topBar = { TopAppBar(title = { Text("GlassMail") }, actions = { IconButton(search) { Text("⌕") }; IconButton(settings) { Text("⚙") } }) }) { padding ->
        if (selectedAccount == null) Column(Modifier.fillMaxSize().padding(padding).padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) { Text("No account yet"); Button({ vm.seed(100) }) { Text("Seed debug mailbox") } }
        else if (rows.isEmpty()) Column(Modifier.fillMaxSize().padding(padding).padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) { Text("Inbox is empty", style = MaterialTheme.typography.titleLarge); Text(selectedAccount.syncState); Button({ vm.refresh() }) { Text("Refresh") } }
        else LazyColumn(Modifier.fillMaxSize().padding(padding)) { items(rows, key = { it.messageId }, contentType = { "mail" }) { row -> MailRow(row, open, vm) } }
    }
}

@Composable private fun MailRow(row: MailListItem, open: (String) -> Unit, vm: AppViewModel) {
    Row(Modifier.fillMaxWidth().clickable { open(row.messageId) }.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Column(Modifier.weight(1f)) { Text(row.sender, style = if (row.unread) MaterialTheme.typography.titleSmall else MaterialTheme.typography.bodyLarge); Text(row.subject, maxLines = 1); Text(row.preview, maxLines = 2, style = MaterialTheme.typography.bodySmall); if (row.labels.isNotEmpty()) Text(row.labels.joinToString(), style = MaterialTheme.typography.labelSmall) }
        Column {
            Text(if (row.starred) "★" else "☆", Modifier.semantics { contentDescription = if (row.starred) "Unstar message" else "Star message" }.clickable { vm.mutation(row, "star") })
            Text(if (row.unread) "●" else "○", Modifier.semantics { contentDescription = if (row.unread) "Mark message read" else "Mark message unread" }.clickable { vm.mutation(row, "read") })
            Text("⌫", Modifier.semantics { contentDescription = "Archive message" }.clickable { vm.mutation(row, "archive") })
            Text("×", Modifier.semantics { contentDescription = "Delete message" }.clickable { vm.mutation(row, "delete") })
            if (row.hasAttachment) Text("⌁", Modifier.semantics { contentDescription = "Has attachment" })
        }
    }
}

@Composable private fun ReaderScreen(vm: AppViewModel, id: String, back: () -> Unit) {
    BackHandler(onBack = back)
    androidx.compose.runtime.LaunchedEffect(id) { vm.selectReaderMessage(id) }
    val state by vm.readerUiState.collectAsStateWithLifecycle()
    Scaffold(topBar = { TopAppBar(title = { Text("Message") }, navigationIcon = { IconButton(back) { Text("‹") } }) }) { padding -> LazyColumn(Modifier.fillMaxSize().padding(padding).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) { val messages = state.thread.ifEmpty { listOfNotNull(state.selected) }; items(messages, key = { it.messageId }) { item -> Column(verticalArrangement = Arrangement.spacedBy(10.dp)) { Text(item.subject, style = MaterialTheme.typography.headlineSmall); Text(item.sender); Text(item.body ?: item.preview); if (item.messageId == state.selected?.messageId && item.attachments.isNotEmpty()) Text("Attachments: " + item.attachments.joinToString { attachment -> attachment.fileName ?: attachment.mimeType.orEmpty() }); if (item.html) Text("HTML is rendered as safe text; remote content is blocked.", style = MaterialTheme.typography.labelSmall) } } } }
}

@Composable private fun SearchScreen(vm: AppViewModel, account: MailAccount?, open: (String) -> Unit, back: () -> Unit) {
    BackHandler(onBack = back)
    val state by vm.searchUiState.collectAsStateWithLifecycle()
    Scaffold(topBar = { TopAppBar(title = { Text("Search") }, navigationIcon = { IconButton(back) { Text("‹") } }) }) { padding -> Column(Modifier.padding(padding)) { OutlinedTextField(state.query, vm::setSearchQuery, Modifier.fillMaxWidth().padding(12.dp), label = { Text("Search cached mail") }); LazyColumn { items(state.messages, key={it.messageId}) { MailRow(it, open, vm) } } } }
}

@Composable private fun SettingsScreen(vm: AppViewModel, account: MailAccount?, back: () -> Unit) {
    BackHandler(onBack = back)
    // Stable diagnostic default: rendering experiments are opt-in during functional testing.
    var quality by remember { mutableStateOf(GlassQuality.TRANSPARENT) }
    Scaffold(topBar = { TopAppBar(title = { Text("Settings") }, navigationIcon = { IconButton(back) { Text("‹") } }) }) { padding -> Column(Modifier.padding(padding).padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) { Text(account?.email ?: "No account"); Button({ vm.refresh() }) { Text("Manual refresh") }; Button({ vm.removeAccount() }) { Text("Remove account") }; if (BuildConfig.DEBUG) { Text("Debug fixtures"); Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) { listOf(10,100,1000,10000).forEach { Button({ vm.seed(it) }) { Text("$it") } } }; Button({ vm.clear() }) { Text("Clear debug mailbox") } }; Text("Glass quality"); Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) { GlassQuality.entries.forEach { Button({ quality = it }) { Text(it.name) } } }; GlassSurface(quality, Modifier.fillMaxWidth()) { Text("Glass preview", Modifier.padding(16.dp)) } } }
}
