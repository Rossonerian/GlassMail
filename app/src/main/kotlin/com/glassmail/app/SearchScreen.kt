@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.glassmail.app

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Clear
import androidx.compose.material.icons.outlined.History
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Terminal
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
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

private val SEARCH_SUGGESTIONS = listOf(
    "is:unread",
    "has:attachment",
    "is:starred",
    "Google",
    "Invoice",
    "Receipt",
)

@Composable
fun SearchScreen(
    vm: AppViewModel,
    account: MailAccount?,
    quality: GlassQuality,
    open: (String) -> Unit,
    back: () -> Unit,
    openPalette: () -> Unit,
    modifier: Modifier = Modifier,
) {
    BackHandler(onBack = back)
    val state by vm.searchUiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            GlassMailTopCapsule(
                title = "Search Mail",
                subtitle = if (state.query.isNotBlank()) "${state.messages.size} results" else "Local cache index",
                quality = quality,
                navigationIcon = {
                    IconButton(onClick = back) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = openPalette) {
                        Icon(Icons.Outlined.Terminal, contentDescription = "Open command palette")
                    }
                },
            )
        },
        contentWindowInsets = WindowInsets(0),
        modifier = modifier.fillMaxSize(),
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .imePadding()
                .navigationBarsPadding(),
        ) {
            // Search Input Field
            TextField(
                value = state.query,
                onValueChange = vm::setSearchQuery,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = GlassSpacing.md, vertical = GlassSpacing.xs)
                    .clip(RoundedCornerShape(GlassRadius.lg)),
                placeholder = { Text("Search sender, subject, or message preview…") },
                leadingIcon = {
                    Icon(Icons.Outlined.Search, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                },
                trailingIcon = {
                    if (state.query.isNotBlank()) {
                        IconButton(onClick = { vm.setSearchQuery("") }) {
                            Icon(Icons.Outlined.Clear, contentDescription = "Clear search query")
                        }
                    }
                },
                singleLine = true,
                colors = TextFieldDefaults.colors(
                    cursorColor = MaterialTheme.colorScheme.primary,
                    unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f),
                    focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.55f),
                    unfocusedIndicatorColor = Color.Transparent,
                    focusedIndicatorColor = MaterialTheme.colorScheme.primary,
                ),
            )

            // Search query suggestions row
            LazyRow(
                modifier = Modifier.fillMaxWidth(),
                contentPadding = PaddingValues(horizontal = GlassSpacing.md, vertical = GlassSpacing.xs),
                horizontalArrangement = Arrangement.spacedBy(GlassSpacing.xs),
            ) {
                items(SEARCH_SUGGESTIONS) { suggestion ->
                    FilterChip(
                        selected = state.query == suggestion,
                        onClick = { vm.setSearchQuery(suggestion) },
                        label = { Text(suggestion, style = MaterialTheme.typography.labelSmall) },
                        leadingIcon = {
                            Icon(Icons.Outlined.History, contentDescription = null, modifier = Modifier.size(14.dp))
                        },
                    )
                }
            }

            // Results / Empty State
            when {
                state.query.isBlank() -> {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(GlassSpacing.xl),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Icon(
                            Icons.Outlined.Search,
                            contentDescription = null,
                            modifier = Modifier.size(56.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f),
                        )
                        Spacer(Modifier.height(GlassSpacing.md))
                        Text(
                            "Instant Local Search",
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Spacer(Modifier.height(GlassSpacing.xs))
                        Text(
                            "Search across sender, subject, preview, and label metadata cached offline in Room.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                        )
                    }
                }
                state.messages.isEmpty() -> {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(GlassSpacing.xl),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text(
                            "No messages matching \"${state.query}\"",
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Spacer(Modifier.height(GlassSpacing.xs))
                        Text(
                            "Try different keywords, sender addresses, or check spelling.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                else -> {
                    LazyColumn(
                        modifier = Modifier.fillMaxWidth(),
                        contentPadding = PaddingValues(bottom = 110.dp),
                    ) {
                        items(
                            items = state.messages,
                            key = { it.messageId },
                            contentType = { "searchResult" },
                        ) { row ->
                            MailRow(row = row, open = open, vm = vm)
                        }
                    }
                }
            }
        }
    }
}
