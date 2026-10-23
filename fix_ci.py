import re

for filename in ['.github/workflows/android.yml', '.github/workflows/flutter.yml', '.github/workflows/flutter_ci.yml']:
    with open(filename, 'r') as f:
        content = f.read()

    # Remove the block entirely
    content = re.sub(r'\s*- uses: android-actions/setup-android@v3\n\s*with:\n\s*packages: \'cmdline-tools platform-tools\'\n\s*cmdline-tools-version: 11479570', '', content)
    content = re.sub(r'\s*- uses: android-actions/setup-android@v3\n\s*with:\n\s*cmdline-tools-version: 11479570', '', content)

    # Set flutter version correctly
    content = content.replace("version: 'any'", "version: '3.47.5'")
    content = content.replace("flutter-version: 'any'", "flutter-version: '3.47.5'")

    with open(filename, 'w') as f:
        f.write(content)
