# GlassMail Privacy Policy

Last updated: 2026-09-26

GlassMail is an open-source email client. The project does not operate a GlassMail account service and the app contains no analytics, advertising SDK, or telemetry collection.

## Mail and account data

When you connect an account, GlassMail sends your address and app password to that provider over TLS to authenticate IMAP and SMTP. The app downloads mailbox metadata and message bodies from the provider and sends messages you compose through the provider's SMTP service. The provider's privacy policy governs that processing.

Mailbox data and drafts are stored in the app's private local database. Account credentials are stored using Android Keystore-backed encryption. Downloaded attachments are stored in the app's private files directory and can be evicted according to the cache settings. Removing an account deletes its local mailbox data and credential.

## Notifications and background sync

GlassMail may keep an IMAP IDLE connection while its foreground sync service is active. The service shows an ongoing system notification. If IDLE is unavailable or disconnected, WorkManager performs periodic synchronization when Android permits it. Notifications are generated on the device from newly synchronized mail.

## Tracking protection and unsubscribe

Remote images and external link navigation in message HTML are blocked. An explicit unsubscribe action may send an RFC 8058 one-click HTTPS POST to the list endpoint from your device, or open a mail app for a `mailto:` unsubscribe request.

## Your choices

You can remove an account from Settings, change local cache limits, or disable notification previews. Clearing app storage removes locally stored data. GlassMail cannot delete data already held by your email provider.

## Contact

For privacy questions, open an issue in the project's source repository. Do not include passwords, message contents, or other private account data in an issue.
