# P0.2 transport evaluation and implementation

Checked 2026-09-27 against the current Flutter/Dart workspace and official
package/API documentation. The `enough_mail` review remains source-level; no
dedicated Gmail account was available and no live credentials were used. The
app-owned transport now has fake wire transcripts and local certificate tests.

## Candidate reviewed

`enough_mail` 2.1.7 is the latest stable version shown on pub.dev at review
time. It supports Android and iOS, documents low-level IMAP/SMTP clients,
MIME, IDLE, UIDPLUS, QUOTA, and is MPL-2.0. The API is usable for RFC-level
operations, but its public IMAP fetch parser does not currently provide the
Gmail extension data GlassMail needs. Do not add it as GlassMail's only IMAP
transport.

## Capability matrix

| Capability | Package/API evidence | Outcome |
| --- | --- | --- |
| Gmail `X-GM-MSGID`, `X-GM-THRID`, `X-GM-LABELS` fetch | `uidFetchMessagesByCriteria` accepts custom fetch text, but its built-in fetch result model does not expose these attributes. | **FAIL for current repository contract.** Needs an app-owned parser. |
| `+/-X-GM-LABELS.SILENT` store | `uidStore` exposes only the standard `FLAGS` add/remove/replace form. | **FAIL.** Exact Gmail extension commands need an app-owned adapter. |
| UID ranges and `UIDVALIDITY` | `MessageSequence`, UID fetch/store APIs and the `Mailbox` UID state fields cover the standard forms. | **API PRESENT; transcript test NOT RUN.** |
| `BODY.PEEK` and bounded literals | Custom fetch text is accepted, but the package parser is not a proof of `BODY.PEEK` handling or GlassMail's 8 MiB literal bound. | **NOT ACCEPTED** until a fake transcript verifies parser and memory limits. |
| LIST SPECIAL-USE | `listMailboxes` accepts extended selection/return options, and the package exposes special-use mailbox flags. | **API PRESENT; transcript test NOT RUN.** |
| `GETQUOTAROOT` / quota | `getQuotaRoot` and `getQuota` are public low-level API methods. | **API PRESENT; transcript test NOT RUN.** |
| IDLE lifecycle | `idleStart` / `idleDone` are public low-level methods. | **API PRESENT; reconnect/cancellation transcript NOT RUN.** |
| APPEND / APPENDUID | `appendMessage` returns a result that exposes APPENDUID response-code parsing. | **API PRESENT; transcript test NOT RUN.** |
| SMTP STARTTLS / certificate validation | `SmtpClient.startTls` exists; clients also expose an optional bad-certificate callback. GlassMail must leave that callback unset and test rejection of invalid certificates. | **API PRESENT; TLS transcript/test NOT RUN.** |
| MIME and attachment memory bounds | The API parses/renders MIME messages, but the reviewed docs do not establish an 8 MiB bounded streaming path equivalent to GlassMail's current contract. | **NOT ACCEPTED** pending stream and size-limit tests. |

The reviewed [`ImapClient` API](https://pub.dev/documentation/enough_mail/latest/enough_mail/ImapClient-class.html)
documents UID, IDLE, APPEND, quota and list operations; the package's
[`uidFetchMessagesByCriteria` API](https://pub.dev/documentation/enough_mail/latest/enough_mail/ImapClient/uidFetchMessagesByCriteria.html)
accepts caller-supplied fetch criteria. That signature alone does not prove
Gmail response parsing. The
[`SmtpClient` API](https://pub.dev/documentation/enough_mail/latest/enough_mail/SmtpClient-class.html)
documents STARTTLS, but certificate rejection still requires a test. The
package page records version 2.1.7 and its MPL-2.0 license:
[pub.dev package page](https://pub.dev/packages/enough_mail).

## Reversible direction

`core_imap` now owns the bounded response parser, TLS socket client, Gmail
extension commands, STARTTLS SMTP submission, uncertain-delivery signal and
MIME body decoder. The app-owned protocol tests cover arbitrary packet splits,
nested response values and response codes, malformed literals, the 8 MiB
literal and 64 KiB line boundaries, sparse UID sets, Gmail label fetch/store,
BODY.PEEK, LIST special-use flags, quota, IDLE mailbox changes/BYE/cancellation,
APPEND continuation/APPENDUID, SMTP authentication and dot-stuffing, DATA
rejection versus uncertain delivery, MIME transfer encodings and bounded
nesting/part counts. Local TLS tests use a test-only self-signed certificate
and verify that both IMAP TLS and SMTP STARTTLS reject it without a trust
override.

The client deliberately accepts raw RFC 822 bytes for SMTP; message composition,
attachment retention and end-to-end send queue integration belong to P0.3. The
MIME decoder returns text/HTML and an empty attachment-info list like the
current Kotlin decoder; attachments are fetched separately by validated part
ID and stay within the 8 MiB IMAP literal limit. No streaming attachment claim
is made.

**NOT RUN:** disposable Gmail authentication, Gmail server response variations,
IDLE reconnect against a real server, actual APPENDUID on Gmail, accepted SMTP
delivery, and iOS runtime behavior. Run those only with a dedicated disposable
account and supported platform/device. Do not use the owner's primary account.
