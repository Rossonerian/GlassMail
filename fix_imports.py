import re

with open('flutter_app/lib/features/inbox/inbox_screen.dart', 'r') as f:
    content = f.read()

if 'liquid_glass_nav_bar.dart' not in content:
    content = re.sub(
        r'import \'../../design/glass_mail_glass.dart\';',
        'import \'../../design/glass_mail_glass.dart\';\nimport \'../../design/liquid_glass_nav_bar.dart\';\nimport \'../../design/dock_visibility_controller.dart\';',
        content
    )
    with open('flutter_app/lib/features/inbox/inbox_screen.dart', 'w') as f:
        f.write(content)
