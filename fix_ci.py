import re

def fix_android_yml():
    with open('.github/workflows/android.yml', 'r') as f:
        content = f.read()
    content = content.replace(
        "      - uses: android-actions/setup-android@v3\n        with:\n          cmdline-tools-version: 11479570",
        "      - uses: android-actions/setup-android@v3\n        with:\n          packages: 'cmdline-tools platform-tools'\n          cmdline-tools-version: 11479570"
    )
    with open('.github/workflows/android.yml', 'w') as f:
        f.write(content)

def fix_flutter_yml():
    with open('.github/workflows/flutter.yml', 'r') as f:
        content = f.read()
    content = content.replace(
        "      - uses: android-actions/setup-android@v3\n        with:\n          cmdline-tools-version: 11479570",
        "      - uses: android-actions/setup-android@v3\n        with:\n          packages: 'cmdline-tools platform-tools'\n          cmdline-tools-version: 11479570"
    )
    content = content.replace("version: 'any'", "version: '3.47.5'")
    with open('.github/workflows/flutter.yml', 'w') as f:
        f.write(content)

def fix_flutter_ci_yml():
    with open('.github/workflows/flutter_ci.yml', 'r') as f:
        content = f.read()
    content = content.replace(
        "      - uses: android-actions/setup-android@v3\n        with:\n          cmdline-tools-version: 11479570",
        "      - uses: android-actions/setup-android@v3\n        with:\n          packages: 'cmdline-tools platform-tools'\n          cmdline-tools-version: 11479570"
    )
    content = content.replace("flutter-version: 'any'", "flutter-version: '3.47.5'")
    with open('.github/workflows/flutter_ci.yml', 'w') as f:
        f.write(content)

fix_android_yml()
fix_flutter_yml()
fix_flutter_ci_yml()
