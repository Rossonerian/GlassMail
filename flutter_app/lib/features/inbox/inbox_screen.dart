import 'package:flutter/material.dart';

import '../../design/glass_mail_glass.dart';
import '../../design/liquid_glass_nav_bar.dart';
import '../../design/dock_visibility_controller.dart';
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
  final Set<int> _starred = {1, 5};

  late final DockVisibilityController _visibilityController;

  @override
  void initState() {
    super.initState();
    _visibilityController = DockVisibilityController();
  }

  @override
  void dispose() {
    _visibilityController.dispose();
    super.dispose();
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
      bottomNavigationBar: LiquidGlassNavBar(
        selected: "Inbox",
        visibilityController: _visibilityController,
      ),
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
          onNotification: _visibilityController.handleScrollNotification,
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
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    mailDockTotalHeight(context) + 24,
                  ),
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
