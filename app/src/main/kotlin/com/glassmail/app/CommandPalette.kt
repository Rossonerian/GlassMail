package com.glassmail.app

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
    Box(
        Modifier.fillMaxSize()
            .background(Color.Black.copy(alpha = .48f))
            .clickable(onClick = onDismiss),
        contentAlignment = Alignment.TopCenter,
    ) {
        GlassSurface(
            quality = quality,
            shape = RoundedCornerShape(28.dp),
            modifier = Modifier.fillMaxWidth(.92f).padding(top = 72.dp).clickable { },
        ) {
            Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Command palette", style = MaterialTheme.typography.headlineSmall, color = MaterialTheme.colorScheme.onSurface)
                Text("Search, navigate, and act on the current mailbox", color = MaterialTheme.colorScheme.onSurface.copy(alpha = .72f))
                LazyColumn(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    items(actions, key = { it.id }) { command ->
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
                                .padding(vertical = 12.dp, horizontal = 8.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Column(Modifier.weight(1f)) {
                                Text(command.title, color = if (command.destructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface)
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
