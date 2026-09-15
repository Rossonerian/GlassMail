package com.glassmail.app

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Search
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.glassmail.designsystem.glass.GlassQuality
import com.glassmail.designsystem.glass.GlassSurface

@Composable
fun GlassMailTopCapsule(
    title: String,
    subtitle: String? = null,
    quality: GlassQuality,
    modifier: Modifier = Modifier,
    navigationIcon: (@Composable () -> Unit)? = null,
    actions: @Composable () -> Unit = {},
) {
    GlassSurface(
        quality = quality,
        modifier = modifier.fillMaxWidth().statusBarsPadding().padding(horizontal = 12.dp, vertical = 8.dp),
        shape = androidx.compose.foundation.shape.RoundedCornerShape(20.dp),
    ) {
        Row(
            Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(horizontal = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            navigationIcon?.invoke()
            Column(Modifier.weight(1f).padding(horizontal = if (navigationIcon == null) 8.dp else 4.dp), verticalArrangement = Arrangement.Center) {
                Text(title, style = MaterialTheme.typography.headlineSmall, maxLines = 1)
                subtitle?.let { Text(it.uppercase(), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary, maxLines = 1) }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(0.dp), verticalAlignment = Alignment.CenterVertically) { actions() }
        }
    }
}

@Composable
fun GlassMailSearchCapsule(
    quality: GlassQuality,
    placeholder: String,
    onClick: () -> Unit,
    shortcut: String? = null,
    modifier: Modifier = Modifier,
) {
    GlassSurface(
        quality = quality,
        modifier = modifier.fillMaxWidth().clickable(onClick = onClick).semantics { role = Role.Button },
        shape = androidx.compose.foundation.shape.RoundedCornerShape(16.dp),
    ) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 13.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Outlined.Search, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(22.dp))
            Spacer(Modifier.width(12.dp))
            Text(placeholder, Modifier.weight(1f), color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodyLarge, maxLines = 1)
            shortcut?.let {
                Text(it, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.labelSmall, modifier = Modifier.padding(start = 8.dp))
            }
        }
    }
}

@Composable
fun FlatMetadata(text: String, modifier: Modifier = Modifier, color: Color = MaterialTheme.colorScheme.onSurfaceVariant) {
    Text(text.uppercase(), modifier = modifier, color = color, style = MaterialTheme.typography.labelSmall, maxLines = 1)
}
