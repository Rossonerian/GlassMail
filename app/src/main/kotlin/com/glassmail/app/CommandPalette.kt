package com.glassmail.app

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Clear
import androidx.compose.material.icons.outlined.Search
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.glassmail.designsystem.glass.GlassQuality
import com.glassmail.designsystem.glass.GlassSurface

data class CommandPaletteAction(
    val id: String,
    val title: String,
    val subtitle: String? = null,
    val enabled: Boolean = true,
    val destructive: Boolean = false,
    val action: () -> Unit,
)

@Composable
fun CommandPalette(
    actions: List<CommandPaletteAction>,
    quality: GlassQuality,
    onDismiss: () -> Unit,
) {
    var query by remember { mutableStateOf("") }
    val filtered = actions.filter { action ->
        query.isBlank() || action.title.contains(query, true) || action.subtitle.orEmpty().contains(query, true)
    }
    Box(
        Modifier.fillMaxSize()
            .background(Color.Black.copy(alpha = .48f))
            .clickable(onClick = onDismiss),
        contentAlignment = Alignment.BottomCenter,
    ) {
        GlassSurface(
            quality = quality,
            shape = RoundedCornerShape(28.dp),
            modifier = Modifier.fillMaxWidth(.96f).heightIn(max = 680.dp).navigationBarsPadding().padding(horizontal = 10.dp, vertical = 12.dp).clickable { },
        ) {
            Column(Modifier.padding(horizontal = 6.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.fillMaxWidth().padding(bottom = 2.dp), contentAlignment = Alignment.Center) {
                    Box(Modifier.padding(bottom = 2.dp).fillMaxWidth(.12f).heightIn(min = 4.dp).background(MaterialTheme.colorScheme.onSurface.copy(alpha = .24f), RoundedCornerShape(8.dp)))
                }
                Text("Search & command", style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.onSurface)
                TextField(
                    value = query,
                    onValueChange = { query = it },
                    modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
                    placeholder = { Text("Search commands…") },
                    leadingIcon = { Icon(Icons.Outlined.Search, contentDescription = null) },
                    trailingIcon = { if (query.isNotBlank()) IconButton({ query = "" }) { Icon(Icons.Outlined.Clear, contentDescription = "Clear command search") } },
                    singleLine = true,
                    colors = TextFieldDefaults.colors(
                        unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = .40f),
                        focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = .55f),
                        unfocusedIndicatorColor = Color.Transparent,
                        focusedIndicatorColor = MaterialTheme.colorScheme.primary,
                    ),
                )
                Text("COMMANDS · ${filtered.size}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                LazyColumn(Modifier.heightIn(max = 450.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    items(filtered, key = { it.id }) { command ->
                        Row(
                            Modifier.fillMaxWidth()
                                .semantics {
                                    role = Role.Button
                                    contentDescription = buildString {
                                        append(command.title)
                                        command.subtitle?.let { append(". ").append(it) }
                                    }
                                    if (!command.enabled) stateDescription = "Disabled"
                                }
                                .clickable(enabled = command.enabled, onClick = command.action)
                                .heightIn(min = 56.dp).padding(vertical = 8.dp, horizontal = 10.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Column(Modifier.weight(1f)) {
                                Text(command.title, style = MaterialTheme.typography.titleSmall, color = if (command.destructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface)
                                command.subtitle?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurface.copy(alpha = .72f)) }
                            }
                            Text(if (command.enabled) "›" else "—", color = MaterialTheme.colorScheme.onSurface.copy(alpha = .72f))
                        }
                    }
                }
            }
        }
    }
}
