package com.glassmail.designsystem

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.material3.Icon
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/** One bounded navigation surface: rows deliberately never use this material. */
@Composable fun MorphingDock(compact: Boolean, selected: Int, onSelect: (Int) -> Unit) {
    val width by animateDpAsState(if (compact) 168.dp else 360.dp, label = "dockWidth")
    Row(Modifier.navigationBarsPadding().padding(bottom = 8.dp).width(width).clip(RoundedCornerShape(if (compact) 24.dp else 32.dp)).background(Color(0xDD181E28)).padding(8.dp), horizontalArrangement = Arrangement.SpaceEvenly) {
        listOf("Inbox", "Search", "Settings").forEachIndexed { index, label ->
            Box(
                modifier = Modifier.sizeIn(minWidth = 48.dp, minHeight = 48.dp)
                    .semantics { contentDescription = label }
                    .clickable { onSelect(index) },
            ) {
                if (compact) {
                    Icon(
                        imageVector = listOf(Icons.Outlined.Inbox, Icons.Outlined.Search, Icons.Outlined.Settings)[index],
                        contentDescription = null,
                        tint = if (index == selected) Color(0xFF38BDF8) else Color(0xFF9DA8B6),
                        modifier = Modifier.padding(12.dp),
                    )
                } else {
                    Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                        Icon(
                            imageVector = listOf(Icons.Outlined.Inbox, Icons.Outlined.Search, Icons.Outlined.Settings)[index],
                            contentDescription = null,
                            tint = if (index == selected) Color(0xFF38BDF8) else Color(0xFF9DA8B6),
                        )
                        Text(label, color = if (index == selected) Color(0xFF38BDF8) else Color(0xFF9DA8B6), modifier = Modifier.padding(start = 6.dp, end = 8.dp))
                    }
                }
            }
        }
    }
}
