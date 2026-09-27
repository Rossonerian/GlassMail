#!/bin/bash
FILE="core/imap/src/main/kotlin/com/glassmail/core/imap/GmailImapClient.kt"

# Remove the empty block at 292
sed -i '/<<<<<<< HEAD/,/======/d' "$FILE"

# Wait, the first conflict at 292 is:
# <<<<<<< HEAD
#     fun writeLogin(tag: String, email: String, password: CharArray) { ... }
# =======
# >>>>>>> origin/main
# I can just remove the markers for that block.

