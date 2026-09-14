# Security

The Google App Password is encrypted with AES-GCM using a non-exportable Android Keystore key. The encrypted blob is the only credential material written to private app preferences. The database, Worker `Data`, `SavedStateHandle`, pending-mutation payloads, repository UI models, and logs do not contain the App Password. WorkManager receives only an account identifier and a non-secret source label.

The setup password field is transient Compose input only: it is not saveable, not placed in the ViewModel state, and is cleared on submission. A `CharArray` is passed once to `CredentialStore` and cleared after encryption/decryption use. JVM strings cannot be zeroed reliably; no credential string is retained beyond the immediate IMAP command construction.

IMAP uses the platform TLS socket factory, default certificate trust validation, hostname verification, connect/read timeouts, input-size limits, and no command logging. Application backup is disabled to avoid backing up the encrypted credential blob without its Keystore key.

Never use a personal primary Gmail account for development. Use a dedicated test account with 2-Step Verification and an App Password, then revoke the App Password when testing ends. Live authentication and socket-cycle validation have not yet been performed for this repository.
## Outgoing mail

SMTP send uses Gmail STARTTLS on `smtp.gmail.com:587`, platform TLS trust/hostname verification, and 30-second connection/read/write timeouts. The SMTP adapter receives credentials through an injected callback backed by `AndroidKeystoreCredentialStore`; it never logs or stores the password. Compose input is validated before transport and message size/attachment support is intentionally not advertised until streaming attachments are implemented.

Authentication, transport, protocol, and invalid-message outcomes are mapped to typed send results. A server-accepted/network-dropped SMTP operation cannot be made fully idempotent by the protocol; the client retains the failed draft and does not automatically retry.
