@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.glassmail.app

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.FilterList
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material.icons.outlined.MoreHoriz
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.glassmail.designsystem.GlassRadius
import com.glassmail.designsystem.GlassSpacing
import com.glassmail.designsystem.glass.GlassQuality
import com.glassmail.domain.mail.MailAccount
import kotlinx.coroutines.flow.collectLatest

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
    search: () -> Unit,
    settings: () -> Unit,
    openPalette: () -> Unit,
    onDockCompactChanged: (Boolean) -> Unit,
    onDockBackdropChanged: (Any, Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    val state by vm.inboxUiState.collectAsStateWithLifecycle()
    val selectedAccount = state.account ?: account
    val allMessages = state.messages
    val listState = rememberLazyListState()

    var activeFilter by remember { mutableStateOf(InboxFilter.All) }

    val filteredMessages = remember(allMessages, activeFilter) {
        when (activeFilter) {
            InboxFilter.All -> allMessages
            InboxFilter.Unread -> allMessages.filter { it.unread }
            InboxFilter.Starred -> allMessages.filter { it.starred }
        }
    }

    val unreadCount = remember(allMessages) { allMessages.count { it.unread } }

    val compact by remember {
        derivedStateOf {
            listState.firstVisibleItemIndex > 0 || listState.firstVisibleItemScrollOffset > 56
        }
    }

    LaunchedEffect(compact) { onDockCompactChanged(compact) }

    LaunchedEffect(listState) {
        snapshotFlow { listState.firstVisibleItemIndex to listState.firstVisibleItemScrollOffset }
            .collectLatest { onDockBackdropChanged(it, listState.isScrollInProgress) }
    }
    LaunchedEffect(listState) {
        snapshotFlow { listState.isScrollInProgress }
            .collectLatest { onDockBackdropChanged(listState.firstVisibleItemIndex to listState.firstVisibleItemScrollOffset, it) }
    }

    Scaffold(
        topBar = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(GlassSpacing.xs),
            ) {
                GlassMailTopCapsule(
                    title = "GlassMail",
                    subtitle = if (unreadCount > 0) "$unreadCount unread" else "All caught up",
                    quality = quality,
                    navigationIcon = {
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = (selectedAccount?.email?.firstOrNull() ?: 'G').uppercase(),
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.primary,
                            )
                        }
                    },
                    actions = {
                        IconButton(onClick = openPalette) {
                            Icon(Icons.Outlined.MoreHoriz, contentDescription = "Open command palette")
                        }
                        IconButton(onClick = settings) {
                            Icon(Icons.Outlined.Settings, contentDescription = "Open settings")
                        }
                    },
                )

                AnimatedVisibility(
                    visible = !compact,
                    enter = fadeIn(),
                    exit = fadeOut(),
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = GlassSpacing.md),
                        verticalArrangement = Arrangement.spacedBy(GlassSpacing.xs),
                    ) {
                        GlassMailSearchCapsule(
                            quality = quality,
                            placeholder = "Search mail, people, or dates…",
                            onClick = search,
                        )

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
                                    label = {
                                        Text(
                                            when (filter) {
                                                InboxFilter.All -> "All (${allMessages.size})"
                                                InboxFilter.Unread -> "Unread ($unreadCount)"
                                                InboxFilter.Starred -> "Starred (${allMessages.count { it.starred }})"
                                            },
                                        )
                                    },
                                    leadingIcon = if (selected) {
                                        { Icon(Icons.Outlined.Check, contentDescription = null, modifier = Modifier.size(16.dp)) }
                                    } else null,
                                    colors = FilterChipDefaults.filterChipColors(
                                        selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
                                        selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer,
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
                        tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.6f),
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
            filteredMessages.isEmpty() -> {
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
                        if (activeFilter == InboxFilter.All) "Inbox is empty" else "No matching messages",
                        style = MaterialTheme.typography.titleLarge,
                    )
                    Spacer(Modifier.height(GlassSpacing.xs))
                    Text(
                        syncStatus(selectedAccount.syncState),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(GlassSpacing.base))
                    Button(onClick = { vm.refresh() }) {
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
                        .background(MaterialTheme.colorScheme.background)
                        .padding(padding),
                    state = listState,
                    contentPadding = PaddingValues(bottom = 110.dp),
                ) {
                    items(
                        items = filteredMessages,
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
