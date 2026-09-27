import re

with open("core/imap/src/main/kotlin/com/glassmail/core/imap/GmailImapClient.kt", "r") as f:
    content = f.read()

# Conflict 1
c1_pattern = re.compile(r'<<<<<<< HEAD\n(    fun writeLogin.*?)\n=======\n>>>>>>> origin/main\n', re.DOTALL)
content = c1_pattern.sub(r'\1\n', content)

# Conflict 2
c2_pattern = re.compile(r'<<<<<<< HEAD\n(        val tag =.*?)\n=======\n        execute.*?\n>>>>>>> origin/main\n', re.DOTALL)
content = c2_pattern.sub(r'\1\n', content)

# Conflict 3
c3_pattern = re.compile(r'<<<<<<< HEAD\n=======\n(// ⚡ Bolt: Extracted.*?)\n>>>>>>> origin/main\n', re.DOTALL)
content = c3_pattern.sub(r'\1\n', content)

# Conflict 4
c4_pattern = re.compile(r'<<<<<<< HEAD\n        runCatching.*?=======\n(        runCatching.*?)\n>>>>>>> origin/main\n', re.DOTALL)
content = c4_pattern.sub(r'\1\n', content)

with open("core/imap/src/main/kotlin/com/glassmail/core/imap/GmailImapClient.kt", "w") as f:
    f.write(content)

