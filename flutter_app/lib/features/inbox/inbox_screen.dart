import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../design/glass_mail_glass.dart';
import '../../design/glass_material.dart';
import '../../design/glass_mail_theme.dart';
import '../glass_lab/glass_lab_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool _unreadOnly = false;
  bool _dockCollapsed = false;
  double _userDragTravel = 0;
  int _userDragDirection = 0;
  final Set<int> _starred = {1, 5};

  bool _handleInboxScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;

    if (notification is ScrollStartNotification) {
      _userDragTravel = 0;
      _userDragDirection = 0;
      return false;
    }

    if (notification is ScrollEndNotification) {
      _userDragTravel = 0;
      _userDragDirection = 0;
      return false;
    }

    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      final delta = notification.scrollDelta ?? 0;
      final direction = delta.compareTo(0);
      if (direction == 0) return false;
      if (_userDragDirection != direction) {
        _userDragDirection = direction;
        _userDragTravel = 0;
      }
      _userDragTravel += delta.abs();

      final reachedTop = notification.metrics.pixels <= 0;
      final shouldCollapse =
          !_dockCollapsed && direction > 0 && _userDragTravel >= 72;
      final shouldExpand =
          _dockCollapsed &&
          ((direction < 0 && _userDragTravel >= 48) || reachedTop);
      if (shouldCollapse || shouldExpand) {
        setState(() => _dockCollapsed = shouldCollapse);
        _userDragTravel = 0;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visible = _messages
        .where((message) => !_unreadOnly || message.unread)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: colors.surface,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: const _InboxCapsule(),
      bottomNavigationBar: MorphingMailDock(collapsed: _dockCollapsed),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(1.0, -1.1),
            radius: 1.35,
            colors: [
              colors.secondary.withValues(alpha: .10),
              Colors.transparent,
            ],
          ),
        ),
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleInboxScroll,
          child: CustomScrollView(
            key: const PageStorageKey('inbox-preview-list'),
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.paddingOf(context).top + 72),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Inbox',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -.8,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '5 unread · just for you',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Compose message',
                            onPressed: () => _showPreviewNotice(context),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 8,
                        children: [
                          _FilterPill(
                            label: 'All mail',
                            selected: !_unreadOnly,
                            onTap: () => setState(() => _unreadOnly = false),
                          ),
                          _FilterPill(
                            label: 'Unread',
                            selected: _unreadOnly,
                            onTap: () => setState(() => _unreadOnly = true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'TODAY',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.5,
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
              SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(left: 92),
                  child: Divider(
                    height: 1,
                    color: colors.outlineVariant.withValues(alpha: .7),
                  ),
                ),
                itemBuilder: (context, index) {
                  final message = visible[index];
                  return _MailRow(
                    message: message,
                    starred: _starred.contains(message.id),
                    onStar: () => setState(() {
                      if (!_starred.add(message.id)) {
                        _starred.remove(message.id);
                      }
                    }),
                    onOpen: () => _showPreviewNotice(context),
                  );
                },
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 34),
                  child: Center(
                    child: Text(
                      'Sample inbox · no mail account connected',
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxCapsule extends StatelessWidget implements PreferredSizeWidget {
  const _InboxCapsule();

  @override
  Size get preferredSize => const Size.fromHeight(96);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
        child: GlassMailGlass(
          material: GlassPresets.toolbar,
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                const SizedBox(width: 10),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.mark_email_unread_rounded,
                    color: colors.primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'GlassMail',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.4,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Search mail',
                  onPressed: () => _showPreviewNotice(context),
                  icon: const Icon(Icons.search_rounded),
                  color: colors.onSurface,
                ),
                IconButton(
                  tooltip: 'Glass Lab',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GlassLabScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.science_outlined),
                  color: colors.onSurface,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MorphingMailDock extends StatefulWidget {
  const MorphingMailDock({
    required this.collapsed,
    super.key,
    this.selected = 'Inbox',
    this.onDestinationSelected,
    this.onQuickSearch,
  });

  final bool collapsed;
  final String selected;
  final ValueChanged<String>? onDestinationSelected;
  final VoidCallback? onQuickSearch;

  @override
  State<MorphingMailDock> createState() => _MorphingMailDockState();
}

class _MorphingMailDockState extends State<MorphingMailDock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: widget.collapsed ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant MorphingMailDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collapsed != widget.collapsed) {
      _controller.animateTo(
        widget.collapsed ? 1 : 0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dockHeight = mailDockContentHeight(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: LayoutBuilder(
            builder: (context, constraints) {
              final progress = Curves.easeOutCubic.transform(_controller.value);
              final width = lerpDouble(constraints.maxWidth, 156, progress)!;
              return Center(
                child: SizedBox(
                  key: ValueKey(
                    widget.collapsed
                        ? 'mail-dock-compact'
                        : 'mail-dock-expanded',
                  ),
                  width: width,
                  child: GlassMailGlass(
                    material: GlassPresets.bottomBar,
                    child: SizedBox(
                      height: dockHeight,
                      child: ClipRect(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: ExcludeSemantics(
                                excluding: widget.collapsed,
                                child: IgnorePointer(
                                  ignoring: widget.collapsed,
                                  child: Opacity(
                                    opacity: 1 - progress,
                                    child: _expandedContents(context),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: ExcludeSemantics(
                                excluding: !widget.collapsed,
                                child: IgnorePointer(
                                  ignoring: !widget.collapsed,
                                  child: Opacity(
                                    opacity: progress,
                                    child: _compactContents(context),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ));
  }

  Widget _expandedContents(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _DockItem(
        icon: Icons.inbox_rounded,
        label: 'Inbox',
        selected: widget.selected == 'Inbox',
        onTap: () => _selectDestination(context, 'Inbox'),
      ),
      _DockItem(
        icon: Icons.search_rounded,
        label: 'Search',
        selected: widget.selected == 'Search',
        onTap: () => _selectDestination(context, 'Search'),
      ),
      _DockItem(
        icon: Icons.send_outlined,
        label: 'Sent',
        selected: widget.selected == 'Sent',
        onTap: () => _selectDestination(context, 'Sent'),
      ),
      _DockItem(
        icon: Icons.settings_outlined,
        label: 'Settings',
        selected: widget.selected == 'Settings',
        onTap: () => _selectDestination(context, 'Settings'),
      ),
    ],
  );

  Widget _compactContents(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _DockItem(
        icon: _iconForDestination(widget.selected),
        label: widget.selected,
        selected: true,
        onTap: () => _selectDestination(context, widget.selected),
      ),
      IconButton(
        tooltip: 'Quick search',
        onPressed:
            widget.onQuickSearch ?? () => _selectDestination(context, 'Search'),
        icon: const Icon(Icons.search_rounded),
      ),
    ],
  );

  void _selectDestination(BuildContext context, String destination) {
    final onSelect = widget.onDestinationSelected;
    if (onSelect == null) {
      _showPreviewNotice(context);
    } else {
      onSelect(destination);
    }
  }

  IconData _iconForDestination(String destination) => switch (destination) {
    'Search' => Icons.search_rounded,
    'Sent' => Icons.send_outlined,
    'Settings' => Icons.settings_outlined,
    _ => Icons.inbox_rounded,
  };
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dockHeight = mailDockContentHeight(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 68,
          height: dockHeight - 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double mailDockContentHeight(BuildContext context) => math.max(
  64,
  math.min(120, 44 + MediaQuery.textScalerOf(context).scale(1) * 20),
);

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary
                : colors.surface.withValues(alpha: .62),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? colors.onPrimary : colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _MailRow extends StatelessWidget {
  const _MailRow({
    required this.message,
    required this.starred,
    required this.onStar,
    required this.onOpen,
  });
  final _PreviewMessage message;
  final bool starred;
  final VoidCallback onStar;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label:
          '${message.sender}, ${message.subject}, ${message.time}${message.unread ? ', unread' : ''}',
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 18, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: CircleAvatar(
                  radius: 23,
                  backgroundColor: message.color.withValues(alpha: .18),
                  child: Text(
                    message.initials,
                    style: TextStyle(
                      color: message.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.sender,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: message.unread
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                          ),
                        ),
                        Text(
                          message.time,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: message.unread
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                                fontWeight: message.unread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: message.unread
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: colors.onSurface,
                                ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                          padding: EdgeInsets.zero,
                          tooltip: starred ? 'Remove star' : 'Star message',
                          onPressed: onStar,
                          icon: Icon(
                            starred
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 19,
                            color: starred
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      message.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (message.unread)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 24),
                  child: CircleAvatar(
                    radius: 3.5,
                    backgroundColor: colors.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showPreviewNotice(BuildContext context) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    const SnackBar(
      content: Text(
        'This is a sample inbox preview. Mail actions arrive in the next packets.',
      ),
    ),
  );
}

class _PreviewMessage {
  const _PreviewMessage({
    required this.id,
    required this.sender,
    required this.initials,
    required this.subject,
    required this.preview,
    required this.time,
    required this.color,
    this.unread = false,
  });
  final int id;
  final String sender;
  final String initials;
  final String subject;
  final String preview;
  final String time;
  final Color color;
  final bool unread;
}

const _messages = <_PreviewMessage>[
  _PreviewMessage(
    id: 1,
    sender: 'Maya Chen',
    initials: 'MC',
    subject: 'A little weekend plan?',
    preview: 'Found a quiet place by the water. Saturday could be perfect…',
    time: '9:42 AM',
    color: GlassMailPalette.priority,
    unread: true,
  ),
  _PreviewMessage(
    id: 2,
    sender: 'Studio North',
    initials: 'SN',
    subject: 'Your September collection is here',
    preview: 'A few new pieces we thought you might like.',
    time: '9:18 AM',
    color: GlassMailPalette.newsletters,
    unread: true,
  ),
  _PreviewMessage(
    id: 3,
    sender: 'Daniel Rivera',
    initials: 'DR',
    subject: 'Re: Project notes',
    preview: 'Thanks — I added the final details to the shared doc.',
    time: '8:56 AM',
    color: GlassMailPalette.work,
    unread: true,
  ),
  _PreviewMessage(
    id: 4,
    sender: 'Field Notes',
    initials: 'FN',
    subject: 'The art of taking the long way',
    preview: 'A short read for the days that need a little more room.',
    time: '8:30 AM',
    color: GlassMailPalette.updates,
    unread: true,
  ),
  _PreviewMessage(
    id: 5,
    sender: 'Olivia Park',
    initials: 'OP',
    subject: 'Photos from Sunday',
    preview: 'I finally sorted through them — these are my favorites.',
    time: 'Yesterday',
    color: GlassMailPalette.personal,
    unread: true,
  ),
  _PreviewMessage(
    id: 6,
    sender: 'Good Things Daily',
    initials: 'GT',
    subject: 'A softer start to the day',
    preview: 'Small rituals, fresh pages, and a very good cup of tea.',
    time: 'Yesterday',
    color: GlassMailPalette.reminders,
  ),
  _PreviewMessage(
    id: 7,
    sender: 'Ari Patel',
    initials: 'AP',
    subject: 'Dinner next week?',
    preview: 'Tuesday or Wednesday both work on my end.',
    time: 'Mon',
    color: GlassMailPalette.promotions,
  ),
  _PreviewMessage(
    id: 8,
    sender: 'GlassMail',
    initials: 'GM',
    subject: 'Welcome to a calmer inbox',
    preview: 'Your mail, thoughtfully organized and ready when you are.',
    time: 'Sun',
    color: GlassMailPalette.secondary,
  ),
  _PreviewMessage(
    id: 9,
    sender: 'Noah Williams',
    initials: 'NW',
    subject: 'The book you mentioned',
    preview: 'I found it at the little shop on King Street.',
    time: 'Sat',
    color: GlassMailPalette.reminders,
  ),
  _PreviewMessage(
    id: 10,
    sender: 'The Daily Edit',
    initials: 'DE',
    subject: 'Sunday reading list',
    preview: 'Five stories worth slowing down for this weekend.',
    time: 'Fri',
    color: GlassMailPalette.newsletters,
  ),
];
