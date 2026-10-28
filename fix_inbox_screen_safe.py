import re

with open('flutter_app/lib/features/inbox/inbox_screen.dart', 'r') as f:
    content = f.read()

if 'liquid_glass_nav_bar.dart' not in content:
    content = re.sub(
        r"import '../../design/glass_mail_glass.dart';",
        "import '../../design/glass_mail_glass.dart';\nimport '../../design/liquid_glass_nav_bar.dart';\nimport '../../design/dock_visibility_controller.dart';",
        content
    )

content = re.sub(
    r"class _InboxScreenState extends State<InboxScreen> \{.*?\n  final Set<int> _starred = \{1, 5\};",
    """class _InboxScreenState extends State<InboxScreen> {
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
  }""",
    content,
    flags=re.DOTALL
)

content = re.sub(
    r"bool _handleInboxScroll\(ScrollNotification notification\) \{.*?return false;\n  \}",
    """bool _handleInboxScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    
    if (notification is ScrollUpdateNotification && notification.dragDetails != null) {
      final delta = notification.scrollDelta ?? 0;
      _visibilityController.updateScroll(delta);
    }
    
    if (notification.metrics.pixels <= 0) {
      _visibilityController.setExpanded();
    }
    
    return false;
  }""",
    content,
    flags=re.DOTALL
)

content = re.sub(
    r"bottomNavigationBar: MorphingMailDock\(collapsed: _dockCollapsed\),",
    'bottomNavigationBar: LiquidGlassNavBar(selected: "Inbox", visibilityController: _visibilityController),',
    content
)

content = re.sub(
    r"SliverToBoxAdapter\(\s*child: Padding\(\s*padding: const EdgeInsets\.fromLTRB\(24, 24, 24, 34\),\s*child: Center\(\s*child: Text\(\s*'Sample inbox · no mail account connected',",
    """SliverToBoxAdapter(
                child: Builder(
                  builder: (context) {
                    final viewPadding = MediaQuery.viewPaddingOf(context);
                    final dockHeight = math.max(
                      64.0,
                      math.min(120.0, 44 + MediaQuery.textScalerOf(context).scale(1) * 20),
                    );
                    final bottomInset = dockHeight + 12.0 + viewPadding.bottom + 24.0;
                    
                    return Padding(
                      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset),
                      child: Center(
                        child: Text(
                          'Sample inbox · no mail account connected',""",
    content
)

# We need to add the closing bracket for Builder!
# Let's just use string replace on the specific ending block of that SliverToBoxAdapter.
content = content.replace(
"""                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
            ],
          ),""",
"""                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                );
              }),
              ),
            ],
          ),"""
)

if 'dart:math' not in content:
    content = "import 'dart:math' as math;\n" + content

# ONLY remove MorphingMailDock classes by looking for exactly their definitions
content = re.sub(
    r"class MorphingMailDock extends StatefulWidget \{.*?class _DockItem extends StatelessWidget \{.*?\n\}\n",
    "",
    content,
    flags=re.DOTALL
)

with open('flutter_app/lib/features/inbox/inbox_screen.dart', 'w') as f:
    f.write(content)
