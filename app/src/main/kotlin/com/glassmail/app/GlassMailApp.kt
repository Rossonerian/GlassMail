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
import androidx.compose.foundation.layout.height
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
import androidx.compose.material3.Switch
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.size
import androidx.compose.ui.text.style.TextOverflow
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
import com.glassmail.designsystem.glass.BackdropProvider
import com.glassmail.designsystem.glass.LocalBackdropSource
import com.glassmail.designsystem.glass.rememberGlassBackdrop
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
    val accountsLoaded by vm.accountsLoaded.collectAsStateWithLifecycle()
    val appearance by vm.appearance.collectAsStateWithLifecycle()
    val drafts by vm.drafts.collectAsStateWithLifecycle()
    val navController = rememberNavController()
    var paletteOpen by rememberSaveable { mutableStateOf(false) }
    var inboxSearchExpanded by rememberSaveable { mutableStateOf(false) }
    val inboxListState = rememberLazyListState()
    val searchListState = rememberLazyListState()
    val dockCoroutineScope = rememberCoroutineScope()
    val dockCollapseState = remember { androidx.compose.runtime.mutableFloatStateOf(0f) }
    val currentRoute by navController.currentBackStackEntryAsState()
    val notificationId by notificationMessageId.collectAsStateWithLifecycle()
    val route = currentRoute?.destination?.route
    LaunchedEffect(route) {
        if (route != ROUTE_INBOX) inboxSearchExpanded = false
    }
    val dark = when (appearance.theme) {
        ThemeChoice.DARK -> true
        ThemeChoice.LIGHT -> false
        ThemeChoice.SYSTEM -> androidx.compose.foundation.isSystemInDarkTheme()
    }
    val ambient = when {
        route == ROUTE_SETTINGS -> GlassMailPalette.Personal
        route?.startsWith(ROUTE_READER) == true -> GlassMailPalette.Personal
        else -> GlassMailPalette.Priority
    }
    fun openCompose(seed: MailDraft? = null) {
        val account = seed?.let { draft -> accounts.firstOrNull { it.accountId == draft.accountId } } ?: vm.currentAccount() ?: return
        val draft = seed ?: MailDraft(UUID.randomUUID().toString(), account.accountId)
        vm.saveDraft(draft)
        navController.navigate("$ROUTE_COMPOSE/${draft.draftId}")
    }
    BackHandler(enabled = paletteOpen) { paletteOpen = false }
    androidx.compose.runtime.LaunchedEffect(accounts.isEmpty(), accountsLoaded) {
        if (!accountsLoaded) return@LaunchedEffect
        val current = navController.currentBackStackEntry?.destination?.route
        if (accounts.isEmpty() && current != ROUTE_SETUP) {
            navController.navigate(ROUTE_SETUP) { popUpTo(ROUTE_INBOX) { inclusive = true } }
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
    AmbientCanvas(ambient, dark = dark) {
        val rootBackdrop = rememberGlassBackdrop()
        androidx.compose.runtime.CompositionLocalProvider(
            LocalBackdropSource provides rootBackdrop,
        ) {
        Box(Modifier.fillMaxSize()) {
            BackdropProvider(backdrop = rootBackdrop, modifier = Modifier.fillMaxSize()) {
                    NavHost(navController = navController, startDestination = ROUTE_INBOX) {
                        composable(ROUTE_SETUP) {
                            AccountSetupRoute(graph) {
                                navController.navigate(ROUTE_INBOX) {
                                    popUpTo(ROUTE_SETUP) { inclusive = true }
                                    launchSingleTop = true
                                }
                            }
                        }
                        composable(ROUTE_INBOX) {
                            InboxScreen(
                                vm = vm,
                                account = if (appearance.unifiedInbox) null else vm.currentAccount(),
                                quality = appearance.glassQuality,
                                open = { navController.navigate("$ROUTE_READER/$it") },
                                openPalette = { paletteOpen = true },
                                onDockCollapseChanged = { dockCollapseState.floatValue = it },
                                listState = inboxListState,
                                searchListState = searchListState,
                                searchExpanded = inboxSearchExpanded,
                                onSearchExpandedChange = { inboxSearchExpanded = it },
                                onAddAccount = { navController.navigate(ROUTE_SETUP) },
                            )
                        }
                        composable(ROUTE_SETTINGS) {
                            SettingsScreen(
                                graph = graph,
                                vm = vm,
                                account = vm.currentAccount(),
                                back = { navController.popBackStack() },
                                openPalette = { paletteOpen = true },
                                openLab = { navController.navigate(ROUTE_GLASS_LAB) },
                            )
                        }
                        composable(ROUTE_GLASS_LAB) {
                            GlassLabScreen(
                                quality = appearance.glassQuality,
                                back = { navController.popBackStack() },
                            )
                        }
                        composable("$ROUTE_COMPOSE/{draftId}") { entry ->
                            val draftId = entry.arguments?.getString("draftId")?.takeUnless { it == "new" }
                            val draftAccount = drafts.firstOrNull { it.draftId == draftId }
                                ?.let { draft -> accounts.firstOrNull { it.accountId == draft.accountId } }
                            ComposeRoute(
                                graph = graph,
                                account = draftAccount ?: vm.currentAccount(),
                                quality = appearance.glassQuality,
                                draftId = draftId,
                                back = { navController.popBackStack() },
                            )
                        }
                        composable(
                            route = "$ROUTE_READER/{messageId}",
                            arguments = listOf(navArgument("messageId") { type = NavType.StringType }),
                        ) { entry ->
                            ReaderScreen(
                                vm = vm,
                                account = entry.arguments?.getString("messageId")?.let(vm::accountForMessage),
                                id = entry.arguments?.getString("messageId").orEmpty(),
                                quality = appearance.glassQuality,
                                back = { navController.popBackStack() },
                                openPalette = { paletteOpen = true },
                                compose = { draft -> openCompose(draft) },
                                download = { attachment -> vm.downloadAttachment(attachment) },
                            )
                        }
                    }
            }

            val dockSelectedIndex = when (route) {
                ROUTE_INBOX -> 0
                ROUTE_SETTINGS, ROUTE_GLASS_LAB -> 1
                else -> null
            }
            if (dockSelectedIndex != null) {
                MorphingDock(
                    selectedIndex = dockSelectedIndex,
                    quality = appearance.glassQuality,
                    onSelect = { destination ->
                        val target = when (destination) {
                            0 -> ROUTE_INBOX
                            1 -> ROUTE_SETTINGS
                            else -> return@MorphingDock
                        }
                        if (route != target) navController.navigate(target) { launchSingleTop = true }
                    },
                    onCompose = { openCompose() },
                    onInboxHold = {
                        inboxSearchExpanded = false
                        dockCoroutineScope.launch { inboxListState.animateScrollToItem(0) }
                    },
                    collapseFraction = { if (route == ROUTE_INBOX) dockCollapseState.floatValue else 0f },
                    backdropSource = rootBackdrop,
                    modifier = Modifier.align(Alignment.BottomCenter),
                )
            }
            if (paletteOpen) {
                val selected = if (route?.startsWith(ROUTE_READER) == true) vm.readerUiState.collectAsStateWithLifecycle().value.selected else null
                val actions = buildList {
                    add(CommandPaletteAction("inbox", "Inbox", "Open cached mailbox") { paletteOpen = false; navController.navigate(ROUTE_INBOX) })
                    add(CommandPaletteAction("settings", "Settings", "Appearance and account") { paletteOpen = false; navController.navigate(ROUTE_SETTINGS) })
                    add(CommandPaletteAction("lab", "Glass Optical Lab", "Interactive shader sandbox") { paletteOpen = false; navController.navigate(ROUTE_GLASS_LAB) })
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
                CommandPalette(actions, appearance.glassQuality, backdropSource = rootBackdrop, onDismiss = { paletteOpen = false })
            }
        }
        }
    }
}
}
}

private const val ROUTE_SETUP = "setup"
private const val ROUTE_INBOX = "inbox"
private const val ROUTE_SETTINGS = "settings"
private const val ROUTE_READER = "reader"
private const val ROUTE_COMPOSE = "compose"
private const val ROUTE_GLASS_LAB = "glass_lab"
