@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.glassmail.app

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.Clear
import androidx.compose.material.icons.outlined.FilterList
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material.icons.outlined.MoreHoriz
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.Button
import androidx.compose.material3.Badge
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.glassmail.designsystem.GlassRadius
import com.glassmail.designsystem.GlassSpacing
import com.glassmail.designsystem.glass.GlassQuality
import com.glassmail.domain.mail.MailAccount
import com.glassmail.domain.mail.MailCategory
import kotlinx.coroutines.flow.collect

enum class InboxFilter {
    All,
    Unread,
    Starred,
}

@Composable
fun InboxScreen(
    vm: AppViewModel,
    account: MailAccount?,
    quality: GlassQuality,
    open: (String) -> Unit,
    openPalette: () -> Unit,
    onDockCollapseChanged: (Float) -> Unit,
    listState: LazyListState,
    searchListState: LazyListState,
    searchExpanded: Boolean,
    onSearchExpandedChange: (Boolean) -> Unit,
    onAddAccount: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val state by vm.inboxUiState.collectAsStateWithLifecycle()
    val searchState by vm.searchUiState.collectAsStateWithLifecycle()
    val undoableArchive by vm.undoableArchive.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    val refreshing by vm.isRefreshing.collectAsStateWithLifecycle()
    val selectedAccount = state.account ?: account
    val isSyncing = refreshing || selectedAccount?.syncState?.equals("SYNCING", ignoreCase = true) == true
    val allMessages = state.messages
    var activeFilter by rememberSaveable { mutableStateOf(InboxFilter.All) }
    var restoredCategory by rememberSaveable { mutableStateOf(state.selectedCategory) }
    var restoredSearchQuery by rememberSaveable { mutableStateOf(searchState.query) }
    var accountMenuOpen by remember { mutableStateOf(false) }
    val searchFocusRequester = remember { FocusRequester() }

    BackHandler(enabled = searchExpanded) { onSearchExpandedChange(false) }
    LaunchedEffect(restoredCategory) { vm.selectCategory(restoredCategory) }
    LaunchedEffect(restoredSearchQuery) { vm.setSearchQuery(restoredSearchQuery) }
    LaunchedEffect(searchExpanded) {
        if (searchExpanded) searchFocusRequester.requestFocus()
    }
    LaunchedEffect(undoableArchive?.actionId) {
        val action = undoableArchive ?: return@LaunchedEffect
        val result = snackbarHostState.showSnackbar("Conversation archived", actionLabel = "Undo")
        if (result == SnackbarResult.ActionPerformed) vm.undoArchive(action.actionId)
        else vm.dismissUndoArchive(action.actionId)
    }

    val filteredMessages = remember(allMessages, activeFilter) {
        when (activeFilter) {
            InboxFilter.All -> allMessages
            InboxFilter.Unread -> allMessages.filter { it.unread }
            InboxFilter.Starred -> allMessages.filter { it.starred }
        }
    }

    val unreadCount = remember(allMessages) { allMessages.count { it.unread } }
    val starredCount = remember(allMessages) { allMessages.count { it.starred } }

    val visibleMessages = if (searchExpanded && searchState.query.isNotBlank()) searchState.messages else filteredMessages
    val activeListState = if (searchExpanded) searchListState else listState

    LaunchedEffect(searchState.query, searchExpanded) {
        if (searchExpanded && searchState.query.isNotBlank()) searchListState.scrollToItem(0)
    }

    LaunchedEffect(activeListState) {
        snapshotFlow { activeListState.isScrollInProgress }
            .collect { isScrolling ->
                onDockCollapseChanged(if (isScrolling) 1f else 0f)
            }
    }

    Scaffold(
        containerColor = Color.Transparent,
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(GlassSpacing.xs),
            ) {
                GlassMailTopCapsule(
                    title = if (state.unifiedInbox) "All inboxes" else "Inbox",
                    subtitle = when {
                        searchExpanded && searchState.query.isNotBlank() -> "${searchState.messages.size} results"
                        isSyncing -> "Syncing your mailbox…"
                        selectedAccount?.syncState?.startsWith("ERROR_", ignoreCase = true) == true -> syncStatus(selectedAccount.syncState)
                        allMessages.isEmpty() -> selectedAccount?.let { syncStatus(it.syncState) } ?: "No account connected"
                        unreadCount > 0 -> "$unreadCount unread"
                        else -> "All caught up"
                    },
                    quality = quality,
                    navigationIcon = {
                        Box {
                            Box(
                                modifier = Modifier.size(36.dp).clip(CircleShape)
                                    .background(MaterialTheme.colorScheme.primaryContainer)
                                    .clickable { accountMenuOpen = true },
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    text = if (state.unifiedInbox) "✉" else (selectedAccount?.email?.firstOrNull() ?: 'G').uppercase(),
                                    style = MaterialTheme.typography.titleMedium,
                                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                                )
                            }
                            DropdownMenu(expanded = accountMenuOpen, onDismissRequest = { accountMenuOpen = false }) {
                                state.accounts.forEach { mailboxAccount ->
                                    DropdownMenuItem(
                                        text = { Text(mailboxAccount.email) },
                                        onClick = { accountMenuOpen = false; vm.selectAccount(mailboxAccount.accountId) },
                                    )
                                }
                                if (state.accounts.size > 1) DropdownMenuItem(
                                    text = { Text("Unified inbox") },
                                    onClick = { accountMenuOpen = false; vm.setUnifiedInbox(true) },
                                )
                                if (state.accounts.size < 2) DropdownMenuItem(
                                    text = { Text("Add account") },
                                    onClick = { accountMenuOpen = false; onAddAccount() },
                                )
                            }
                        }
                    },
                    actions = {
                        IconButton(onClick = { onSearchExpandedChange(!searchExpanded) }) {
                            Icon(
                                if (searchExpanded) Icons.Outlined.Clear else Icons.Outlined.Search,
                                contentDescription = if (searchExpanded) "Close search" else "Search mail",
                            )
                        }
                        IconButton(onClick = vm::refresh, enabled = !isSyncing) {
                            if (isSyncing) {
                                androidx.compose.material3.CircularProgressIndicator(
                                    modifier = Modifier.size(18.dp),
                                    strokeWidth = 2.dp,
                                )
                            } else {
                                Icon(Icons.Outlined.Refresh, contentDescription = "Sync mailbox")
                            }
                        }
                        IconButton(onClick = openPalette) {
                            Icon(Icons.Outlined.MoreHoriz, contentDescription = "Open command palette")
                        }
                    },
                )

                if (searchExpanded) {
                    TextField(
                        value = restoredSearchQuery,
                        onValueChange = { query -> restoredSearchQuery = query; vm.setSearchQuery(query) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = GlassSpacing.md, vertical = GlassSpacing.xs)
                            .focusRequester(searchFocusRequester)
                            .clip(RoundedCornerShape(GlassRadius.lg)),
                        placeholder = { Text("Search sender, subject, or message…") },
                        leadingIcon = { Icon(Icons.Outlined.Search, contentDescription = null) },
                        trailingIcon = {
                            if (restoredSearchQuery.isNotBlank()) {
                                IconButton(onClick = { restoredSearchQuery = ""; vm.setSearchQuery("") }) {
                                    Icon(Icons.Outlined.Clear, contentDescription = "Clear search")
                                }
                            }
                        },
                        singleLine = true,
                        colors = TextFieldDefaults.colors(
                            cursorColor = MaterialTheme.colorScheme.primary,
                            focusedContainerColor = MaterialTheme.colorScheme.surface,
                            unfocusedContainerColor = MaterialTheme.colorScheme.surface,
                            focusedIndicatorColor = MaterialTheme.colorScheme.primary,
                            unfocusedIndicatorColor = MaterialTheme.colorScheme.outlineVariant,
                        ),
                    )
                }

                AnimatedVisibility(
                    visible = !searchExpanded,
                    enter = fadeIn(),
                    exit = fadeOut(),
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = GlassSpacing.md),
                        verticalArrangement = Arrangement.spacedBy(GlassSpacing.xs),
                    ) {
                        LazyRow(
                            horizontalArrangement = Arrangement.spacedBy(GlassSpacing.xs),
                            contentPadding = PaddingValues(vertical = 4.dp),
                        ) {
                            items(MailCategory.all) { category ->
                                val selected = restoredCategory == category
                                val unread = state.unreadByCategory[category] ?: 0
                                FilterChip(
                                    selected = selected,
                                    onClick = { restoredCategory = category; vm.selectCategory(category) },
                                    shape = RoundedCornerShape(GlassRadius.chip),
                                    label = {
                                        Row(
                                            horizontalArrangement = Arrangement.spacedBy(GlassSpacing.xs),
                                            verticalAlignment = Alignment.CenterVertically,
                                        ) {
                                            Text(categoryLabel(category), style = MaterialTheme.typography.labelMedium)
                                            if (unread > 0) {
                                                Badge { Text(if (unread > 99) "99+" else unread.toString()) }
                                            }
                                        }
                                    },
                                    leadingIcon = if (selected) {
                                        { Icon(Icons.Outlined.Check, contentDescription = null, modifier = Modifier.size(16.dp)) }
                                    } else null,
                                    colors = FilterChipDefaults.filterChipColors(
                                        selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
                                        selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer,
                                        containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f),
                                        labelColor = MaterialTheme.colorScheme.onSurfaceVariant,
                                    ),
                                )
                            }
                        }

                        // Quick Filter Chips
                        LazyRow(
                            horizontalArrangement = Arrangement.spacedBy(GlassSpacing.xs),
                            contentPadding = PaddingValues(vertical = 4.dp),
                        ) {
                            items(InboxFilter.values()) { filter ->
                                val selected = activeFilter == filter
                                FilterChip(
                                    selected = selected,
                                    onClick = { activeFilter = filter },
                                    shape = RoundedCornerShape(GlassRadius.chip),
                                    label = {
                                        Text(
                                            when (filter) {
                                                InboxFilter.All -> "All (${allMessages.size})"
                                                InboxFilter.Unread -> "Unread ($unreadCount)"
                                                InboxFilter.Starred -> "Starred ($starredCount)"
                                            },
                                            style = MaterialTheme.typography.labelMedium,
                                        )
                                    },
                                    leadingIcon = if (selected) {
                                        { Icon(Icons.Outlined.Check, contentDescription = null, modifier = Modifier.size(16.dp)) }
                                    } else null,
                                    colors = FilterChipDefaults.filterChipColors(
                                        selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
                                        selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer,
                                        containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f),
                                        labelColor = MaterialTheme.colorScheme.onSurfaceVariant,
                                    ),
                                )
                            }
                        }
                    }
                }
            }
        },
        modifier = modifier.fillMaxSize(),
    ) { padding ->
        when {
            selectedAccount == null -> {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                        .padding(GlassSpacing.xl),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Icon(
                        Icons.Outlined.Inbox,
                        contentDescription = null,
                        modifier = Modifier.size(64.dp),
                        tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.7f),
                    )
                    Spacer(Modifier.height(GlassSpacing.base))
                    Text("No Account Connected", style = MaterialTheme.typography.titleLarge)
                    Spacer(Modifier.height(GlassSpacing.xs))
                    Text(
                        "Connect a Gmail account in Settings or seed debug mail.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(GlassSpacing.base))
                    Button(onClick = { vm.seed(100) }) {
                        Text("Seed 100 debug messages")
                    }
                }
            }
            searchExpanded && searchState.isLoading -> {
                Column(
                    modifier = Modifier.fillMaxSize().padding(padding),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    androidx.compose.material3.CircularProgressIndicator()
                    Spacer(Modifier.height(GlassSpacing.md))
                    Text("Searching your cached mail…", style = MaterialTheme.typography.bodyMedium)
                }
            }
            visibleMessages.isEmpty() -> {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                        .padding(GlassSpacing.xl),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Icon(
                        Icons.Outlined.Inbox,
                        contentDescription = null,
                        modifier = Modifier.size(56.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                    )
                    Spacer(Modifier.height(GlassSpacing.md))
                    Text(
                        when {
                            searchExpanded && searchState.query.isNotBlank() -> "No matching messages"
                            activeFilter == InboxFilter.All -> "Inbox is empty"
                            else -> "No matching messages"
                        },
                        style = MaterialTheme.typography.titleLarge,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Spacer(Modifier.height(GlassSpacing.xs))
                    Text(
                        syncStatus(selectedAccount.syncState),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(GlassSpacing.base))
                    Button(onClick = vm::refresh, enabled = !isSyncing) {
                        Icon(Icons.Outlined.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(GlassSpacing.xs))
                        Text("Sync Mailbox")
                    }
                }
            }
            else -> {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                    state = activeListState,
                    contentPadding = PaddingValues(start = GlassSpacing.md, end = GlassSpacing.md, top = GlassSpacing.md, bottom = 128.dp),
                    verticalArrangement = Arrangement.spacedBy(GlassSpacing.md),
                ) {
                    items(
                        items = visibleMessages,
                        key = { it.messageId },
                        contentType = { "mailItem" },
                    ) { row ->
                        MailRow(row = row, open = open, vm = vm)
                    }
                }
            }
        }
    }
}

private fun categoryLabel(category: String): String = when (category) {
    MailCategory.PRIMARY -> "Primary"
    MailCategory.SOCIAL -> "Social"
    MailCategory.PROMOTIONS -> "Promotions"
    MailCategory.UPDATES -> "Updates"
    MailCategory.FORUMS -> "Forums"
    else -> category
}
