# GlassMail functional status

## Implemented

- Room-backed conversation inbox, latest-expanded thread reader, Gmail categories with header-based fallback, and offline FTS search.
- Sandboxed HTML rendering with JavaScript, network loads, remote images, and link navigation disabled. Small or known tracking images are stripped and counted.
- Configurable short/long swipe actions, thread archive/mute/star/delete, and a snackbar that can undo queued archive mutations.
- SMTP submission with a configurable 5/10/15/30 second WorkManager undo window. A recovered send with uncertain delivery is surfaced for the user to check Sent before retrying.
- IMAP APPEND to the advertised Sent folder, local-to-Gmail Drafts synchronization using stable Message-ID replacement, and import of remote drafts.
- RFC 8058 HTTPS one-click unsubscribe and `mailto:` unsubscribe handoff.
- Per-account body/attachment cache caps, read-body eviction, attachment LRU eviction, IMAP GETQUOTAROOT, and Settings quota display.
- Up to two accounts, per-account switching, unified inbox/search, and independent periodic sync.
- IMAP IDLE foreground service with an ongoing notification, reconnect backoff, and 15-minute WorkManager fallback.
- Navigation, inbox search/category selection, reader expansion, and compose disclosure state use saveable UI state; drafts are persisted through Room autosave.
- Apache-2.0 license, privacy policy, F-Droid text metadata, R8 rules, and a build-only GitHub Actions workflow.

## Partial / release-owner follow-up

- Remote images remain blocked. A safe image proxy requires a trusted relay service; direct device fetch would expose the device IP to the image host, so the app does not offer a misleading “show images” action.
- Mailto unsubscribe opens a mail app for confirmation; only compliant HTTPS one-click endpoints can be submitted directly.
- A local draft can be imported without remote attachment parts when it was created on another client; local draft attachments remain supported.
- Release signing is configurable through environment variables but no signing key is present. Without those values the release APK is unsigned.
- F-Droid screenshots and final listing assets are intentionally pending real-device manual verification.

## Unverified

- Live Gmail Sent APPEND, remote Drafts replacement/import, one-click unsubscribe, quota responses, IDLE delivery timing, reconnect behavior, and two-account operation.
- Room migration 8→9→10 on an existing user database, large-mailbox cache eviction, and actual phone layout/rotation/process-death behavior.
- Macrobenchmark performance and F-Droid reproducible build review.

The requested phone-based manual run has not been performed. See `MANUAL_TEST.md` for the v1 verification sequence.
