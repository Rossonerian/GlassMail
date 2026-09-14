# GlassMail functional status

## Supported

- Local Room-backed Inbox, Reader, Search, read/unread, star, archive, Gmail Trash mapping, and label mutations.
- Gmail IMAP over TLS with canonical Gmail message/thread IDs, checkpointed 200-message pages, UIDVALIDITY handling, WorkManager sync, and transactional pending mutations.
- Compose and Gmail SMTP submission over STARTTLS with address validation, bounded timeouts, Keystore-only credential access, stable operation Message-ID, duplicate-tap protection, and typed failures.
- Local durable drafts with debounced autosave and recovery by command palette.
- Reply, Reply All, and Forward draft creation with subject prefixes and In-Reply-To/References headers where cached metadata permits.
- Account removal cancellation, credential deletion, Room cascade cleanup, and Settings credential re-entry.
- Minimal sync-driven notifications with durable per-account initial-sync suppression, canonical-message deduplication, account grouping, privacy-safe previews, runtime permission gating, and existing Reader intent routing.

## Partial

- Send confirmation is local-only after SMTP accepts the message; Sent-mail IMAP append/synchronization is not implemented.
- If SMTP accepts a message and the client loses connectivity before receiving confirmation, the draft is retained as failed and the user must decide whether to retry; duplicate-free server-side idempotency cannot be guaranteed by SMTP.
- Reply All can only use recipient metadata currently present in `MailMessage`; received To/Cc/Reply-To headers are not yet persisted.
- Attachments support SAF selection, durable draft URI metadata, multipart SMTP submission, private storage, FileProvider opening, and on-demand IMAP body-part retrieval. IMAP payload handling is bounded to the existing 8 MiB literal safety limit; larger files require a future streaming protocol refinement.
- Labels have a Reader selector for add/remove through real pending mutations. A dedicated mailbox Move UI is not implemented.
- Delete removes Inbox membership locally and reconciles to Gmail's `\\Trash` system label; permanent deletion is not exposed.
- Notification delivery has not been exercised against a live newly-arriving Gmail message on the available device; WorkManager/IMAP polling is not push or real-time.
- Live Gmail send, reply, attachment, and reconciliation tests are UNVERIFIED because no dedicated test account was supplied.

## Unverified

- Real Gmail SMTP acceptance/delivery, Sent-folder reflection, Reply All correctness against live headers, remote draft synchronization, attachment transfer, notification delivery against live mail, and offline reconnect reconciliation on a live account.
- Connected Room/WorkManager tests and macrobenchmarks on the available device.

## Deferred

- Remote Gmail draft synchronization, rich attachment preview, configurable swipe actions, snooze, Gatekeeper, bundles, multi-account, collaboration, and all P2 AI features.
