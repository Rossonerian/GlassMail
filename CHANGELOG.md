# Changelog

All notable changes to GlassMail are documented here, following Keep a Changelog.

## [Unreleased]

## [1.0.0] - 2026-10-05

### Added

- Room-backed threaded inbox, Gmail categories with header-based fallback, offline full-text search, and an expandable thread reader.
- Restricted HTML rendering with JavaScript, network loads, remote images, and link navigation disabled; tracking-image removal and counts.
- Configurable short/long swipe actions, thread archive/mute/star/delete, and undo for queued archive mutations.
- SMTP submission with configurable 5/10/15/30-second undo-send windows and recovery warnings for uncertain delivery.
- Sent-folder IMAP APPEND, Gmail Drafts synchronization using stable Message-ID replacement, and remote draft import.
- RFC 8058 HTTPS one-click unsubscribe and mailto unsubscribe handoff.
- Per-account body/attachment cache caps and eviction, IMAP quota queries, and Settings quota display.
- Up to two accounts, account switching, unified inbox/search, and independent periodic sync.
- Foreground IMAP IDLE with an ongoing notification, reconnect backoff, and 15-minute WorkManager fallback.
- Saveable navigation, search/category, reader, and compose disclosure state, plus Room draft autosave.
- Apache-2.0 license, privacy policy, F-Droid text metadata, R8 rules, and build-only native CI.

### Known limitations

- Remote images remain blocked. A safe image proxy requires a trusted relay service.
- Mailto unsubscribe opens a mail app for confirmation; only compliant HTTPS one-click endpoints can be submitted directly.
- A local draft can be imported without remote attachment parts when it was created on another client; local draft attachments remain supported.
- F-Droid screenshots and final listing assets are intentionally pending real-device manual verification.
- Live Gmail Sent APPEND, remote Drafts replacement/import, one-click unsubscribe, quota responses, IDLE delivery timing, reconnect behavior, and two-account operation are unverified.
- Room migration 8→9→10 on an existing user database, large-mailbox cache eviction, and actual phone layout/rotation/process-death behavior are unverified.
- Macrobenchmark performance and F-Droid reproducible build review are unverified.
