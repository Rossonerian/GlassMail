@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.glassmail.app

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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.MoreHoriz
import androidx.compose.material.icons.outlined.Science
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.glassmail.designsystem.GlassRadius
import com.glassmail.designsystem.GlassSpacing
import com.glassmail.designsystem.glass.BackdropSource
import com.glassmail.designsystem.glass.GlassPresets
import com.glassmail.designsystem.glass.GlassQuality
import com.glassmail.designsystem.glass.GlassSurface
import com.glassmail.designsystem.glass.GlassTier
import com.glassmail.domain.mail.MailAccount

@Composable
fun SettingsScreen(
    graph: AppGraph,
    vm: AppViewModel,
    account: MailAccount?,
    back: () -> Unit,
    openPalette: () -> Unit,
    openLab: () -> Unit,
    modifier: Modifier = Modifier,
) {
    BackHandler(onBack = back)
    val appearance by vm.appearance.collectAsStateWithLifecycle()
    var credentialDialogOpen by remember { mutableStateOf(false) }
    var credentialText by remember { mutableStateOf("") }

    Scaffold(
        topBar = {
            GlassMailTopCapsule(
                title = "Settings",
                subtitle = "Preferences & Diagnostics",
                quality = appearance.glassQuality,
                navigationIcon = {
                    IconButton(onClick = back) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = openPalette) {
                        Icon(Icons.Outlined.MoreHoriz, contentDescription = "Open command palette")
                    }
                },
            )
        },
        modifier = modifier.fillMaxSize(),
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = GlassSpacing.lg),
            contentPadding = PaddingValues(bottom = 110.dp),
            verticalArrangement = Arrangement.spacedBy(GlassSpacing.md),
        ) {
            // Account Information
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(GlassRadius.md))
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f))
                        .padding(GlassSpacing.md),
                    verticalArrangement = Arrangement.spacedBy(GlassSpacing.xxs),
                ) {
                    Text(
                        account?.email ?: "No account connected",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        account?.syncState ?: "Add an account to synchronize mail",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }

            // Account Actions
            item {
                SettingsActionRow("Manual Sync", "Synchronize cached mailbox now") { vm.refresh() }
            }
            if (account != null) {
                item {
                    SettingsActionRow("Update Gmail App Password", "Replace the Android Keystore credential") {
                        credentialDialogOpen = true
                    }
                }
                item {
                    SettingsActionRow("Remove Account", "Delete local mailbox metadata and credential", destructive = true) {
                        vm.removeAccount()
                    }
                }
            }

            // Glass Lab Link
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(GlassRadius.md))
                        .background(MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f))
                        .clickable(onClick = openLab)
                        .padding(GlassSpacing.md),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        Icons.Outlined.Science,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(24.dp),
                    )
                    Spacer(Modifier.width(GlassSpacing.md))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            "Glass Optical Lab",
                            style = MaterialTheme.typography.titleSmall,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                        )
                        Text(
                            "Interactive AGSL shader test sandbox & frame diagnostics",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f),
                        )
                    }
                    Icon(
                        Icons.Outlined.ChevronRight,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                    )
                }
            }

            // Appearance Section
            item {
                Text("APPEARANCE", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
            }
            item {
                ChoiceSection("Theme Mode", ThemeChoice.entries, appearance.theme) { choice ->
                    vm.updateAppearance { it.copy(theme = choice) }
                }
            }
            item {
                ChoiceSection("Glass Quality Tier", GlassQuality.entries, appearance.glassQuality) { choice ->
                    vm.updateAppearance { it.copy(glassQuality = choice) }
                }
            }

            // Accessibility Section
            item {
                Text("ACCESSIBILITY", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
            }
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(GlassRadius.md))
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.25f))
                        .padding(GlassSpacing.xs),
                    verticalArrangement = Arrangement.spacedBy(GlassSpacing.xs),
                ) {
                    PreferenceRow(
                        title = "Reduce Transparency",
                        selected = appearance.reduceTransparency,
                        onClick = { vm.updateAppearance { it.copy(reduceTransparency = !it.reduceTransparency) } },
                    )
                    PreferenceRow(
                        title = "Reduce Motion",
                        selected = appearance.reduceMotion,
                        onClick = { vm.updateAppearance { it.copy(reduceMotion = !it.reduceMotion) } },
                    )
                }
            }

            // Notifications Section
            item {
                Text("NOTIFICATIONS", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
            }
            item {
                PreferenceRow(
                    title = "Show Message Previews",
                    selected = appearance.showNotificationPreviews,
                    onClick = { vm.updateAppearance { it.copy(showNotificationPreviews = !it.showNotificationPreviews) } },
                )
            }

            // Live Surface Sample
            item {
                Text("LIVE GLASS PREVIEW", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                Spacer(Modifier.height(GlassSpacing.xs))
                val previewLayer = rememberGraphicsLayer()
                var previewOffset by remember { mutableStateOf(Offset.Zero) }
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(130.dp)
                        .clip(RoundedCornerShape(GlassRadius.card))
                        .onGloballyPositioned { coords ->
                            val b = coords.boundsInWindow()
                            previewOffset = Offset(b.left, b.top)
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    // Vibrant rich pattern backdrop
                    Box(
                        modifier = Modifier
                            .matchParentSize()
                            .drawWithContent {
                                previewLayer.record {
                                    this@drawWithContent.drawContent()
                                }
                                drawLayer(previewLayer)
                            }
                            .background(
                                Brush.linearGradient(
                                    listOf(
                                        Color(0xFF38BDF8),
                                        Color(0xFF818CF8),
                                        Color(0xFFC084FC),
                                        Color(0xFFF472B6),
                                    ),
                                ),
                            ),
                    ) {
                        Box(
                            Modifier
                                .size(80.dp)
                                .align(Alignment.TopStart)
                                .offset((-20).dp, (-20).dp)
                                .clip(CircleShape)
                                .background(Color.White.copy(alpha = 0.35f)),
                        )
                        Box(
                            Modifier
                                .size(100.dp)
                                .align(Alignment.BottomEnd)
                                .offset(20.dp, 20.dp)
                                .clip(CircleShape)
                                .background(Color.Black.copy(alpha = 0.25f)),
                        )
                        Text(
                            "OPTICAL GLASS TEST",
                            style = MaterialTheme.typography.labelMedium,
                            color = Color.White.copy(alpha = 0.5f),
                            modifier = Modifier.align(Alignment.Center),
                        )
                    }

                    // Floating Glass Surface sampling the backdrop
                    val material = when (appearance.glassQuality) {
                        GlassQuality.AUTOMATIC, GlassQuality.LIQUID -> GlassPresets.Toolbar.copy(refraction = 0.20f, dispersion = 0.15f)
                        GlassQuality.BLUR -> GlassPresets.Toolbar.copy(refraction = 0f, dispersion = 0f)
                        GlassQuality.TRANSPARENT -> GlassPresets.Toolbar.copy(opacity = 0.75f, refraction = 0f, dispersion = 0f, blur = 0.dp)
                    }
                    val tier = when (appearance.glassQuality) {
                        GlassQuality.AUTOMATIC, GlassQuality.LIQUID -> GlassTier.FULL
                        GlassQuality.BLUR -> GlassTier.LITE
                        GlassQuality.TRANSPARENT -> GlassTier.ACCESSIBILITY
                    }
                    GlassSurface(
                        material = material,
                        tierOverride = tier,
                        shape = RoundedCornerShape(GlassRadius.card),
                        backdropSampling = true,
                        backdropSource = BackdropSource(layer = previewLayer, providerOffsetInWindow = previewOffset),
                        modifier = Modifier
                            .fillMaxWidth(0.92f)
                            .padding(GlassSpacing.xs),
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(GlassSpacing.base),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Column {
                                Text("Realtime Lens Surface", style = MaterialTheme.typography.titleSmall)
                                Text(
                                    "Quality: ${appearance.glassQuality.name}",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
            }

            // Debug Fixtures (Debug Only)
            if (BuildConfig.DEBUG) {
                item {
                    Text("DEBUG FIXTURES", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.error)
                }
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(GlassSpacing.xs),
                    ) {
                        listOf(10, 100, 1000).forEach { count ->
                            Button(
                                onClick = { vm.seed(count) },
                                modifier = Modifier.weight(1f),
                            ) {
                                Text("$count")
                            }
                        }
                    }
                }
                item {
                    Button(
                        onClick = { vm.clear() },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Clear Debug Mailbox")
                    }
                }
            }
        }
    }

    if (credentialDialogOpen && account != null) {
        AlertDialog(
            onDismissRequest = {
                credentialDialogOpen = false
                credentialText = ""
            },
            title = { Text("Update Gmail Credential") },
            text = {
                OutlinedTextField(
                    value = credentialText,
                    onValueChange = { credentialText = it },
                    label = { Text("Google App Password") },
                    visualTransformation = PasswordVisualTransformation(),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            },
            confirmButton = {
                TextButton(
                    enabled = credentialText.isNotBlank(),
                    onClick = {
                        val chars = credentialText.toCharArray()
                        credentialText = ""
                        credentialDialogOpen = false
                        vm.updateCredential(account.accountId, chars)
                    },
                ) {
                    Text("Store Securely")
                }
            },
            dismissButton = {
                TextButton(
                    onClick = {
                        credentialDialogOpen = false
                        credentialText = ""
                    },
                ) {
                    Text("Cancel")
                }
            },
        )
    }
}

@Composable
fun <T> ChoiceSection(
    title: String,
    choices: List<T>,
    selected: T,
    onSelect: (T) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(GlassSpacing.xs)) {
        Text(title, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface)
        val rows = if (choices.size > 3) choices.chunked(2) else listOf(choices)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(GlassRadius.md))
                .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.38f))
                .padding(4.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            rows.forEach { row ->
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    row.forEach { choice ->
                        val isSelected = choice == selected
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .heightIn(min = 48.dp)
                                .clip(RoundedCornerShape(8.dp))
                                .background(if (isSelected) MaterialTheme.colorScheme.primaryContainer else Color.Transparent)
                                .clickable { onSelect(choice) }
                                .semantics {
                                    role = Role.RadioButton
                                    stateDescription = if (isSelected) "Selected" else "Not selected"
                                },
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = prettyChoice(choice),
                                color = if (isSelected) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurfaceVariant,
                                style = MaterialTheme.typography.labelMedium,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun PreferenceRow(
    title: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 52.dp)
            .clip(RoundedCornerShape(GlassRadius.sm))
            .background(if (selected) MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f) else Color.Transparent)
            .clickable(onClick = onClick)
            .semantics { stateDescription = if (selected) "Selected" else "Not selected" }
            .padding(horizontal = GlassSpacing.md, vertical = GlassSpacing.xs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            title,
            style = MaterialTheme.typography.bodyMedium,
            color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
        )
        Spacer(Modifier.weight(1f))
        Switch(checked = selected, onCheckedChange = { onClick() })
    }
}

@Composable
fun SettingsActionRow(
    title: String,
    description: String,
    destructive: Boolean = false,
    onClick: () -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 56.dp)
                .clickable(onClick = onClick)
                .padding(horizontal = GlassSpacing.xs, vertical = GlassSpacing.sm),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    title,
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (destructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Icon(Icons.Outlined.ChevronRight, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.25f))
    }
}

private fun prettyChoice(value: Any?): String =
    value.toString().lowercase().replace('_', ' ').replaceFirstChar { it.uppercase() }
