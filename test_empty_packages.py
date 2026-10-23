import re

for filename in ['.github/workflows/android.yml', '.github/workflows/flutter.yml', '.github/workflows/flutter_ci.yml']:
    with open(filename, 'r') as f:
        content = f.read()
    content = content.replace("packages: 'cmdline-tools platform-tools'", "packages: ''")
    with open(filename, 'w') as f:
        f.write(content)
