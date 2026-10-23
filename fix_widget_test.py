import re

with open("flutter_app/test/widget_test.dart", "r") as f:
    content = f.read()

if "import 'package:glassmail/design/liquid_glass_nav_bar.dart';" not in content:
    content = content.replace(
        "import 'package:glassmail/design/glass_mail_theme.dart';",
        "import 'package:glassmail/design/glass_mail_theme.dart';\nimport 'package:glassmail/design/liquid_glass_nav_bar.dart';"
    )

content = content.replace(
    "expect(find.byKey(const ValueKey('mail-dock-expanded')), findsOneWidget);",
    "expect(tester.widget<LiquidGlassNavBar>(find.byType(LiquidGlassNavBar)).visibilityController.isCollapsed, isFalse);"
)

content = content.replace(
    "expect(find.byKey(const ValueKey('mail-dock-compact')), findsOneWidget);",
    "expect(tester.widget<LiquidGlassNavBar>(find.byType(LiquidGlassNavBar)).visibilityController.isCollapsed, isTrue);"
)

with open("flutter_app/test/widget_test.dart", "w") as f:
    f.write(content)
