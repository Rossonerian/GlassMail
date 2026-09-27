#!/bin/bash
git checkout main
git branch -D chore-consolidate-unused-imports 2>/dev/null || true
git checkout -b chore-consolidate-unused-imports

# Remove LocalGlassPreferences from GlassLabScreen.kt
sed -i '/import com.glassmail.designsystem.glass.LocalGlassPreferences/d' app/src/main/kotlin/com/glassmail/app/GlassLabScreen.kt

# Remove AnimatedVisibility from GlassLabScreen.kt
sed -i '/import androidx.compose.animation.AnimatedVisibility/d' app/src/main/kotlin/com/glassmail/app/GlassLabScreen.kt

# Remove Search from GlassMailApp.kt
sed -i '/import androidx.compose.material.icons.filled.Search/d' app/src/main/kotlin/com/glassmail/app/GlassMailApp.kt

# Remove MailAccount import from GlassMailApp.kt
sed -i '/import com.glassmail.domain.mail.MailAccount/d' app/src/main/kotlin/com/glassmail/app/GlassMailApp.kt

# Fix format of mail_workspace_screen.dart (which was PR 6)
export PATH=$PATH:$HOME/devtools/flutter-sdk/flutter/bin
cd flutter_app
dart format lib/features/routes/mail_workspace_screen.dart
cd ..


export PATH=$PATH:$HOME/devtools/flutter-sdk/flutter/bin
cd flutter_app
flutter analyze || exit 1
cd ..

git add .
git commit -m "🧹 chore: consolidate unused import removals

Resolves duplicates and conflicts from PRs #5, #6, #14, #19, #20 by combining all cleanups:
- Remove LocalGlassPreferences from GlassLabScreen
- Remove AnimatedVisibility from GlassLabScreen
- Remove Search from GlassMailApp
- Remove MailAccount from GlassMailApp
- Format mail_workspace_screen.dart"

git push origin HEAD -f
gh pr create --title "🧹 chore: consolidate unused import removals" --body "Resolves duplicates and conflicts from PRs #5, #6, #14, #19, #20."
