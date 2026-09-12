# Security

The Google App Password is encrypted with AES-GCM using a non-exportable Android Keystore key. The encrypted blob is the only credential material written to private app preferences. The database, Worker `Data`, `SavedStateHandle`, pending-mutation payloads, repository UI models, and logs do not contain the App Password. WorkManager receives only an account identifier and a non-secret source label.

The setup password field is transient Compose input only: it is not saveable, not placed in the ViewModel state, and is cleared on submission. A `CharArray` is passed once to `CredentialStore` and cleared after encryption/decryption use. JVM strings cannot be zeroed reliably; no credential string is retained beyond the immediate IMAP command construction.

IMAP uses the platform TLS socket factory, default certificate trust validation, hostname verification, connect/read timeouts, input-size limits, and no command logging. Application backup is disabled to avoid backing up the encrypted credential blob without its Keystore key.

Never use a personal primary Gmail account for development. Use a dedicated test account with 2-Step Verification and an App Password, then revoke the App Password when testing ends. Live authentication and socket-cycle validation have not yet been performed for this repository.
