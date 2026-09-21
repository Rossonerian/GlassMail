# Architecture

```text
Compose UI (Modular Screens & Floating Glass Chrome)
       │
       ▼
AppViewModel (StateFlow & Coroutine Orchestration)
       │
       ├─────────────────────────────────┐
       ▼                                 ▼
MailRepository / DraftRepository    AccountSyncScheduler (WorkManager)
       │                                 │
       ├──────────────┬──────────────────┤
       ▼              ▼                  ▼
GlassMailDatabase  GmailImapClient   GmailSmtpMailSender
   (Room DB)       (IMAP Transport)  (SMTP Transport)
```

## Boundaries & Principles
- **Room as Source of Truth**: UI consumes immutable `StateFlow` streams from `AppViewModel`, backed directly by Room queries. Compose never creates a secondary in-memory list or shadows durable state.
- **Repository Isolation**: `:app` interacts with domain interfaces (`MailRepository`, `DraftRepository`, `MailSender`, `CredentialStore`), not internal DAOs or IMAP sessions.
- **Security**: Keystore credentials are provided to `withCredential` lambdas only at the transport boundary and wiped immediately via `finally { credential.fill('\u0000') }`.
- **Flat Content Surfaces vs Floating Liquid Glass**:
  - Message rows (`MailRow.kt`), reading canvas (`ReaderScreen.kt`), and compose canvas (`ComposeScreen.kt`) are strictly flat, high-contrast surfaces to guarantee maximum legibility and zero distortion.
  - Liquid glass is confined exclusively to floating chrome (`MorphingDock`, `GlassMailTopCapsule`, floating reader action bar, `CommandPalette`, dialogs).

## Modular Screen De-monolithization
Previously all screens were in an 840-line monolithic `GlassMailApp.kt`. The UI layer is now cleanly decomposed into modular, focused components:
- `AppViewModel.kt`: Central state holder and repository orchestrator for inbox, search, reader, drafts, and appearance preferences.
- `MailRow.kt`: High-contrast, flat email list row with unread indicator, snippet preview, star toggle, and overflow actions.
- `InboxScreen.kt`: Filterable mail list with top capsule, search/settings actions, and backdrop freeze signaling.
- `ReaderScreen.kt`: Distraction-free email reading view with attachment chips and floating glass action bar.
- `SearchScreen.kt`: Instant local cache search with history suggestion chips and full query filtering.
- `SettingsScreen.kt`: Appearance controls (Theme, Glass Quality, Accessibility), diagnostic mailbox seed/clear, and credentials update.
- `GlassLabScreen.kt`: Developer playground for interactive live AGSL shader tuning, preset switching, and frame timing diagnostics.
- `GlassMailChrome.kt`: Shared top capsules, dock coordination, and draft helpers.

## Module Structure
- `:app`: Application entry point, modular screens, Navigation graph, and application graph wiring.
- `:designsystem`: Theme tokens (`GlassSpacing`, `GlassRadius`, `GlassIconSize`, `GlassElevation`, `GlassMotion`), `AmbientCanvas`, and `MorphingDock`.
- `:designsystem:glass`: Zero-copy live `GlassProvider`, `GlassSurface`, 14-parameter `GlassMaterial`, AGSL shader, and quality tiers.
- `:domain:mail`: Core entities (`MailMessage`, `MailDraft`, `MailAccount`, `MailMutation`) and repository contracts.
- `:data:mail`: `ImapMailRepository` implementation coordinating Room persistence and remote IMAP sync.
- `:core:database`: Room database, entities, DAOs, and database migrations.
- `:core:imap`: `GmailImapClient` and `GmailSmtpMailSender` network transports.
- `:core:security`: Android Keystore credential storage.
- `:core:model`: Shared data transfer models.
- `:sync`: WorkManager scheduled background synchronization.
- `:benchmark`: Macrobenchmark start-up and scroll performance tests.
