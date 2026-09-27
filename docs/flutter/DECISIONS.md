# Flutter migration decisions

This file records reversible defaults and evidence-backed decisions for the Flutter migration. It does not imply a production cutover.

## D-001 — Run Kotlin and Flutter side by side

**Decision:** Keep the existing Kotlin app, modules, CI and database migrations in-tree and buildable throughout Phase 0. Create a different Flutter development application ID / bundle ID so installing the prototype cannot replace the native app.

**Reason:** The Kotlin app is the current implementation and holds the behavioral reference. A Flutter build alone does not prove data continuity or feature parity.

**Revisit when:** Android and iOS parity is demonstrated and a release owner accepts the remaining platform gaps.

## D-002 — Start Flutter with a fresh database and re-sync

**Decision:** The first Flutter prototype uses a new local cache and re-syncs from the configured account. Do not delete, overwrite, or claim to import the existing Room database. Preserve drafts by retaining the Kotlin installation; production cutover requires a separately tested export/import or a later approved continuity plan plus rollback rehearsal.

**Reason:** Room v10 includes pending mutations, drafts, send state, checkpoints, notification baselines, cache configuration and quota. A fresh install is not a Room migration test.

## D-003 — Pin stable Flutter and use Dart pub workspaces

**Decision:** Use Flutter `3.47.5` / Dart `3.13.4` as the initial reproducible toolchain and built-in Pub workspaces for packages under `flutter_app/packages/*`. Do not add Melos unless concrete workflow needs appear.

**Reason:** The target toolchain includes built-in workspace support and avoids an extra package-management layer. Recheck the pinned version against CI and the selected plugins when dependencies are introduced.

## D-004 — Preserve Android's current app constraints initially

**Decision:** The native Android app is `com.glassmail.app`, min SDK 34, target/compile SDK 35, Java/Kotlin 17. Flutter uses `com.glassmail.dev.glassmail`, min SDK 34 and target/compile SDK 35. The generated iOS host uses bundle ID `com.glassmail.dev.glassmail` and deployment target 15.0. Do not change production ID, signing, or native targets as part of scaffolding.

**Build note:** Flutter 3.47.5's doctor currently asks for Android platform SDK 36 and reports some SDK licenses unaccepted on this machine. The host's compile/target SDK remain 35 to match the current Kotlin baseline, and its App Bundle has built successfully with that configuration. This is recorded as a toolchain warning, not treated as a clean doctor result.

## D-005 — iOS source can be scaffolded here; iOS execution cannot

**Decision:** Generate the iOS host and include macOS/Xcode build gates, but mark simulator/device results NOT RUN on the current Linux host. Treat notification timing, background refresh and any scheduled send while suspended as best-effort unless a separate server architecture is authorized.

## D-006 — Do not select transport or glass dependencies before capability evidence

**Decision:** No Flutter IMAP/SMTP or glass package is accepted by name alone. First port source contracts and run a capability/license/platform/performance evaluation for each dependency. An app-owned adapter must provide an opaque and accessible fallback.

**Reason:** The native app relies on Gmail-specific IMAP extensions, bounded literals, Android IDLE, an Android Keystore boundary and a renderer whose Flutter equivalent is not established.

## D-007 — Keep GlassMail's brand and content hierarchy

**Decision:** Derive Flutter tokens from `designsystem/.../GlassMailTheme.kt`, local font assets/licenses, icons and current screens. Keep message rows, reader body, settings forms and compose body flat/high contrast; confine glass to selected floating chrome. Do not copy Karmi branding/backend or Square code/assets.

## D-008 — Room v10 is the persistence source of truth

**Decision:** The Flutter schema starts from the exported v10 model and entity/DAO behavior. Retain FTS4-equivalent semantics for the initial port. Any FTS change needs explicit performance evidence and a reversible schema migration. Fresh Flutter installs start at their own baseline and do not claim 1→10 Room migration coverage.

## D-009 — Keep platform validation claims separate

**Decision:** Report JVM unit tests, Android instrumented tests, Android device checks, iOS simulator/device checks and live Gmail scenarios separately. Mark unavailable evidence NOT RUN. Keep the native CI workflow and add Flutter checks without claiming native or Flutter feature parity from build success.

## D-010 — No credentials or primary-account testing

**Decision:** Never place mail credentials in source, shell arguments, logs, database, saved state or job payloads. Use a dedicated disposable test account only after the user supplies/authorizes it; no live account test is part of scaffolding.

## D-011 — Flutter build artifacts stay unsigned development outputs

**Decision:** Do not configure production signing for the Flutter host. The initial release bundle is an unsigned CI/local build artifact, not distributable to users. Add signing only after parity, data continuity and rollback decisions are complete.

## D-012 — Show each completed packet on a connected Pixel 9a

**Decision:** At a completed migration packet, check `adb devices`, build the separate `com.glassmail.dev.glassmail` debug APK, install/update that package, launch it, and capture a screenshot when the Pixel 9a is connected. Keep screenshots and debug APKs available as review artifacts; do not install over `com.glassmail.app`.

**Reason:** The owner asked to see each fully completed phase on the connected device. This provides an observable checkpoint while keeping the Kotlin app and its data untouched.

## D-013 — Build the Flutter SQLite engine with FTS4 enabled

**Decision:** Use the official SQLite 3.53.4 amalgamation in `flutter_app/third_party/sqlite/3.53.4`, compiled through the `sqlite3` build hook with `SQLITE_ENABLE_FTS4` and the package's default options. Keep the `sqlite3` Dart wrapper pinned by `pubspec.lock`; record the upstream source URL and SHA3-256 beside the vendored source.

**Reason:** The default bundled SQLite build used by the package enables FTS5 but does not enable FTS4. Room v10's exported schema requires FTS4 with Unicode61, and the Flutter schema test must exercise that exact engine feature. The custom build keeps FTS4 rather than substituting FTS5.

**Revisit when:** A deliberate, measured FTS migration is designed with a schema migration and rollback test. Re-audit SQLite source and build flags when updating the vendored version.

## D-014 — Keep credentials behind an app-owned interface

**Decision:** Add `core_security` with a `CredentialStore` boundary and pin `flutter_secure_storage` 11.2.0 for native storage. Use Android Keystore-wrapped AES-GCM with a stable storage namespace, disable reset-on-error so key failures do not silently erase credentials, and use backup-protected plugin migration. Android app backup stays disabled. On iOS, use device-only Keychain items, accessible while unlocked, with synchronizable disabled. Account removal deletes only that account's credential.

**Reason:** This matches the current local-only contract while avoiding secret data in Drift. Dart/plugin strings cannot be securely zeroed; the adapter reduces byte-buffer lifetime and clears mutable UTF-8 buffers, but does not claim Kotlin `CharArray`-equivalent zeroization. Native plugin reinstall/backup/key invalidation checks remain NOT RUN.

## D-015 — Do not use `enough_mail` as the only Gmail IMAP stack yet

**Decision:** Record the source-level `enough_mail` 2.1.7 evaluation in `TRANSPORT_CAPABILITIES.md`; do not add it as the app transport until fake transcripts prove Gmail `X-GM-*` fetch/store parsing and the required literal bounds. Build an isolated app-owned IMAP protocol adapter for those behaviors; reconsider isolated MIME/SMTP use after transcript, TLS and memory tests.

**Reason:** The public API exposes RFC-level UID, IDLE, quota, special-use LIST, APPEND and STARTTLS methods, but this does not establish Gmail extension behavior, parser safety or an 8 MiB bound. Live dedicated-account tests are a later gate.

## D-016 — Use app-owned bounded IMAP and SMTP wire sessions

**Decision:** `core_imap` owns the IMAP parser/client and SMTP STARTTLS session. IMAP uses Dart `SecureSocket` with default trust and hostname verification; SMTP upgrades a plain submission socket with `SecureSocket.secure` and passes the configured hostname. There is no certificate-bypass hook. Bound IMAP lines to 64 KiB and literals/messages to 8 MiB; cap SMTP payloads at 24 MiB. If SMTP loses the server's final DATA reply, report delivery as uncertain. The MIME decoder caps input size, headers, part count and multipart nesting.

**Reason:** Source inspection found that the pinned library did not establish Gmail `X-GM-*` response parsing, GlassMail's literal bounds or safe behavior on malformed responses. Local transcript and self-signed-certificate tests cover the app-owned implementation. Live Gmail and native platform behavior remain separate validation gates.

## D-017 — Keep batch sync and notifications in the Flutter host

**Decision:** Pin `workmanager` 0.10.10 for Android account-scoped batch sync and a single user-visible IDLE foreground worker, and `flutter_local_notifications` 22.3.1 for local mail alerts. Use one registered iOS BGTaskScheduler identifier for all accounts because iOS task identifiers are app-scoped. Request notification permission only from explicit UI. Keep Android periodic batch sync as fallback when the IDLE worker is stopped.

**Reason:** WorkManager provides durable constrained batch jobs and a user-visible long-running Android foreground worker. Android 15 limits the `dataSync` foreground-service type to six hours per 24 hours, so periodic batch sync remains necessary. iOS refresh timing is system-controlled and no exact send while iOS is suspended is claimed.

**Revisit when:** Device-validate Android IDLE/WorkManager recovery and iOS background registration; keep delayed sends foreground-only on iOS unless a separately authorized server architecture is chosen.

## D-018 — Keep outgoing attachments in app-private storage

**Decision:** Use Flutter's native `file_selector` picker, copy selected files into the app support directory, persist only those app-owned file URIs with drafts, cap draft attachments at 18 MiB total, and share downloaded incoming attachments only after a user tap through `share_plus`.

**Reason:** Provider/content URIs can expire after a process restart. Copying the selected bytes gives the durable send queue a stable local source and does not request broad storage access. The share sheet is an explicit user action.

**Validation:** The OS picker/share sheet and process-restart path remain device checks; local draft, repository cache and MIME send behavior have package/widget coverage.

## D-019 — Use Riverpod for app composition

**Decision:** Use Riverpod 3.4.3 as the app's provider boundary for repository composition. Keep mailbox data in Drift streams and use Flutter restoration only for selected route/account and dock state.

**Reason:** The first account-aware route can consume repository streams without copying durable mailbox state into view models.

## D-020 — Keep appearance and notification privacy preferences app-local

**Decision:** Persist theme mode, reduce-transparency, reduced-motion and notification-preview choices in a small app-support JSON file. Do not add presentation preferences to the mail database. Notification sender/subject details are hidden by default, including background-worker notifications.

**Reason:** These settings apply across accounts and do not describe mailbox content. An atomic local write keeps them separate from sync and account removal.

## D-021 — Keep Phase 2 workflows local and provider/platform guarantees explicit

**Decision:** Store templates, saved views, sender screening/profiles, snooze/follow-up metadata and scheduled-send status in app-private local state. The screener only hides messages in GlassMail; Trash view ignores local mute/snooze filters, and star actions target the mailbox currently displayed. Delete moves mail to Gmail Trash. Expose permanent purge only for a selected message after confirming the selected mailbox is server-advertised Trash and the server supports UIDPLUS; send only `UID EXPUNGE` for that UID. Provider-level Gmail blocking stays unavailable because the current app-password/IMAP flow has no Gmail OAuth settings-filter scope. The sender profile contact picker requests Contacts access only after an explicit user tap. Use generic reminder notifications and inexact idle-aware Android scheduling without exact-alarm permission. Android scheduled sends use network-constrained WorkManager; iOS sends stay foreground-only and interrupted sends restore as drafts. Encrypted backup uses PBKDF2-HMAC-SHA256 (600,000 iterations) and AES-256-GCM, restores only into an empty local database, and excludes credentials, pending provider actions, and scheduled-send work. Android and iOS home-screen widgets display only aggregate unread counts; Android source is build-verified, while iOS target/signing remain NOT RUN on this Linux host. Launcher shortcuts remain available.

**Reason:** Provider block creation needs a separate OAuth client, consent and Gmail settings scope; guessing it through IMAP would claim behavior the transport cannot provide. UIDPLUS scoped expunge avoids mailbox-wide destructive deletion. Backup encryption gives users portable local state without moving it to a service, while the empty-store restore and secret exclusions avoid overwriting live state or exporting credentials. The Linux host cannot validate an iOS extension.

**Intelligence decision:** Do not advertise on-device summaries or add a model dependency. Apple Foundation Models are limited to supported Apple Intelligence devices/regions; Google ML Kit GenAI uses Gemini Nano/AICore on a restricted device set. That does not establish availability across GlassMail's Android/iOS target matrix. Deterministic local smart cards are used until both platforms have an actually available, testable model and an approved content-processing design.

**Revisit when:** a dedicated Gmail test account and authorized OAuth client/scope design are available for provider filters; reminder scheduling can be validated on both OSes; macOS/Xcode and App Group provisioning are available for iOS widgets; or one privacy-reviewed on-device model is supported and testable across intended devices. Remote link previews remain off unless a privacy review approves the disclosure and network behavior.

## Open decisions

- Full cross-platform parity and the platform gaps listed in `PORT_MATRIX.md`: resolve through device evidence or owner acceptance before closing Phase 0.
- P0.1 fresh-store schema/model/query work is complete and visible in the Flutter host. The database package's schema, FTS4, DAO, rollback and file-reopen tests pass; Android debug APK is installed on the Pixel 9a. A true Android process-death test and iOS build remain NOT RUN.
- P0.2 implementation is complete: credential boundary, TLS IMAP and SMTP transports, bounded MIME decoder, fake transcripts, and local certificate rejection tests pass. Android secure-storage store/read/delete passed on the Pixel 9a. iOS execution, backup/key invalidation and dedicated Gmail are NOT RUN; no live credentials have been used.
- `enough_mail` remains unelected as the protocol transport. Revisit only if an isolated use passes the current no-content-logging and bounds requirements.
- Glass renderer and exact quality-tier mapping: decide after the representative Inbox proof and platform performance measurements.
- Existing drafts/data continuity: decide before any production app ID, signing or store cutover.
- Theme mode, reduce-transparency, reduced-motion and notification-preview preferences are now app-wide and persisted. A saved glass quality tier, haptics controls, and full appearance parity remain open.
- Android `compileSdk` is 36 because the secure-storage and integration-test plugins require it; keep `targetSdk` at 35 until a separate platform-support decision.
- Phase 2 source implementation is recorded in `PORT_MATRIX.md`; the arm64 debug build compiles the Android widget/contact/backup integrations. Trash-only single-UID purge and encrypted empty-store restore are implemented with focused tests. Provider-level Gmail block and remote link preview remain excluded by authentication/privacy boundaries; native model summaries remain excluded because availability is not established across targets. ADB has no connected device for the current build; iOS/Xcode, App Group provisioning, live Gmail, reminder delivery and physical accessibility behavior are NOT RUN.
