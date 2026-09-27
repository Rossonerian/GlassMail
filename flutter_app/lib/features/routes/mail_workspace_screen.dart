import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:glassmail_domain_mail/glassmail_domain_mail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/mail_services.dart';
import '../../app/app_shortcuts.dart';
import '../../app/encrypted_mail_backup.dart';
import '../../app/mail_link_preview.dart';
import '../../app/user_preferences.dart';
import '../../app/workflow_store.dart';
import '../../design/glass_mail_glass.dart';
import '../../platform/delayed_send_coordinator.dart';
import '../../platform/mail_notifications.dart';
import 'mail_html_text.dart';
import '../inbox/inbox_screen.dart';
import '../glass_lab/glass_lab_screen.dart';

class MailWorkspaceScreen extends StatefulWidget {
  const MailWorkspaceScreen({
    super.key,
    required this.repository,
    required this.preferences,
    required this.workflowStore,
    this.delayedSendCoordinator,
  });

  final MailRepository repository;
  final MailUserPreferences preferences;
  final MailWorkflowStore workflowStore;
  final DelayedSendCoordinator? delayedSendCoordinator;

  @override
  State<MailWorkspaceScreen> createState() => _MailWorkspaceScreenState();
}

class _MailWorkspaceScreenState extends State<MailWorkspaceScreen>
    with RestorationMixin {
  static const _destinations = ['Inbox', 'Search', 'Sent', 'Settings'];
  final _selected = RestorableInt(0);
  final _collapsed = RestorableBool(false);
  final _unified = RestorableBool(false);
  final _category = RestorableString(MailCategory.primary);
  final _accountId = RestorableStringN(null);
  double _dragTravel = 0;
  int _dragDirection = 0;
  String? _savedSearchQuery;

  @override
  String get restorationId => 'mail-workspace';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_selected, 'selected-destination');
    registerForRestoration(_collapsed, 'dock-collapsed');
    registerForRestoration(_unified, 'unified-inbox');
    registerForRestoration(_category, 'inbox-category');
    registerForRestoration(_accountId, 'selected-account');
    if (_selected.value < 0 || _selected.value >= _destinations.length) {
      _selected.value = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    notificationRouteController.addListener(_onNotificationTap);
    appShortcutController.addListener(_onAppShortcut);
    if (notificationRouteController.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onNotificationTap());
    }
    if (appShortcutController.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onAppShortcut());
    }
  }

  @override
  void dispose() {
    notificationRouteController.removeListener(_onNotificationTap);
    appShortcutController.removeListener(_onAppShortcut);
    _selected.dispose();
    _collapsed.dispose();
    _unified.dispose();
    _category.dispose();
    _accountId.dispose();
    super.dispose();
  }

  void _onNotificationTap() {
    final messageId = notificationRouteController.value;
    if (messageId == null || messageId.isEmpty) return;
    notificationRouteController.value = null;
    unawaited(_openNotification(messageId));
  }

  void _onAppShortcut() {
    final action = appShortcutController.value;
    if (action == null) return;
    appShortcutController.value = null;
    switch (action) {
      case appShortcutCompose:
        unawaited(_composeFromShortcut());
      case appShortcutInbox:
        _select(0);
      case appShortcutSearch:
        _select(1);
    }
  }

  Future<void> _composeFromShortcut() async {
    final accounts = await widget.repository.observeAccounts().first;
    final account =
        accounts
            .where((candidate) => candidate.accountId == _accountId.value)
            .firstOrNull ??
        accounts.firstOrNull;
    if (!mounted) return;
    if (account == null) {
      _addAccount();
    } else {
      _compose(account);
    }
  }

  Future<void> _openNotification(String messageId) async {
    final accounts = await widget.repository.observeAccounts().first;
    for (final account in accounts) {
      final inbox = await widget.repository
          .observeInbox(account.accountId)
          .first;
      final item = inbox
          .where((message) => message.messageId == messageId)
          .firstOrNull;
      if (item != null && mounted) {
        _openMessage(item, account);
        return;
      }
    }
  }

  bool _onScroll(ScrollNotification event) {
    if (event.depth != 0) return false;
    if (event is ScrollStartNotification || event is ScrollEndNotification) {
      _dragTravel = 0;
      _dragDirection = 0;
    } else if (event is ScrollUpdateNotification && event.dragDetails != null) {
      final delta = event.scrollDelta ?? 0;
      final direction = delta.compareTo(0);
      if (direction != 0) {
        if (_dragDirection != direction) {
          _dragDirection = direction;
          _dragTravel = 0;
        }
        _dragTravel += delta.abs();
        final collapse =
            !_collapsed.value && direction > 0 && _dragTravel >= 72;
        final expand =
            _collapsed.value &&
            ((direction < 0 && _dragTravel >= 48) || event.metrics.pixels <= 0);
        if (collapse || expand) {
          setState(() => _collapsed.value = collapse);
          _dragTravel = 0;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<MailAccount>>(
    stream: widget.repository.observeAccounts(),
    builder: (context, snapshot) {
      final accounts = snapshot.data ?? const <MailAccount>[];
      final active =
          accounts.where((a) => a.accountId == _accountId.value).firstOrNull ??
          accounts.firstOrNull;
      if (active?.accountId != _accountId.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _accountId.value = active?.accountId);
        });
      }
      return Scaffold(
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: IndexedStack(
            index: _selected.value,
            children: [
              _InboxRoute(
                repository: widget.repository,
                account: active,
                accounts: accounts,
                unified: _unified.value,
                category: _category.value,
                workflowStore: widget.workflowStore,
                onSelectAccount: (accountId) => setState(() {
                  _accountId.value = accountId;
                  _unified.value = false;
                }),
                onSetUnified: (value) => setState(() => _unified.value = value),
                onCategoryChanged: (value) =>
                    setState(() => _category.value = value),
                onOpen: _openMessage,
                onCompose: () => _compose(active),
                onSearch: () => _select(1),
                onSettings: () => _select(3),
                onGlassLab: _openGlassLab,
              ),
              _SearchRoute(
                repository: widget.repository,
                account: active,
                accounts: accounts,
                unified: _unified.value,
                initialQuery: _savedSearchQuery ?? '',
                key: ValueKey(_savedSearchQuery),
                onOpen: _openMessage,
              ),
              _SentRoute(
                repository: widget.repository,
                account: active,
                onOpen: (item) => _openMessage(
                  item,
                  active,
                  mailboxId: active == null ? null : '${active.accountId}:SENT',
                ),
              ),
              _SettingsRoute(
                repository: widget.repository,
                accounts: accounts,
                preferences: widget.preferences,
                workflowStore: widget.workflowStore,
                delayedSendCoordinator: widget.delayedSendCoordinator,
                onAddAccount: _addAccount,
                onAccountChanged: (account) => setState(() {
                  _accountId.value = account.accountId;
                  _unified.value = false;
                  _selected.value = 0;
                }),
                onOpenDrafts: _openDrafts,
                onGlassLab: _openGlassLab,
                onOpenSavedView: (view) => setState(() {
                  _savedSearchQuery = view.query;
                  _selected.value = 1;
                }),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SizedBox(
          height: 24 + mailDockContentHeight(context),
          child: MorphingMailDock(
            collapsed: _collapsed.value,
            selected: _destinations[_selected.value],
            onDestinationSelected: (destination) {
              final index = _destinations.indexOf(destination);
              if (index >= 0) setState(() => _selected.value = index);
            },
            onQuickSearch: () => _select(1),
          ),
        ),
      );
    },
  );

  void _select(int index) => setState(() => _selected.value = index);

  void _openMessage(
    MailListItem item,
    MailAccount? account, {
    String? mailboxId,
  }) {
    if (account == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ReaderRoute(
          repository: widget.repository,
          account: account,
          messageId: item.messageId,
          mailboxId: mailboxId ?? '${account.accountId}:INBOX',
          workflowStore: widget.workflowStore,
          onReply: (message) => _composeFromMessage(account, message),
          onReplyAll: (message) =>
              _composeFromMessage(account, message, replyAll: true),
          onForward: (message) =>
              _composeFromMessage(account, message, forward: true),
        ),
      ),
    );
  }

  void _composeFromMessage(
    MailAccount account,
    MailMessage message, {
    bool replyAll = false,
    bool forward = false,
  }) {
    final draftId = 'draft-${DateTime.now().microsecondsSinceEpoch}';
    final body = message.body ?? message.preview;
    final draft = forward
        ? MailDraft(
            draftId: draftId,
            accountId: account.accountId,
            subject: forwardSubject(message.subject),
            body:
                '\n\n— Forwarded message —\nFrom: ${message.sender}'
                '\nSubject: ${message.subject}\n\n$body',
          )
        : MailDraft(
            draftId: draftId,
            accountId: account.accountId,
            to: replyAll
                ? replyAllRecipients(
                    ReceivedMailHeaders(
                      replyTo: [message.sender],
                      messageId: message.messageId,
                    ),
                    account.email,
                  )
                : replyRecipients(message, account.email),
            subject: replySubject(message.subject),
            body: '\n\n— Original message —\n$body',
            inReplyTo: message.messageId,
            references: referencesForReply(message.messageId, const []),
          );
    _compose(account, draft: draft);
  }

  void _compose(MailAccount? account, {MailMessage? reply, MailDraft? draft}) {
    if (account == null) {
      _addAccount();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ComposeRoute(
          repository: widget.repository,
          account: account,
          workflowStore: widget.workflowStore,
          delayedSendCoordinator: widget.delayedSendCoordinator,
          reply: reply,
          draft: draft,
        ),
      ),
    );
  }

  void _openDrafts(MailAccount account) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DraftsRoute(
          repository: widget.repository,
          account: account,
          onOpen: (draft) {
            Navigator.of(context).pop();
            _compose(account, draft: draft);
          },
        ),
      ),
    );
  }

  void _addAccount() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _AccountSetupRoute(repository: widget.repository),
    ),
  );

  void _openGlassLab() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const GlassLabScreen()));
}

class _InboxRoute extends StatelessWidget {
  const _InboxRoute({
    required this.repository,
    required this.account,
    required this.accounts,
    required this.unified,
    required this.category,
    required this.workflowStore,
    required this.onSelectAccount,
    required this.onSetUnified,
    required this.onCategoryChanged,
    required this.onOpen,
    required this.onCompose,
    required this.onSearch,
    required this.onSettings,
    required this.onGlassLab,
  });

  final MailRepository repository;
  final MailAccount? account;
  final List<MailAccount> accounts;
  final bool unified;
  final String category;
  final MailWorkflowStore workflowStore;
  final ValueChanged<String> onSelectAccount;
  final ValueChanged<bool> onSetUnified;
  final ValueChanged<String> onCategoryChanged;
  final void Function(MailListItem, MailAccount?, {String? mailboxId}) onOpen;
  final VoidCallback onCompose;
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final VoidCallback onGlassLab;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    if (accounts.isEmpty || account == null) {
      return _RouteScaffold(
        title: 'Inbox',
        trailing: IconButton(
          tooltip: 'Glass Lab',
          onPressed: onGlassLab,
          icon: const Icon(Icons.blur_on_rounded),
        ),
        child: _EmptyState(
          icon: Icons.mark_email_unread_outlined,
          title: 'Start with an account',
          detail: 'Your mail stays in the local GlassMail database.',
          action: FilledButton.icon(
            onPressed: onCompose,
            icon: const Icon(Icons.add),
            label: const Text('Add Gmail account'),
          ),
        ),
      );
    }
    final snoozed = category == 'SNOOZED';
    final trash = category == 'TRASH';
    final Stream<List<MailListItem>> inboxStream;
    if (snoozed) {
      inboxStream = unified
          ? _combineMailStreams(
              accounts.map((item) => repository.observeInbox(item.accountId)),
            )
          : repository.observeInbox(account!.accountId);
    } else if (trash) {
      final trashRepository = repository;
      inboxStream = trashRepository is TrashMailboxRepository
          ? unified
                ? _combineMailStreams(
                    accounts.map(
                      (item) => (trashRepository as TrashMailboxRepository)
                          .observeTrash(item.accountId),
                    ),
                  )
                : (trashRepository as TrashMailboxRepository).observeTrash(
                    account!.accountId,
                  )
          : Stream.value(const <MailListItem>[]);
    } else if (unified) {
      inboxStream = repository.observeUnifiedInbox(
        accounts.map((item) => item.accountId).toList(growable: false),
        category,
      );
    } else {
      inboxStream = repository.observeInboxCategory(
        account!.accountId,
        category,
      );
    }
    return AnimatedBuilder(
      animation: workflowStore,
      builder: (context, _) => StreamBuilder<List<MailListItem>>(
        stream: inboxStream,
        builder: (context, snapshot) {
          final source = snapshot.data ?? const <MailListItem>[];
          final visible = source
              .where((item) {
                // Trash is a mailbox view. Local workflow filters must not
                // make already-deleted messages disappear from it.
                if (trash) return true;
                if (workflowStore.isSenderMuted(item.sender)) return false;
                return snoozed
                    ? workflowStore.isSnoozed(item.messageId)
                    : !workflowStore.isSnoozed(item.messageId);
              })
              .toList(growable: false);
          final unreadCount = visible.where((item) => item.unread).length;
          final attachmentCount = visible
              .where((item) => item.hasAttachment)
              .length;
          return _RouteScaffold(
            title: 'Inbox',
            subtitle: unified
                ? 'All accounts · ${_categoryLabel(category)}'
                : '${account!.email} · ${_categoryLabel(category)}',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Filter categories',
                  initialValue: category,
                  onSelected: onCategoryChanged,
                  itemBuilder: (_) => [
                    for (final item in [
                      ...MailCategory.all,
                      'SNOOZED',
                      'TRASH',
                    ])
                      PopupMenuItem(
                        value: item,
                        child: Text(
                          item == category
                              ? '✓ ${_categoryLabel(item)}'
                              : _categoryLabel(item),
                        ),
                      ),
                  ],
                  icon: const Icon(Icons.filter_list_rounded),
                ),
                IconButton(
                  tooltip: 'Search mail',
                  onPressed: onSearch,
                  icon: const Icon(Icons.search_rounded),
                ),
                IconButton(
                  tooltip: 'Compose message',
                  onPressed: onCompose,
                  icon: const Icon(Icons.edit_outlined),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Accounts and more options',
                  onSelected: (value) {
                    if (value == 'all-accounts') onSetUnified(true);
                    if (value.startsWith('account:')) {
                      onSelectAccount(value.substring('account:'.length));
                    }
                    if (value == 'sync') {
                      for (final item in unified ? accounts : [account!]) {
                        repository.synchronize(item.accountId);
                      }
                    }
                    if (value == 'lab') onGlassLab();
                    if (value == 'commands') {
                      _showCommandPalette(
                        context,
                        onSearch: onSearch,
                        onCompose: onCompose,
                        onSettings: onSettings,
                        onGlassLab: onGlassLab,
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    if (accounts.length > 1) ...[
                      PopupMenuItem(
                        value: 'all-accounts',
                        child: Text(
                          unified ? '✓ All accounts' : 'All accounts',
                        ),
                      ),
                      for (final item in accounts)
                        PopupMenuItem(
                          value: 'account:${item.accountId}',
                          child: Text(
                            !unified && item.accountId == account!.accountId
                                ? '✓ ${item.email}'
                                : item.email,
                          ),
                        ),
                      const PopupMenuDivider(),
                    ],
                    const PopupMenuItem(value: 'sync', child: Text('Sync now')),
                    const PopupMenuItem(
                      value: 'commands',
                      child: Text('Command palette…'),
                    ),
                    const PopupMenuItem(value: 'lab', child: Text('Glass Lab')),
                  ],
                ),
              ],
            ),
            child: snapshot.hasError
                ? Center(child: Text('Inbox unavailable: ${snapshot.error}'))
                : snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                ? _EmptyState(
                    icon: snoozed
                        ? Icons.snooze_rounded
                        : trash
                        ? Icons.delete_outline_rounded
                        : Icons.inbox_outlined,
                    title: snoozed
                        ? 'Nothing snoozed right now'
                        : trash
                        ? 'Gmail Trash is empty'
                        : 'Your inbox is empty',
                    detail: snoozed
                        ? 'Snoozed mail returns here when its reminder time arrives.'
                        : trash
                        ? 'Trash updates when this account syncs.'
                        : 'Pull to sync or use the menu to sync now.',
                    action: OutlinedButton.icon(
                      onPressed: () {
                        for (final item in unified ? accounts : [account!]) {
                          repository.synchronize(item.accountId);
                        }
                      },
                      icon: const Icon(Icons.sync),
                      label: const Text('Sync now'),
                    ),
                  )
                : ListView.builder(
                    key: const PageStorageKey('live-inbox-list'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: visible.length + (!snoozed && !trash ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (!snoozed && !trash && index == 0) {
                        return _SmartMailCard(
                          unreadCount: unreadCount,
                          attachmentCount: attachmentCount,
                        );
                      }
                      final item =
                          visible[index - (!snoozed && !trash ? 1 : 0)];
                      final owner = _ownerOf(item, accounts) ?? account;
                      return ListTile(
                        minVerticalPadding: 12,
                        onTap: () async {
                          if (trash) {
                            final trashRepository = repository;
                            if (trashRepository is! TrashMailboxRepository ||
                                owner == null) {
                              return;
                            }
                            final mailboxId =
                                await (trashRepository
                                        as TrashMailboxRepository)
                                    .trashMailboxId(owner.accountId);
                            if (mailboxId == null) return;
                            onOpen(item, owner, mailboxId: mailboxId);
                          } else {
                            onOpen(item, owner);
                          }
                        },
                        leading: CircleAvatar(
                          backgroundColor: item.unread
                              ? color.primaryContainer
                              : color.surfaceContainerHighest,
                          child: Text(_initial(item.sender)),
                        ),
                        title: Text(
                          workflowStore.senderProfile(item.sender) ??
                              item.sender,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: item.unread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.subject,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              item.preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          tooltip: item.starred
                              ? 'Unstar message'
                              : 'Star message',
                          onPressed: owner == null
                              ? null
                              : () async {
                                  final String? mailboxId;
                                  if (trash) {
                                    final trashRepository = repository;
                                    if (trashRepository
                                        is! TrashMailboxRepository) {
                                      return;
                                    }
                                    mailboxId =
                                        await (trashRepository
                                                as TrashMailboxRepository)
                                            .trashMailboxId(owner.accountId);
                                  } else {
                                    mailboxId = '${owner.accountId}:INBOX';
                                  }
                                  if (mailboxId == null) return;
                                  await repository.applyMutation(
                                    StarMutation(
                                      accountId: owner.accountId,
                                      messageId: item.messageId,
                                      mailboxId: mailboxId,
                                      starred: !item.starred,
                                    ),
                                  );
                                },
                          icon: Icon(
                            item.starred
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _SmartMailCard extends StatelessWidget {
  const _SmartMailCard({
    required this.unreadCount,
    required this.attachmentCount,
  });

  final int unreadCount;
  final int attachmentCount;

  @override
  Widget build(BuildContext context) {
    if (unreadCount == 0 && attachmentCount == 0) {
      return const SizedBox.shrink();
    }
    final notes = <String>[
      if (unreadCount > 0) '$unreadCount unread',
      if (attachmentCount > 0) '$attachmentCount with attachments',
    ];
    return Card(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: ListTile(
        leading: const Icon(Icons.auto_awesome_outlined),
        title: const Text('Inbox overview'),
        subtitle: Text(notes.join(' · ')),
      ),
    );
  }
}

class _SearchRoute extends StatefulWidget {
  const _SearchRoute({
    super.key,
    required this.repository,
    required this.account,
    required this.accounts,
    required this.unified,
    this.initialQuery = '',
    required this.onOpen,
  });

  final MailRepository repository;
  final MailAccount? account;
  final List<MailAccount> accounts;
  final bool unified;
  final String initialQuery;
  final void Function(MailListItem, MailAccount?) onOpen;

  @override
  State<_SearchRoute> createState() => _SearchRouteState();
}

class _SearchRouteState extends State<_SearchRoute> {
  final _controller = TextEditingController();
  Stream<List<MailListItem>>? _results;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    _controller.addListener(_search);
    if (_controller.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search();
      });
    }
  }

  void _search() {
    final account = widget.account;
    if (account == null || widget.accounts.isEmpty) return;
    setState(
      () => _results = widget.unified
          ? widget.repository.searchUnified(
              widget.accounts.map((item) => item.accountId).toList(),
              _controller.text,
            )
          : widget.repository.search(account.accountId, _controller.text),
    );
  }

  @override
  void didUpdateWidget(covariant _SearchRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account?.accountId != widget.account?.accountId ||
        oldWidget.initialQuery != widget.initialQuery ||
        oldWidget.unified != widget.unified ||
        oldWidget.accounts.map((account) => account.accountId).join(',') !=
            widget.accounts.map((account) => account.accountId).join(',')) {
      _search();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_search);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _RouteScaffold(
    title: 'Search',
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search messages',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        Expanded(
          child: widget.account == null
              ? const _EmptyState(
                  icon: Icons.search,
                  title: 'Add an account to search',
                  detail: 'Search uses the local full-text index.',
                )
              : _results == null
              ? const Center(child: Text('Search your mail'))
              : StreamBuilder<List<MailListItem>>(
                  stream: _results,
                  builder: (context, snapshot) {
                    final results = snapshot.data ?? const <MailListItem>[];
                    if (_controller.text.trim().isEmpty) {
                      return const Center(child: Text('Search your mail'));
                    }
                    if (results.isEmpty) {
                      return const Center(child: Text('No matching messages'));
                    }
                    return ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (_, index) {
                        final item = results[index];
                        return ListTile(
                          title: Text(item.subject),
                          subtitle: Text(
                            '${item.sender} · ${item.preview}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => widget.onOpen(
                            item,
                            _ownerOf(item, widget.accounts) ?? widget.account,
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class _ReaderRoute extends StatefulWidget {
  const _ReaderRoute({
    required this.repository,
    required this.account,
    required this.messageId,
    required this.mailboxId,
    required this.workflowStore,
    required this.onReply,
    required this.onReplyAll,
    required this.onForward,
  });

  final MailRepository repository;
  final MailAccount account;
  final String messageId;
  final String mailboxId;
  final MailWorkflowStore workflowStore;
  final ValueChanged<MailMessage> onReply;
  final ValueChanged<MailMessage> onReplyAll;
  final ValueChanged<MailMessage> onForward;

  @override
  State<_ReaderRoute> createState() => _ReaderRouteState();
}

class _ReaderRouteState extends State<_ReaderRoute> {
  bool _loading = false;
  Uri? _previewingLink;
  final Set<String> _readMarked = {};
  final Set<String> _sharingAttachments = {};

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadBody(String messageId) async {
    setState(() => _loading = true);
    await widget.repository.loadMessageBody(messageId);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _shareAttachment(MailAttachment attachment) async {
    final repository = widget.repository as AttachmentRepository?;
    if (repository == null ||
        !_sharingAttachments.add(attachment.attachmentId)) {
      return;
    }
    setState(() {});
    final result = await repository.downloadAttachment(
      widget.account.accountId,
      attachment.attachmentId,
    );
    if (!mounted) return;
    setState(() => _sharingAttachments.remove(attachment.attachmentId));
    if (result is MailOperationSuccess<DownloadedAttachment>) {
      final file = result.value;
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile(
                file.filePath,
                name: file.fileName,
                mimeType: file.mimeType,
              ),
            ],
          ),
        );
      } on Object {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The attachment could not be shared.'),
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not download ${attachment.fileName ?? 'attachment'}.',
          ),
        ),
      );
    }
  }

  Future<void> _applyThreadAction(
    List<MailMessage> messages,
    String action,
  ) async {
    final mailboxId = widget.mailboxId;
    final targets = messages.toList(growable: false);
    for (final message in targets) {
      switch (action) {
        case 'archive':
          await widget.repository.applyMutation(
            ArchiveMutation(
              accountId: widget.account.accountId,
              messageId: message.messageId,
              mailboxId: mailboxId,
            ),
          );
        case 'delete':
          await widget.repository.applyMutation(
            DeleteMutation(
              accountId: widget.account.accountId,
              messageId: message.messageId,
              mailboxId: mailboxId,
            ),
          );
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    if (action == 'archive' && targets.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Conversation archived'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              for (final message in targets) {
                widget.repository.undoPendingArchive(message.messageId);
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _purgeThreadFromTrash(List<MailMessage> messages) async {
    final repository = widget.repository;
    if (repository is! PermanentMailDeletionRepository) return;
    final purgeRepository = repository as PermanentMailDeletionRepository;
    final permanentlyDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently delete conversation?'),
        content: Text(
          'This permanently deletes ${messages.length} message${messages.length == 1 ? '' : 's'} from Gmail Trash. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Permanently delete'),
          ),
        ],
      ),
    );
    if (permanentlyDelete != true) return;
    try {
      for (final message in messages) {
        await purgeRepository.purgeFromTrash(
          accountId: widget.account.accountId,
          messageId: message.messageId,
          mailboxId: widget.mailboxId,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation permanently deleted.')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not permanently delete: $error')),
      );
    }
  }

  Future<void> _setReminder(
    MailMessage message,
    String kind,
    Duration delay,
  ) async {
    await widget.workflowStore.setReminder(
      WorkflowReminder(
        messageId: message.messageId,
        kind: kind,
        atEpochMillis: DateTime.now().add(delay).millisecondsSinceEpoch,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          kind == 'snooze' ? 'Message snoozed.' : 'Follow-up reminder saved.',
        ),
      ),
    );
  }

  Future<void> _editSenderProfile(String sender) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _TextEntryDialog(
        title: 'Sender profile',
        label: 'Display name',
        initialValue: widget.workflowStore.senderProfile(sender) ?? '',
        onPickContact: _pickSenderContactName,
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await widget.workflowStore.saveSenderProfile(sender, name);
  }

  Future<String?> _pickSenderContactName() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await FlutterContacts.permissions.request(
        PermissionType.read,
      );
      if (status != PermissionStatus.granted &&
          status != PermissionStatus.limited) {
        return null;
      }
    }
    final contact = await FlutterContacts.native.showPicker(
      properties: {ContactProperty.name, ContactProperty.email},
    );
    final name = contact?.displayName?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  Future<void> _confirmAndOpenLink(Uri uri) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open external link?'),
        content: Text(
          '${uri.host}\n${uri.toString()}\n\nGlassMail will open this address in your browser. The destination may receive your visit and IP address.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open browser'),
          ),
        ],
      ),
    );
    if (open != true || !mounted) return;
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No browser could open this link.')),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this link.')),
        );
      }
    }
  }

  Future<void> _confirmAndPreviewLink(Uri uri) async {
    if (_previewingLink != null) return;
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fetch link preview?'),
        content: Text(
          '${uri.host}\n${uri.toString()}\n\nGlassMail will request this HTTPS link directly from your device. The site can see your IP address and that this exact link was requested. GlassMail sends no cookies or referrer, follows no redirects, and loads no images or other page resources. Previewing private sign-in or password-reset links can expose their one-time token.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fetch preview'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) return;
    setState(() => _previewingLink = uri);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 8),
        content: Row(
          children: [
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Fetching limited page metadata…')),
          ],
        ),
      ),
    );
    try {
      final preview = await MailLinkPreviewService().fetch(uri);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      final openInBrowser = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(preview.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(preview.siteName),
              if (preview.description case final description?) ...[
                const SizedBox(height: 12),
                Text(description),
              ],
              const SizedBox(height: 12),
              SelectableText(preview.uri.toString()),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Done'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open in browser'),
            ),
          ],
        ),
      );
      if (openInBrowser == true && mounted) {
        await _confirmAndOpenLink(uri);
      }
    } on LinkPreviewException catch (error) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not preview this link: ${error.message}'),
        ),
      );
    } on Object {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not preview this link.')),
      );
    } finally {
      if (mounted) setState(() => _previewingLink = null);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<MailMessage>>(
    stream: widget.repository.observeThreadInMailbox(
      widget.messageId,
      widget.mailboxId,
    ),
    builder: (context, snapshot) {
      final messages = snapshot.data ?? const <MailMessage>[];
      if (messages.isEmpty) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      for (final message in messages) {
        if (message.unread && _readMarked.add(message.messageId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.repository.applyMutation(
              MarkReadMutation(
                accountId: widget.account.accountId,
                messageId: message.messageId,
                mailboxId: widget.mailboxId,
                read: true,
              ),
            );
          });
        }
      }
      final replyTarget = messages.last;
      return _RouteScaffold(
        title: 'Message',
        canPop: true,
        trailing: PopupMenuButton<String>(
          tooltip: 'Message actions',
          onSelected: (action) {
            switch (action) {
              case 'reply':
                widget.onReply(replyTarget);
              case 'reply_all':
                widget.onReplyAll(replyTarget);
              case 'forward':
                widget.onForward(replyTarget);
              case 'archive':
              case 'delete':
                _applyThreadAction(messages, action);
              case 'purge':
                _purgeThreadFromTrash(messages);
              case 'snooze_1d':
                _setReminder(replyTarget, 'snooze', const Duration(days: 1));
              case 'snooze_1w':
                _setReminder(replyTarget, 'snooze', const Duration(days: 7));
              case 'followup_1d':
                _setReminder(replyTarget, 'followup', const Duration(days: 1));
              case 'followup_1w':
                _setReminder(replyTarget, 'followup', const Duration(days: 7));
              case 'unsnooze':
                unawaited(
                  widget.workflowStore.clearReminder(
                    replyTarget.messageId,
                    'snooze',
                  ),
                );
              case 'mute_sender':
                unawaited(
                  widget.workflowStore.setSenderMuted(replyTarget.sender, true),
                );
              case 'profile_sender':
                _editSenderProfile(replyTarget.sender);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'reply', child: Text('Reply')),
            const PopupMenuItem(value: 'reply_all', child: Text('Reply all')),
            const PopupMenuItem(value: 'forward', child: Text('Forward')),
            const PopupMenuDivider(),
            if (widget.workflowStore.isSnoozed(widget.messageId))
              const PopupMenuItem(value: 'unsnooze', child: Text('Unsnooze'))
            else ...[
              const PopupMenuItem(
                value: 'snooze_1d',
                child: Text('Snooze 1 day'),
              ),
              const PopupMenuItem(
                value: 'snooze_1w',
                child: Text('Snooze 1 week'),
              ),
            ],
            const PopupMenuItem(
              value: 'followup_1d',
              child: Text('Follow up tomorrow'),
            ),
            const PopupMenuItem(
              value: 'followup_1w',
              child: Text('Follow up in a week'),
            ),
            const PopupMenuItem(
              value: 'profile_sender',
              child: Text('Edit sender profile'),
            ),
            const PopupMenuItem(
              value: 'mute_sender',
              child: Text('Hide sender in inbox'),
            ),
            if (widget.mailboxId.endsWith(':INBOX')) ...[
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'archive',
                child: Text('Archive conversation'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Move to trash'),
              ),
            ] else ...[
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Move to trash'),
              ),
              if (_looksLikeTrashMailboxId(widget.mailboxId) &&
                  widget.repository is PermanentMailDeletionRepository)
                const PopupMenuItem(
                  value: 'purge',
                  child: Text('Permanently delete'),
                ),
            ],
          ],
          icon: const Icon(Icons.more_vert_rounded),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: messages.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final message = messages[index];
            final isFirst = index == 0;
            final isLast = index == messages.length - 1;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isFirst)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    child: Text(
                      message.subject,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                _MessageCard(
                  message: message,
                  initiallyExpanded: isLast || message.unread,
                  workflowStore: widget.workflowStore,
                  repository: widget.repository,
                  account: widget.account,
                  sharingAttachments: _sharingAttachments,
                  onShareAttachment: _shareAttachment,
                  onLoadBody: _loading
                      ? null
                      : () => _loadBody(message.messageId),
                  loading: _loading,
                  onOpenLink: _confirmAndOpenLink,
                  onPreviewLink: _confirmAndPreviewLink,
                  previewingLink: _previewingLink,
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

class _MessageCard extends StatefulWidget {
  const _MessageCard({
    required this.message,
    required this.initiallyExpanded,
    required this.workflowStore,
    required this.repository,
    required this.account,
    required this.sharingAttachments,
    required this.onShareAttachment,
    required this.onLoadBody,
    required this.loading,
    required this.onOpenLink,
    required this.onPreviewLink,
    this.previewingLink,
  });

  final MailMessage message;
  final bool initiallyExpanded;
  final MailWorkflowStore workflowStore;
  final MailRepository repository;
  final MailAccount account;
  final Set<String> sharingAttachments;
  final ValueChanged<MailAttachment> onShareAttachment;
  final VoidCallback? onLoadBody;
  final bool loading;
  final ValueChanged<Uri> onOpenLink;
  final ValueChanged<Uri> onPreviewLink;
  final Uri? previewingLink;

  @override
  State<_MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<_MessageCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final senderProfile =
        widget.workflowStore.senderProfile(widget.message.sender) ??
        widget.message.sender;
    final snippet = widget.message.preview
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: widget.initiallyExpanded,
          onExpansionChanged: (expanded) =>
              setState(() => _expanded = expanded),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  senderProfile,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: widget.message.unread
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDate(widget.message.sentAtEpochMillis),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          subtitle: _expanded
              ? null
              : Text(snippet, maxLines: 1, overflow: TextOverflow.ellipsis),
          children: [
            if (widget.message.html)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: _SafetyNote(
                  'HTML is shown as inert text. Images and remote page resources stay blocked. Link previews require a separate confirmation and contact only the public HTTPS destination.',
                ),
              ),
            _SafeMessageBody(
              text: widget.message.html
                  ? mailHtmlToPlainText(
                      widget.message.body ?? widget.message.preview,
                    )
                  : widget.message.body ?? widget.message.preview,
              onOpen: widget.onOpenLink,
              onPreview: widget.onPreviewLink,
              previewingLink: widget.previewingLink,
            ),
            if (widget.message.attachments.isNotEmpty) ...[
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Attachments',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final attachment in widget.message.attachments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_file_rounded),
                  title: Text(attachment.fileName ?? 'Attachment'),
                  subtitle: Text(_attachmentDetails(attachment)),
                  trailing: IconButton(
                    tooltip:
                        widget.sharingAttachments.contains(
                          attachment.attachmentId,
                        )
                        ? 'Preparing attachment'
                        : 'Download and share ${attachment.fileName ?? 'attachment'}',
                    onPressed:
                        widget.sharingAttachments.contains(
                          attachment.attachmentId,
                        )
                        ? null
                        : () => widget.onShareAttachment(attachment),
                    icon:
                        widget.sharingAttachments.contains(
                          attachment.attachmentId,
                        )
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share_outlined),
                  ),
                ),
            ],
            if (widget.message.body == null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: FilledButton.icon(
                  onPressed: widget.onLoadBody,
                  icon: widget.loading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                  label: const Text('Load full message'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComposeRoute extends StatefulWidget {
  const _ComposeRoute({
    required this.repository,
    required this.account,
    required this.workflowStore,
    this.delayedSendCoordinator,
    this.reply,
    this.draft,
  });

  final MailRepository repository;
  final MailAccount account;
  final MailWorkflowStore workflowStore;
  final DelayedSendCoordinator? delayedSendCoordinator;
  final MailMessage? reply;
  final MailDraft? draft;

  @override
  State<_ComposeRoute> createState() => _ComposeRouteState();
}

class _ComposeRouteState extends State<_ComposeRoute> {
  late final _to = TextEditingController(
    text:
        widget.draft?.to.join(', ') ??
        (widget.reply == null ? '' : _address(widget.reply!.sender)),
  );
  late final _cc = TextEditingController(
    text: widget.draft?.cc.join(', ') ?? '',
  );
  late final _bcc = TextEditingController(
    text: widget.draft?.bcc.join(', ') ?? '',
  );
  late final _subject = TextEditingController(
    text:
        widget.draft?.subject ??
        (widget.reply == null ? '' : 'Re: ${widget.reply!.subject}'),
  );
  late final _body = TextEditingController(text: widget.draft?.body ?? '');
  bool _showCcBcc = false;
  Timer? _saveDebounce;
  late final _operationId =
      widget.draft?.draftId ?? 'draft-${DateTime.now().microsecondsSinceEpoch}';
  bool _sending = false;
  bool _addingAttachments = false;
  bool _sentSuccessfully = false;
  bool _queuedSuccessfully = false;
  final List<DraftAttachment> _attachments = [];

  static const _maxAttachmentBytes = 18 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _attachments.addAll(widget.draft?.attachments ?? const []);
    if ((widget.draft?.cc.isNotEmpty ?? false) ||
        (widget.draft?.bcc.isNotEmpty ?? false)) {
      _showCcBcc = true;
    }
  }

  Future<void> _addAttachments() async {
    if (_addingAttachments) return;
    setState(() => _addingAttachments = true);
    try {
      final selected = await openFiles();
      if (selected.isEmpty || !mounted) return;
      final root = await getApplicationSupportDirectory();
      final accountKey = base64Url
          .encode(utf8.encode(widget.account.accountId))
          .replaceAll('=', '');
      final targetDirectory = Directory(
        '${root.path}/attachments/$accountKey/outgoing',
      );
      await targetDirectory.create(recursive: true);
      var totalBytes = _attachments.fold<int>(
        0,
        (sum, attachment) => sum + attachment.sizeBytes,
      );
      var rejected = false;
      for (final source in selected) {
        final size = await source.length();
        if (totalBytes + size > _maxAttachmentBytes) {
          rejected = true;
          continue;
        }
        final name = sanitizeAttachmentName(source.name);
        final target = File(
          '${targetDirectory.path}/${_operationId}_${DateTime.now().microsecondsSinceEpoch}_${_attachments.length}_$name',
        );
        try {
          final sink = target.openWrite();
          try {
            await sink.addStream(source.openRead());
          } finally {
            await sink.close();
          }
          if (!mounted) {
            await target.delete();
            return;
          }
          final attachment = DraftAttachment(
            uri: target.uri.toString(),
            fileName: name,
            mimeType: source.mimeType ?? 'application/octet-stream',
            sizeBytes: size,
          );
          setState(() => _attachments.add(attachment));
          totalBytes += size;
        } on Object {
          if (await target.exists()) await target.delete();
          rethrow;
        }
      }
      _scheduleSave();
      if (rejected && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attachments are limited to 18 MiB total.'),
          ),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not add the selected attachment.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _addingAttachments = false);
    }
  }

  Future<void> _removeAttachment(DraftAttachment attachment) async {
    setState(() => _attachments.remove(attachment));
    _scheduleSave();
    try {
      final file = _localAttachmentFile(attachment.uri);
      if (await file.exists()) await file.delete();
    } on Object {
      // The draft update is still applied if local cache cleanup fails.
    }
  }

  Future<void> _saveDraft() async {
    final drafts = widget.repository as DraftRepository?;
    if (drafts == null) return;
    try {
      await drafts.saveDraft(
        MailDraft(
          draftId: _operationId,
          accountId: widget.account.accountId,
          to: _parseAddresses(_to.text),
          cc: _parseAddresses(_cc.text),
          bcc: _parseAddresses(_bcc.text),
          subject: _subject.text,
          body: _body.text,
          inReplyTo: widget.reply?.messageId ?? widget.draft?.inReplyTo,
          attachments: List.unmodifiable(_attachments),
          references: widget.reply == null
              ? widget.draft?.references ?? const []
              : referencesForReply(widget.reply!.messageId, const []),
        ),
      );
    } on Object {
      // Keep the editor usable if local persistence reports an error.
    }
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _saveDraft);
  }

  Future<void> _send() async {
    final sender = widget.repository as MailSender?;
    final recipients = _parseAddresses(_to.text);
    final cc = _parseAddresses(_cc.text);
    final bcc = _parseAddresses(_bcc.text);
    if (!validateAddresses(recipients) ||
        !validateAddresses(cc) ||
        !validateAddresses(bcc)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid recipient addresses.')),
      );
      return;
    }
    if (sender == null) return;
    setState(() => _sending = true);
    final result = await sender.send(
      widget.account,
      _outgoingMail(recipients, cc, bcc),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    final text = switch (result) {
      MailSent() => 'Message sent.',
      MailSendFailed(error: SendMailError.uncertain) =>
        'Delivery is uncertain. Check Sent before trying again.',
      MailSendFailed() => 'Message could not be sent.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    if (result is MailSent) {
      _sentSuccessfully = true;
      Navigator.of(context).pop();
    }
  }

  OutgoingMail _outgoingMail(
    List<String> recipients,
    List<String> cc,
    List<String> bcc,
  ) => OutgoingMail(
    operationId: _operationId,
    accountId: widget.account.accountId,
    from: widget.account.email,
    to: recipients,
    cc: cc,
    bcc: bcc,
    subject: _subject.text,
    body: _body.text,
    inReplyTo: widget.reply?.messageId ?? widget.draft?.inReplyTo,
    references: widget.reply == null
        ? widget.draft?.references ?? const []
        : [widget.reply!.messageId],
    attachments: [
      for (final attachment in _attachments)
        OutgoingAttachment(
          uri: attachment.uri,
          fileName: attachment.fileName,
          mimeType: attachment.mimeType,
          sizeBytes: attachment.sizeBytes,
          openStream: () => _localAttachmentFile(attachment.uri).openRead(),
        ),
    ],
  );

  Future<void> _scheduleSend() async {
    final coordinator = widget.delayedSendCoordinator;
    if (coordinator == null) return;
    final recipients = _parseAddresses(_to.text);
    final cc = _parseAddresses(_cc.text);
    final bcc = _parseAddresses(_bcc.text);
    if (!validateAddresses(recipients) ||
        !validateAddresses(cc) ||
        !validateAddresses(bcc)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid recipient addresses.')),
      );
      return;
    }
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    final scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final delay = scheduled.difference(DateTime.now());
    if (delay <= Duration.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a time in the future.')),
      );
      return;
    }
    setState(() => _sending = true);
    _saveDebounce?.cancel();
    try {
      await widget.workflowStore.saveScheduledSend(
        ScheduledMailSend(
          draftId: _operationId,
          accountId: widget.account.accountId,
          atEpochMillis: scheduled.millisecondsSinceEpoch,
        ),
      );
      await coordinator.queue(
        widget.account,
        _outgoingMail(recipients, cc, bcc),
        undoWindow: delay,
      );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _queuedSuccessfully = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Platform.isIOS
                ? 'Scheduled while GlassMail is open. If the app is closed, this will return to Drafts.'
                : 'Scheduled for ${MaterialLocalizations.of(context).formatTimeOfDay(time)} when a network is available.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on Object catch (error) {
      await widget.workflowStore.removeScheduledSend(_operationId);
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not schedule message: $error')),
      );
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    if (!_sentSuccessfully &&
        !_queuedSuccessfully &&
        (_attachments.isNotEmpty ||
            _to.text.isNotEmpty ||
            _subject.text.isNotEmpty ||
            _body.text.isNotEmpty)) {
      unawaited(_saveDraft());
    }
    _to.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _RouteScaffold(
    title: 'Compose',
    canPop: true,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.delayedSendCoordinator != null)
          IconButton(
            tooltip: 'Schedule send',
            onPressed: _sending ? null : _scheduleSend,
            icon: const Icon(Icons.schedule_send_outlined),
          ),
        IconButton(
          tooltip: _sending ? 'Sending' : 'Send',
          onPressed: _sending ? null : _send,
          icon: const Icon(Icons.send_rounded),
        ),
      ],
    ),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        Text(
          'From  ${widget.account.email}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (widget.workflowStore.templates.isNotEmpty)
          AnimatedBuilder(
            animation: widget.workflowStore,
            builder: (context, _) => PopupMenuButton<String>(
              tooltip: 'Insert a saved template',
              onSelected: (id) {
                final template = widget.workflowStore.templates
                    .where((item) => item.id == id)
                    .firstOrNull;
                if (template == null) return;
                _subject.text = template.subject;
                _body.text = template.body;
                _scheduleSave();
              },
              itemBuilder: (_) => [
                for (final template in widget.workflowStore.templates)
                  PopupMenuItem(value: template.id, child: Text(template.name)),
              ],
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.description_outlined),
                title: Text('Insert template'),
                trailing: Icon(Icons.expand_more),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: TextField(
                controller: _to,
                onChanged: (_) => _scheduleSave(),
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'To'),
              ),
            ),
            if (!_showCcBcc)
              TextButton(
                onPressed: () => setState(() => _showCcBcc = true),
                child: const Text('Cc/Bcc'),
              ),
          ],
        ),
        if (_showCcBcc) ...[
          TextField(
            controller: _cc,
            onChanged: (_) => _scheduleSave(),
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Cc'),
          ),
          TextField(
            controller: _bcc,
            onChanged: (_) => _scheduleSave(),
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Bcc'),
          ),
        ],
        TextField(
          controller: _subject,
          onChanged: (_) => _scheduleSave(),
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Subject'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _addingAttachments ? null : _addAttachments,
            icon: _addingAttachments
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.attach_file_rounded),
            label: Text(_addingAttachments ? 'Adding…' : 'Add attachment'),
          ),
        ),
        if (_attachments.isNotEmpty) ...[
          Text(
            '${_attachments.length} attachment${_attachments.length == 1 ? '' : 's'} · up to 18 MiB total',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          for (final attachment in _attachments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.attach_file_rounded),
              title: Text(attachment.fileName),
              subtitle: Text(_formatBytes(attachment.sizeBytes)),
              trailing: IconButton(
                tooltip: 'Remove ${attachment.fileName}',
                onPressed: () => _removeAttachment(attachment),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _body,
          onChanged: (_) => _scheduleSave(),
          minLines: 10,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Write your message',
            border: InputBorder.none,
          ),
        ),
      ],
    ),
  );
}

class _SentRoute extends StatelessWidget {
  const _SentRoute({
    required this.repository,
    required this.account,
    required this.onOpen,
  });
  final MailRepository repository;
  final MailAccount? account;
  final ValueChanged<MailListItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final drafts = repository as DraftRepository?;
    if (account == null || drafts == null) {
      return _RouteScaffold(
        title: 'Sent',
        child: const _EmptyState(
          icon: Icons.send_outlined,
          title: 'Add an account first',
          detail: 'Connect Gmail before sending messages.',
        ),
      );
    }
    return StreamBuilder<List<MailListItem>>(
      stream: repository.observeSent(account!.accountId),
      builder: (context, remoteSnapshot) => StreamBuilder<List<MailDraft>>(
        stream: drafts.observeDrafts(account!.accountId),
        builder: (context, draftSnapshot) {
          final remote = remoteSnapshot.data ?? const <MailListItem>[];
          final sentDrafts = (draftSnapshot.data ?? const <MailDraft>[])
              .where((draft) => draft.status == DraftStatus.sent)
              .toList(growable: false);
          return _RouteScaffold(
            title: 'Sent',
            subtitle: account!.email,
            trailing: IconButton(
              tooltip: 'Sync Sent mail',
              onPressed: () => repository.synchronize(account!.accountId),
              icon: const Icon(Icons.sync_rounded),
            ),
            child: remote.isEmpty && sentDrafts.isEmpty
                ? _EmptyState(
                    icon: Icons.send_outlined,
                    title: 'No sent messages cached',
                    detail: 'Sync to check the server Sent folder. Messages sent on this device will appear here too.',
                    action: OutlinedButton.icon(
                      onPressed: () =>
                          repository.synchronize(account!.accountId),
                      icon: const Icon(Icons.sync_rounded),
                      label: const Text('Sync now'),
                    ),
                  )
                : ListView.builder(
                    itemCount: remote.length + sentDrafts.length,
                    itemBuilder: (context, index) {
                      if (index < remote.length) {
                        final item = remote[index];
                        return ListTile(
                          title: Text(
                            item.subject.isEmpty
                                ? '(no subject)'
                                : item.subject,
                          ),
                          subtitle: Text(
                            '${account!.email}\n${_formatDate(item.sentAtEpochMillis)}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => onOpen(item),
                        );
                      }
                      final draft = sentDrafts[index - remote.length];
                      return ListTile(
                        title: Text(
                          draft.subject.isEmpty
                              ? '(no subject)'
                              : draft.subject,
                        ),
                        subtitle: Text(
                          'To ${draft.to.join(', ')}\n${draft.body}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _DraftsRoute extends StatelessWidget {
  const _DraftsRoute({
    required this.repository,
    required this.account,
    required this.onOpen,
  });

  final MailRepository repository;
  final MailAccount account;
  final ValueChanged<MailDraft> onOpen;

  @override
  Widget build(BuildContext context) {
    final drafts = repository as DraftRepository?;
    if (drafts == null) {
      return const _RouteScaffold(
        title: 'Drafts',
        canPop: true,
        child: _EmptyState(
          icon: Icons.drafts_outlined,
          title: 'Drafts unavailable',
          detail: 'Draft storage is not connected.',
        ),
      );
    }
    return StreamBuilder<List<MailDraft>>(
      stream: drafts.observeDrafts(account.accountId),
      builder: (context, snapshot) {
        final saved = (snapshot.data ?? const <MailDraft>[])
            .where((draft) => draft.status != DraftStatus.sent)
            .toList(growable: false);
        return _RouteScaffold(
          title: 'Drafts',
          subtitle: account.email,
          canPop: true,
          child: saved.isEmpty
              ? const _EmptyState(
                  icon: Icons.drafts_outlined,
                  title: 'No saved drafts',
                  detail: 'Unsent messages are saved on this device.',
                )
              : ListView.builder(
                  itemCount: saved.length,
                  itemBuilder: (context, index) {
                    final draft = saved[index];
                    final editable =
                        draft.status == DraftStatus.draft ||
                        draft.status == DraftStatus.failed;
                    return ListTile(
                      leading: Icon(
                        draft.status == DraftStatus.uncertain
                            ? Icons.warning_amber_rounded
                            : Icons.drafts_outlined,
                      ),
                      title: Text(
                        draft.subject.isEmpty ? '(no subject)' : draft.subject,
                      ),
                      subtitle: Text(
                        draft.status == DraftStatus.uncertain
                            ? 'Delivery uncertain. Check Sent before sending again.'
                            : '${draft.to.join(', ')}\n${draft.body}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text('${draft.attachments.length} files'),
                      onTap: editable ? () => onOpen(draft) : null,
                    );
                  },
                ),
        );
      },
    );
  }
}

class _SettingsRoute extends StatelessWidget {
  const _SettingsRoute({
    required this.repository,
    required this.accounts,
    required this.preferences,
    required this.workflowStore,
    required this.delayedSendCoordinator,
    required this.onAddAccount,
    required this.onAccountChanged,
    required this.onOpenDrafts,
    required this.onGlassLab,
    required this.onOpenSavedView,
  });

  final MailRepository repository;
  final List<MailAccount> accounts;
  final MailUserPreferences preferences;
  final MailWorkflowStore workflowStore;
  final DelayedSendCoordinator? delayedSendCoordinator;
  final VoidCallback onAddAccount;
  final ValueChanged<MailAccount> onAccountChanged;
  final ValueChanged<MailAccount> onOpenDrafts;
  final VoidCallback onGlassLab;
  final ValueChanged<MailSavedView> onOpenSavedView;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: workflowStore,
    builder: (context, _) => _RouteScaffold(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
          DropdownButtonFormField<ThemeMode>(
            initialValue: preferences.themeMode,
            decoration: const InputDecoration(labelText: 'Color theme'),
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
              DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
            ],
            onChanged: (value) {
              if (value != null) preferences.update(themeMode: value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<GlassMailTier>(
            initialValue: preferences.glassTier,
            decoration: const InputDecoration(labelText: 'Glass quality'),
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                value: GlassMailTier.full,
                child: Text('Full (Premium)'),
              ),
              DropdownMenuItem(
                value: GlassMailTier.balanced,
                child: Text('Balanced (Standard)'),
              ),
              DropdownMenuItem(
                value: GlassMailTier.light,
                child: Text('Light (Minimal)'),
              ),
              DropdownMenuItem(
                value: GlassMailTier.off,
                child: Text('Off (Opaque)'),
              ),
            ],
            onChanged: (value) {
              if (value != null) preferences.update(glassTier: value);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reduce transparency'),
            subtitle: const Text('Use opaque surfaces for glass effects'),
            value: preferences.reduceTransparency,
            onChanged: (value) => preferences.update(reduceTransparency: value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reduce motion'),
            subtitle: const Text('Remove route and dock animation'),
            value: preferences.reduceMotion,
            onChanged: (value) => preferences.update(reduceMotion: value),
          ),
          const SizedBox(height: 20),
          Text('Accounts', style: Theme.of(context).textTheme.titleLarge),
          for (final account in accounts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.mail_outline)),
              title: Text(account.email),
              subtitle: Text(account.syncState),
              trailing: PopupMenuButton<String>(
                tooltip: 'Account options',
                onSelected: (value) async {
                  if (value == 'sync') {
                    await repository.synchronize(account.accountId);
                  } else if (value == 'password') {
                    await _updateAccountPassword(context, repository, account);
                  } else if (value == 'remove' && context.mounted) {
                    final remove = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Remove account?'),
                        content: Text(
                          'Remove ${account.email} and its local mail cache?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                    if (remove == true) {
                      await repository.removeAccount(account.accountId);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'sync', child: Text('Sync now')),
                  PopupMenuItem(
                    value: 'password',
                    child: Text('Update app password'),
                  ),
                  PopupMenuItem(value: 'remove', child: Text('Remove account')),
                ],
              ),
              onTap: () => onAccountChanged(account),
            ),
          OutlinedButton.icon(
            onPressed: onAddAccount,
            icon: const Icon(Icons.add),
            label: const Text('Add Gmail account'),
          ),
          if (accounts.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('Drafts', style: Theme.of(context).textTheme.titleLarge),
            for (final account in accounts)
              ListTile(
                leading: const Icon(Icons.drafts_outlined),
                title: const Text('Saved drafts'),
                subtitle: Text(account.email),
                onTap: () => onOpenDrafts(account),
              ),
            const SizedBox(height: 12),
            Text(
              'Data and storage',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            for (final account in accounts)
              _AccountCacheSettings(repository: repository, account: account),
          ],
          const SizedBox(height: 24),
          Text('Workflow tools', style: Theme.of(context).textTheme.titleLarge),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Create mail template'),
            subtitle: const Text('Reuse a subject and message body in Compose'),
            onTap: () => _createTemplate(context, workflowStore),
          ),
          for (final template in workflowStore.templates)
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: Text(template.name),
              subtitle: Text(
                template.subject.isEmpty ? 'No subject' : template.subject,
              ),
              trailing: IconButton(
                tooltip: 'Delete template ${template.name}',
                onPressed: () => workflowStore.removeTemplate(template.id),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.bookmark_add_outlined),
            title: const Text('Save a custom search view'),
            subtitle: const Text('Name a local full-text search query'),
            onTap: () => _createSavedView(context, workflowStore),
          ),
          for (final view in workflowStore.savedViews)
            ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: Text(view.name),
              subtitle: Text(view.query),
              onTap: () => onOpenSavedView(view),
              trailing: IconButton(
                tooltip: 'Delete view ${view.name}',
                onPressed: () => workflowStore.removeView(view.id),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.filter_alt_outlined),
            title: const Text('Add sender to local screener'),
            subtitle: const Text('Hide that sender in this app only'),
            onTap: () => _addScreenedSender(context, workflowStore),
          ),
          for (final sender in workflowStore.mutedSenders)
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text(sender),
              subtitle: const Text('Hidden locally; still delivered by Gmail'),
              trailing: IconButton(
                tooltip: 'Show $sender in inbox',
                onPressed: () => workflowStore.setSenderMuted(sender, false),
                icon: const Icon(Icons.undo_rounded),
              ),
            ),
          for (final entry in workflowStore.senderProfiles.entries)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(entry.value),
              subtitle: Text(entry.key),
              trailing: IconButton(
                tooltip: 'Remove sender profile',
                onPressed: () => workflowStore.removeSenderProfile(entry.key),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          const ListTile(
            leading: Icon(Icons.schedule_outlined),
            title: Text('Reminder timing'),
            subtitle: Text(
              'Generic notifications are scheduled by the operating system. Battery and notification settings may delay or suppress them; due messages also appear when GlassMail opens.',
            ),
          ),
          for (final reminder in workflowStore.reminders)
            ListTile(
              leading: Icon(
                reminder.kind == 'snooze'
                    ? Icons.snooze_rounded
                    : Icons.notifications_active_outlined,
              ),
              title: Text(
                reminder.kind == 'snooze'
                    ? 'Snoozed message'
                    : 'Follow-up reminder',
              ),
              subtitle: Text(
                'Due ${DateTime.fromMillisecondsSinceEpoch(reminder.atEpochMillis).toLocal()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: 'Dismiss reminder',
                onPressed: () => workflowStore.clearReminder(
                  reminder.messageId,
                  reminder.kind,
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          for (final scheduled in workflowStore.scheduledSends)
            _ScheduledSendTile(
              repository: repository,
              workflowStore: workflowStore,
              coordinator: delayedSendCoordinator,
              scheduled: scheduled,
            ),
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text('Storage advisor'),
            subtitle: const Text('Choose a smaller local cache with one step'),
            onTap: () => _showStorageAdvisor(context, repository, accounts),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clean local cache now'),
            subtitle: const Text(
              'Evicts eligible cached bodies and attachments',
            ),
            onTap: () async {
              for (final account in accounts) {
                await repository.enforceCacheLimits(account.accountId);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Local cache cleanup finished.'),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline_rounded),
            title: const Text('Create encrypted backup'),
            subtitle: const Text(
              'Backs up cached mail and settings with a passphrase',
            ),
            onTap: () => _createEncryptedBackup(
              context,
              repository,
              preferences,
              workflowStore,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.lock_open_rounded),
            title: const Text('Restore encrypted backup'),
            subtitle: const Text(
              'Restore on a clean install; account passwords are excluded',
            ),
            onTap: () => _restoreEncryptedBackup(
              context,
              repository,
              preferences,
              workflowStore,
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('New mail notifications'),
            subtitle: const Text('Tap to request notification permission'),
            onTap: () async {
              final allowed = await MailNotifications().requestPermission();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    allowed == true
                        ? 'Notifications enabled.'
                        : 'Notifications were not enabled.',
                  ),
                ),
              );
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show sender and subject in notifications'),
            subtitle: const Text('Off by default; hides message details'),
            value: preferences.showNotificationPreviews,
            onChanged: (value) =>
                preferences.update(showNotificationPreviews: value),
          ),
          ListTile(
            leading: const Icon(Icons.blur_on_rounded),
            title: const Text('Glass Lab'),
            onTap: onGlassLab,
          ),
          const _SafetyNote(
            'Mail is cached on this device. Account passwords use platform secure storage.',
          ),
        ],
      ),
    ),
  );
}

Future<void> _createTemplate(
  BuildContext context,
  MailWorkflowStore store,
) async {
  final template = await showDialog<MailTemplate>(
    context: context,
    builder: (_) => const _MailTemplateDialog(),
  );
  if (template != null) await store.saveTemplate(template);
}

Future<void> _createSavedView(
  BuildContext context,
  MailWorkflowStore store,
) async {
  final view = await showDialog<MailSavedView>(
    context: context,
    builder: (_) => const _SavedViewDialog(),
  );
  if (view != null) await store.saveView(view);
}

Future<void> _addScreenedSender(
  BuildContext context,
  MailWorkflowStore store,
) async {
  final sender = await showDialog<String>(
    context: context,
    builder: (_) => const _TextEntryDialog(
      title: 'Local sender screener',
      label: 'Sender email address',
      helper: 'Messages from this address will be hidden in GlassMail. Gmail will still receive them.',
    ),
  );
  if (sender != null) await store.setSenderMuted(sender, true);
}

Future<void> _showStorageAdvisor(
  BuildContext context,
  MailRepository repository,
  List<MailAccount> accounts,
) async {
  final apply = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Storage advisor'),
      content: const Text(
        'Use a compact local cache: keep 200 offline messages, cap cached attachments at 100 MB, remove eligible read bodies after 30 days, and stop prefetching unread bodies. This removes local cache files only; it does not delete mail from Gmail.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep current settings'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Apply compact cache'),
        ),
      ],
    ),
  );
  if (apply != true) return;
  for (final account in accounts) {
    await repository.saveCacheSettings(
      account.accountId,
      const MailCacheSettings(
        offlineMessageCount: 200,
        attachmentCacheLimitMb: 100,
        autoEvictReadOlderThanDays: 30,
        prefetchUnreadBodies: false,
      ),
    );
    await repository.enforceCacheLimits(account.accountId);
  }
}

Future<void> _createEncryptedBackup(
  BuildContext context,
  MailRepository repository,
  MailUserPreferences preferences,
  MailWorkflowStore workflowStore,
) async {
  final passphrase = await showDialog<String>(
    context: context,
    builder: (_) => const _BackupPassphraseDialog(confirm: true),
  );
  if (passphrase == null || !context.mounted) return;
  try {
    if (repository is! PortableMailBackupRepository) {
      throw UnsupportedError('Portable backups are not available.');
    }
    final backupRepository = repository as PortableMailBackupRepository;
    final payload = <String, Object?>{
      'format': 'glassmail.backup.v1',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'mailData': await backupRepository.exportBackupData(),
      'workflows': workflowStore.exportBackupState(),
      'appearance': preferences.exportBackupState(),
    };
    final plaintext = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    late final Uint8List encrypted;
    try {
      encrypted = await EncryptedMailBackup().encrypt(
        plaintext: plaintext,
        passphrase: passphrase,
      );
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/glassmail-backup-${DateTime.now().millisecondsSinceEpoch}.gmbak',
    );
    await file.writeAsBytes(encrypted, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            name: 'glassmail-backup.gmbak',
            mimeType: 'application/octet-stream',
          ),
        ],
        subject: 'GlassMail encrypted backup',
      ),
    );
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create encrypted backup: $error')),
      );
    }
  }
}

Future<void> _restoreEncryptedBackup(
  BuildContext context,
  MailRepository repository,
  MailUserPreferences preferences,
  MailWorkflowStore workflowStore,
) async {
  if (repository is! PortableMailBackupRepository) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup restore is not available.')),
    );
    return;
  }
  final backupRepository = repository as PortableMailBackupRepository;
  try {
    if ((await repository.observeAccounts().first).isNotEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restore is available only on a clean install.'),
        ),
      );
      return;
    }
    final selected = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'GlassMail encrypted backup',
          extensions: ['gmbak'],
        ),
      ],
    );
    if (selected == null || !context.mounted) return;
    final passphrase = await showDialog<String>(
      context: context,
      builder: (_) => const _BackupPassphraseDialog(confirm: false),
    );
    if (passphrase == null || !context.mounted) return;
    final encrypted = await selected.readAsBytes();
    final plaintext = await EncryptedMailBackup().decrypt(
      ciphertext: encrypted,
      passphrase: passphrase,
    );
    late final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(plaintext));
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'glassmail.backup.v1' ||
        decoded['mailData'] is! Map<String, dynamic> ||
        decoded['workflows'] is! Map<String, dynamic> ||
        decoded['appearance'] is! Map<String, dynamic>) {
      throw const FormatException('Backup contents are invalid.');
    }
    final mailData = decoded['mailData']! as Map<String, dynamic>;
    final workflows = decoded['workflows']! as Map<String, dynamic>;
    final appearance = decoded['appearance']! as Map<String, dynamic>;
    _validateAppearanceBackup(appearance);
    await backupRepository.restoreBackupData(mailData);
    await workflowStore.restoreBackupState(workflows);
    await preferences.restoreBackupState(appearance);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Backup restored. Enter each account password in Settings to sync.',
        ),
      ),
    );
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not restore backup: $error')),
      );
    }
  }
}

void _validateAppearanceBackup(Map<String, dynamic> values) {
  final themeName = values['themeMode'];
  if (themeName is! String ||
      !ThemeMode.values.any((theme) => theme.name == themeName) ||
      values['reduceTransparency'] is! bool ||
      values['reduceMotion'] is! bool ||
      values['showNotificationPreviews'] is! bool) {
    throw const FormatException('Appearance backup data is invalid.');
  }
}

class _BackupPassphraseDialog extends StatefulWidget {
  const _BackupPassphraseDialog({required this.confirm});

  final bool confirm;

  @override
  State<_BackupPassphraseDialog> createState() =>
      _BackupPassphraseDialogState();
}

class _BackupPassphraseDialogState extends State<_BackupPassphraseDialog> {
  final _passphrase = TextEditingController();
  final _confirmation = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _passphrase.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _passphrase.text;
    if (value.trim().length < 12 || value.length > 1024) {
      setState(
        () => _error = 'Use a passphrase between 12 and 1024 characters.',
      );
      return;
    }
    if (widget.confirm && value != _confirmation.text) {
      setState(() => _error = 'The passphrases do not match.');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.confirm ? 'Encrypt backup' : 'Unlock backup'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _passphrase,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Passphrase'),
        ),
        if (widget.confirm)
          TextField(
            controller: _confirmation,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm passphrase'),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Use at least 12 characters and keep this passphrase safe. GlassMail cannot recover it.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(widget.confirm ? 'Create backup' : 'Restore'),
      ),
    ],
  );
}

class _TextEntryDialog extends StatefulWidget {
  const _TextEntryDialog({
    required this.title,
    required this.label,
    this.initialValue = '',
    this.helper,
    this.onPickContact,
  });

  final String title;
  final String label;
  final String initialValue;
  final String? helper;
  final Future<String?> Function()? onPickContact;

  @override
  State<_TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<_TextEntryDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.helper != null) Text(widget.helper!),
        TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(labelText: widget.label),
        ),
        if (widget.onPickContact != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _pickContact,
              icon: const Icon(Icons.contacts_outlined),
              label: const Text('Choose from Contacts'),
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Save'),
      ),
    ],
  );

  Future<void> _pickContact() async {
    try {
      final name = await widget.onPickContact?.call();
      if (name != null && mounted) _controller.text = name;
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the selected contact.')),
      );
    }
  }
}

class _SavedViewDialog extends StatefulWidget {
  const _SavedViewDialog();

  @override
  State<_SavedViewDialog> createState() => _SavedViewDialogState();
}

class _SavedViewDialogState extends State<_SavedViewDialog> {
  final _name = TextEditingController();
  final _query = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Save custom search view'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'View name'),
        ),
        TextField(
          controller: _query,
          decoration: const InputDecoration(labelText: 'Search query'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_name.text.trim().isEmpty || _query.text.trim().isEmpty) return;
          Navigator.pop(
            context,
            MailSavedView(
              id: 'view-${DateTime.now().microsecondsSinceEpoch}',
              name: _name.text.trim(),
              query: _query.text.trim(),
            ),
          );
        },
        child: const Text('Save view'),
      ),
    ],
  );
}

class _MailTemplateDialog extends StatefulWidget {
  const _MailTemplateDialog();

  @override
  State<_MailTemplateDialog> createState() => _MailTemplateDialogState();
}

class _MailTemplateDialogState extends State<_MailTemplateDialog> {
  final _name = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create mail template'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Template name'),
            ),
            TextField(
              controller: _subject,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            TextField(
              controller: _body,
              minLines: 4,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Message body'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_name.text.trim().isEmpty) return;
          Navigator.pop(
            context,
            MailTemplate(
              id: 'template-${DateTime.now().microsecondsSinceEpoch}',
              name: _name.text.trim(),
              subject: _subject.text,
              body: _body.text,
            ),
          );
        },
        child: const Text('Save template'),
      ),
    ],
  );
}

Future<void> _updateAccountPassword(
  BuildContext context,
  MailRepository repository,
  MailAccount account,
) async {
  final updated = await showDialog<bool>(
    context: context,
    builder: (_) =>
        _AccountPasswordDialog(repository: repository, account: account),
  );
  if (updated == true && context.mounted) {
    unawaited(repository.synchronize(account.accountId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password updated. Syncing account…')),
    );
  }
}

class _AccountPasswordDialog extends StatefulWidget {
  const _AccountPasswordDialog({
    required this.repository,
    required this.account,
  });

  final MailRepository repository;
  final MailAccount account;

  @override
  State<_AccountPasswordDialog> createState() => _AccountPasswordDialogState();
}

class _AccountPasswordDialogState extends State<_AccountPasswordDialog> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.text.isEmpty) {
      setState(() => _error = 'Enter an app password.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final credential = Uint8List.fromList(utf8.encode(_controller.text));
    _controller.clear();
    try {
      await widget.repository.updateCredential(
        widget.account.accountId,
        credential,
      );
      if (mounted) Navigator.pop(context, true);
    } on Object catch (failure) {
      credential.fillRange(0, credential.length, 0);
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not update password: $failure';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Update app password'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter a new Google app password for ${widget.account.email}.'),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          autofocus: true,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(labelText: 'Google app password'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Save'),
      ),
    ],
  );
}

class _ScheduledSendTile extends StatelessWidget {
  const _ScheduledSendTile({
    required this.repository,
    required this.workflowStore,
    required this.coordinator,
    required this.scheduled,
  });

  final MailRepository repository;
  final MailWorkflowStore workflowStore;
  final DelayedSendCoordinator? coordinator;
  final ScheduledMailSend scheduled;

  Future<void> _cancel(BuildContext context) async {
    final result = await coordinator?.undo(scheduled.draftId) ?? false;
    if (!result) return;
    await workflowStore.removeScheduledSend(scheduled.draftId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scheduled message returned to Drafts.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final drafts = repository as DraftRepository?;
    if (drafts == null) return const SizedBox.shrink();
    return StreamBuilder<MailDraft?>(
      stream: drafts.observeDraft(scheduled.draftId),
      builder: (context, snapshot) {
        final draft = snapshot.data;
        final complete =
            draft == null ||
            draft.status == DraftStatus.sent ||
            draft.status == DraftStatus.failed;
        final due = DateTime.fromMillisecondsSinceEpoch(scheduled.atEpochMillis)
            .toLocal();
        return ListTile(
          leading: Icon(
            complete
                ? Icons.check_circle_outline
                : Icons.schedule_send_outlined,
          ),
          title: Text(
            draft?.status == DraftStatus.sent
                ? 'Scheduled message sent'
                : draft?.status == DraftStatus.failed
                ? 'Scheduled message needs attention'
                : draft == null
                ? 'Scheduled message is unavailable'
                : 'Scheduled send',
          ),
          subtitle: Text(
            draft == null
                ? 'Open Drafts to review it.'
                : 'Due $due · ${draft.to.join(', ')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            tooltip: complete
                ? 'Dismiss schedule record'
                : 'Cancel scheduled send',
            onPressed: complete
                ? () => workflowStore.removeScheduledSend(scheduled.draftId)
                : coordinator == null
                ? null
                : () => _cancel(context),
            icon: Icon(complete ? Icons.close_rounded : Icons.undo_rounded),
          ),
        );
      },
    );
  }
}

class _AccountCacheSettings extends StatelessWidget {
  const _AccountCacheSettings({
    required this.repository,
    required this.account,
  });

  final MailRepository repository;
  final MailAccount account;

  Future<void> _save(MailCacheSettings value) =>
      repository.saveCacheSettings(account.accountId, value);

  @override
  Widget build(BuildContext context) => StreamBuilder<MailCacheSettings>(
    stream: repository.observeCacheSettings(account.accountId),
    builder: (context, snapshot) {
      final settings = snapshot.data ?? const MailCacheSettings();
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.email,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              StreamBuilder<StorageQuota?>(
                stream: repository.observeStorageQuota(account.accountId),
                builder: (context, quotaSnapshot) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (quotaSnapshot.data case final quota?)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Gmail storage · ${_formatQuota(quota.usedKb)} of ${_formatQuota(quota.limitKb)} used',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            repository.refreshStorageQuota(account.accountId),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                          quotaSnapshot.data == null
                              ? 'Check Gmail storage'
                              : 'Refresh Gmail storage',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              DropdownButtonFormField<int>(
                initialValue: settings.offlineMessageCount,
                decoration: const InputDecoration(
                  labelText: 'Offline messages',
                ),
                items: const [200, 500, 1000]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value messages'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  _save(
                    MailCacheSettings(
                      offlineMessageCount: value,
                      attachmentCacheLimitMb: settings.attachmentCacheLimitMb,
                      autoEvictReadOlderThanDays:
                          settings.autoEvictReadOlderThanDays,
                      prefetchUnreadBodies: settings.prefetchUnreadBodies,
                    ),
                  );
                },
              ),
              DropdownButtonFormField<int>(
                initialValue: settings.attachmentCacheLimitMb,
                decoration: const InputDecoration(
                  labelText: 'Attachment cache',
                ),
                items: const [100, 500, 1000]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value MB'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  _save(
                    MailCacheSettings(
                      offlineMessageCount: settings.offlineMessageCount,
                      attachmentCacheLimitMb: value,
                      autoEvictReadOlderThanDays:
                          settings.autoEvictReadOlderThanDays,
                      prefetchUnreadBodies: settings.prefetchUnreadBodies,
                    ),
                  );
                },
              ),
              DropdownButtonFormField<int>(
                initialValue: settings.autoEvictReadOlderThanDays,
                decoration: const InputDecoration(
                  labelText: 'Remove older read message bodies',
                ),
                items: const [30, 60, 90]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('After $value days'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  _save(
                    MailCacheSettings(
                      offlineMessageCount: settings.offlineMessageCount,
                      attachmentCacheLimitMb: settings.attachmentCacheLimitMb,
                      autoEvictReadOlderThanDays: value,
                      prefetchUnreadBodies: settings.prefetchUnreadBodies,
                    ),
                  );
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Prefetch unread bodies'),
                value: settings.prefetchUnreadBodies,
                onChanged: (value) => _save(
                  MailCacheSettings(
                    offlineMessageCount: settings.offlineMessageCount,
                    attachmentCacheLimitMb: settings.attachmentCacheLimitMb,
                    autoEvictReadOlderThanDays:
                        settings.autoEvictReadOlderThanDays,
                    prefetchUnreadBodies: value,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AccountSetupRoute extends StatefulWidget {
  const _AccountSetupRoute({required this.repository});
  final MailRepository repository;

  @override
  State<_AccountSetupRoute> createState() => _AccountSetupRouteState();
}

class _AccountSetupRouteState extends State<_AccountSetupRoute> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final email = _email.text.trim();
    if (!validateAddresses([email]) || _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid Gmail address and app password.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final bytes = Uint8List.fromList(utf8.encode(_password.text));
    _password.clear();
    try {
      await widget.repository.createAccount(
        email.toLowerCase(),
        email,
        credentialUtf8: bytes,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      unawaited(widget.repository.synchronize(email.toLowerCase()));
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add account: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => _RouteScaffold(
    title: 'Add account',
    canPop: true,
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.lock_outline, size: 42),
        const SizedBox(height: 16),
        Text('Connect Gmail', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Use a Google app password. GlassMail connects over IMAP TLS and SMTP STARTTLS.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Gmail address'),
        ),
        TextField(
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(labelText: 'Google app password'),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _connect,
          child: Text(_saving ? 'Saving securely…' : 'Connect and sync'),
        ),
        const SizedBox(height: 12),
        const _SafetyNote(
          'The password is stored in Android Keystore-backed secure storage. It is not saved in the mail database.',
        ),
      ],
    ),
  );
}

class _RouteScaffold extends StatelessWidget {
  const _RouteScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.canPop = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final bool canPop;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: canPop ? const BackButton() : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          if (subtitle != null)
            Text(subtitle!, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
      actions: trailing == null ? null : [trailing!],
    ),
    body: SafeArea(top: false, child: child),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(detail, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    label: message,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(message, style: Theme.of(context).textTheme.bodySmall),
      ),
    ),
  );
}

String _address(String sender) {
  final match = RegExp(r'<([^>]+)>').firstMatch(sender);
  return match?.group(1) ?? sender.trim();
}

bool _looksLikeTrashMailboxId(String mailboxId) {
  final separator = mailboxId.indexOf(':');
  if (separator < 0 || separator == mailboxId.length - 1) return false;
  final remoteName = mailboxId.substring(separator + 1).toLowerCase();
  return remoteName == 'trash' ||
      remoteName == 'bin' ||
      remoteName.endsWith('/trash');
}

File _localAttachmentFile(String value) {
  final uri = Uri.tryParse(value);
  return File(uri != null && uri.scheme == 'file' ? uri.toFilePath() : value);
}

String _attachmentDetails(MailAttachment attachment) {
  final state = attachment.downloadState == 'AVAILABLE'
      ? 'Cached'
      : 'Tap to share';
  final size = attachment.sizeBytes == null
      ? null
      : _formatBytes(attachment.sizeBytes!);
  return [?size, state].join(' · ');
}

String _formatBytes(int size) => size < 1024
    ? '$size B'
    : size < 1024 * 1024
    ? '${(size / 1024).toStringAsFixed(1)} KB'
    : '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';

String _formatQuota(int sizeKb) => sizeKb < 1024
    ? '$sizeKb KB'
    : sizeKb < 1024 * 1024
    ? '${(sizeKb / 1024).toStringAsFixed(1)} MB'
    : '${(sizeKb / (1024 * 1024)).toStringAsFixed(1)} GB';

String _formatDate(int? timestamp) => timestamp == null
    ? 'Sent mail'
    : DateTime.fromMillisecondsSinceEpoch(timestamp)
          .toLocal()
          .toString()
          .substring(0, 16);

List<String> _parseAddresses(String input) =>
    input.split(RegExp(r'[,;\s]+')).where((value) => value.isNotEmpty).toList();

String _initial(String input) => input.trim().isEmpty
    ? '?'
    : String.fromCharCode(input.trim().runes.first).toUpperCase();

MailAccount? _ownerOf(MailListItem item, List<MailAccount> accounts) =>
    accounts.where((account) {
      final id = account.accountId;
      return item.messageId.startsWith('gmail:$id:') ||
          item.messageId.startsWith('imap:$id:');
    }).firstOrNull;

String _categoryLabel(String category) => switch (category) {
  'SNOOZED' => 'Snoozed',
  'TRASH' => 'Trash',
  MailCategory.primary => 'Primary',
  MailCategory.social => 'Social',
  MailCategory.promotions => 'Promotions',
  MailCategory.updates => 'Updates',
  MailCategory.forums => 'Forums',
  _ => category,
};

Stream<List<MailListItem>> _combineMailStreams(
  Iterable<Stream<List<MailListItem>>> sourceStreams,
) {
  final streams = sourceStreams.toList(growable: false);
  if (streams.isEmpty) return Stream.value(const []);
  return Stream.multi((controller) {
    final latest = List<List<MailListItem>?>.filled(streams.length, null);
    final subscriptions = <StreamSubscription<List<MailListItem>>>[];
    for (var index = 0; index < streams.length; index++) {
      final slot = index;
      subscriptions.add(
        streams[index].listen((items) {
          latest[slot] = items;
          if (latest.every((value) => value != null)) {
            controller.add(latest.expand((value) => value!).toList());
          }
        }, onError: controller.addError),
      );
    }
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
  });
}

class _SafeMessageBody extends StatelessWidget {
  const _SafeMessageBody({
    required this.text,
    required this.onOpen,
    required this.onPreview,
    required this.previewingLink,
  });

  final String text;
  final ValueChanged<Uri> onOpen;
  final ValueChanged<Uri> onPreview;
  final Uri? previewingLink;

  @override
  Widget build(BuildContext context) {
    final links = _extractSafeLinks(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(text),
        for (final uri in links)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.open_in_browser_rounded),
            title: Text(uri.host),
            subtitle: Text(
              uri.toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'Preview link',
              onPressed: previewingLink == null ? () => onPreview(uri) : null,
              icon: previewingLink == uri
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.preview_outlined),
            ),
            onTap: () => onOpen(uri),
          ),
      ],
    );
  }
}

List<Uri> _extractSafeLinks(String text) {
  final links = <String>{};
  for (final match in RegExp(
    r'https?://[^\s<>"\u0000-\u001f]+',
    caseSensitive: false,
  ).allMatches(text)) {
    final raw = (match.group(0) ?? '').replaceFirst(
      RegExp(r'[.,;:!?)}\]]+$'),
      '',
    );
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      continue;
    }
    links.add(uri.toString());
  }
  return links.map(Uri.parse).toList(growable: false);
}

Future<void> _showCommandPalette(
  BuildContext context, {
  required VoidCallback onSearch,
  required VoidCallback onCompose,
  required VoidCallback onSettings,
  required VoidCallback onGlassLab,
}) async {
  final commands = <({String title, IconData icon, VoidCallback action})>[
    (title: 'Search mail', icon: Icons.search, action: onSearch),
    (title: 'Compose message', icon: Icons.edit_outlined, action: onCompose),
    (title: 'Open settings', icon: Icons.settings_outlined, action: onSettings),
    (title: 'Open Glass Lab', icon: Icons.blur_on, action: onGlassLab),
  ];
  final query = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, refresh) {
        final matches = commands
            .where(
              (command) => command.title.toLowerCase().contains(
                query.text.toLowerCase(),
              ),
            )
            .toList(growable: false);
        return AlertDialog(
          title: const Text('Commands'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  autofocus: true,
                  onChanged: (_) => refresh(() {}),
                  controller: query,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Find an action',
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final command in matches)
                        ListTile(
                          leading: Icon(command.icon),
                          title: Text(command.title),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            command.action();
                          },
                        ),
                      if (matches.isEmpty)
                        const ListTile(title: Text('No matching commands')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  query.dispose();
}
