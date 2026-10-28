import re

with open('flutter_app/lib/features/inbox/inbox_screen.dart', 'r') as f:
    content = f.read()

# Replace MorphingMailDock with LiquidGlassNavBar usage
content = re.sub(
    r'bottomNavigationBar: MorphingMailDock\(collapsed: _dockCollapsed\),',
    'bottomNavigationBar: LiquidGlassNavBar(selected: "Inbox", visibilityController: _visibilityController),',
    content
)

# Replace MorphingMailDock definition
content = re.sub(
    r'class MorphingMailDock extends StatefulWidget.*',
    '',
    content,
    flags=re.DOTALL
)

with open('flutter_app/lib/features/inbox/inbox_screen.dart', 'w') as f:
    f.write(content)
