# SQLite 3.53.4 amalgamation

`sqlite3.c` and `sqlite3.h` are the official SQLite amalgamation from:

- Source: <https://www.sqlite.org/2026/sqlite-amalgamation-3530400.zip>
- Version: 3.53.4
- Download SHA3-256: `628a44cfe82c66aed1ccbbe85a562d2e33ebe64b3288981ed76285612227934e`

SQLite is in the public domain. The Flutter workspace's `sqlite3` build hook
retains the package's default compile options and additionally defines
`SQLITE_ENABLE_FTS4` so the Room v10 FTS4 schema is available on every bundled
SQLite target. The amalgamation is kept unchanged.
