# Flutter manual verification

This is the remaining device and account checklist for the parallel Flutter
application (`com.glassmail.dev.glassmail`). It does not replace the root
[`MANUAL_TEST.md`](../../MANUAL_TEST.md), which describes the Kotlin app.
Items below are procedures, not completed test results. Never use the owner's
primary account; use a dedicated disposable Gmail account with an app password.

## Android Pixel 9a

1. Install `flutter_app/build/app/outputs/flutter-apk/app-debug.apk`; confirm
   the launcher label is **GlassMail Dev** and the Kotlin `com.glassmail.app`
   installation and its data remain present.
2. Add a dedicated Gmail test account. Confirm setup never echoes the app
   password and removing that account deletes only its secure credential and
   local cache.
3. Sync mail, open a conversation, fetch a full body, mark it read, and star a
   message. Compare the state with Gmail after sync.
4. Open a message with HTML and remote-image fixtures. Confirm content is
   presented as inert text, tracker URLs do not load, and links do not navigate.
5. Download and share a message attachment. Confirm the operating-system share
   sheet opens only after the explicit tap and the attachment name/content are
   correct.
6. Compose a message with a local attachment, leave the screen, reopen it from
   Settings → Saved drafts, and confirm recipient, subject, body and attachment
   survive. Send only to the dedicated test account and verify Gmail delivery.
7. Exercise reply, reply-all, forward, local draft save, archive with undo,
   delete, remote Sent display, auth failure, offline search and mutation
   behavior; use a disposable mailbox for UIDVALIDITY/reset cases.
8. Grant notification permission from Settings and tap a new-mail notification.
   Confirm it opens the matching local message. Do not infer IDLE delivery timing
   from a single connected-device run.
9. Add two dedicated accounts and check unified inbox/search, account switching,
   per-account cache settings, storage-quota refresh and account removal.
10. Check persisted light/dark/system theme, reduced transparency, reduced motion,
    notification-preview privacy, high contrast, large system text, TalkBack
    labels/focus, IME overlap, portrait/landscape, safe areas and dock selection
    while Settings is selected.
11. Force-stop and relaunch during an unsent draft and a queued/uncertain send.
    Confirm drafts recover and uncertain delivery is never retried blindly.
12. Create and apply a template; save a custom search view and reopen it; add
    then unmute a local screener sender. Confirm the screener changes only this
    app's Inbox view and does not alter Gmail delivery.
13. Snooze a message and create a follow-up. Confirm it leaves Inbox while
    snoozed, returns when due, and has a generic local notification. Close the
    app across the due time, reboot the device, and confirm Android restores the
    pending notification. On iOS, terminate/relaunch across the due time and
    confirm the local notification. OS policies can delay or suppress delivery;
    no exact-time guarantee is claimed.
14. Use the storage advisor and local-cleanup action. Confirm they affect only
    cached bodies/attachments within configured limits. Create a `.gmbak` with
    a strong passphrase and verify the share sheet exports an encrypted file.
    On a clean development install, restore it and verify accounts appear in a
    credential-needed state, local attachments/workflows/preferences return,
    and passwords, queued server mutations and scheduled sends do not. Confirm
    a wrong passphrase fails without changing the empty store. Restore must
    refuse a non-empty database.
15. Edit a sender display profile and tap **Choose from Contacts**. Confirm
    contact access is requested only after that tap, the selected display name
    is stored locally, and denying permission leaves manual editing available.
    Do not import a contact's address unless the user explicitly chooses it.
16. Open the Trash filter on a dedicated test account. Confirm the remote
    Trash mailbox loads; permanently delete one selected test message only
    after the confirmation. Verify the message disappears from the test
    mailbox. Confirm the purge action is absent outside Trash and is unavailable
    if the server does not advertise Trash or UIDPLUS. Do not test against a
    personal or production mailbox. Mute or snooze a sender, then confirm those
    Inbox workflow filters do not hide the sender's messages in Trash. Star a
    Trash message and verify the pending action targets the selected Trash
    mailbox. Provider-level Gmail block is unavailable in the current
    app-password account flow.
17. Add the unread-count GlassMail widget from the Android launcher. Confirm it
    contains only an aggregate count and opens GlassMail Inbox when tapped.
    Verify count changes after sync/read actions. iOS WidgetKit checks require
    the signed App Group entitlement and must be run from the macOS/Xcode CI or
    a provisioned iPhone; no iOS result is implied by Android compilation.
18. Long-press the app icon and launch Compose, Inbox and Search shortcuts.
    Confirm Compose asks to add an account when none is configured. The launcher
    shortcut smoke is covered by a Flutter widget test; native device behavior
    is still a manual check.
19. Open a message containing ordinary HTTP(S) links, a `javascript:` URL,
    user-info URL and punctuation. Confirm only valid HTTP(S) links are shown,
    external launch waits for confirmation, and GlassMail fetches no preview,
    HTML, or remote resource.

## iOS

Run the macOS/Xcode CI job and repeat account, credential, notification,
attachment picker/share, large text, VoiceOver, rotation and draft-recovery
checks on a supported iPhone. Background refresh and suspended send timing are
best-effort on iOS and must not be compared to Android IDLE as an exact timing
promise. This Linux host cannot run this section.

## Live-account safety

Do not place credentials in commands, source, screenshots or logs. Sanitize
logs and screen captures before sharing them. SMTP uncertain-delivery scenarios
must be checked in Gmail Sent before any manual retry.
