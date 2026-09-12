# Synchronization

Each account has one in-process `Mutex`; concurrent refresh calls for that account join the same sequential critical section. WorkManager also uses a unique one-time work name per account, with `KEEP`, network connectivity constraints, and exponential backoff. Existing accounts are queued once at application startup; a successful account setup schedules 24-hour periodic work. Account removal cancels both work names before removing local account data and its encrypted credential. Periodic work is opportunistic rather than exact.

The current IMAP metadata pass is:

```text
CAPABILITY → LOGIN → CAPABILITY → LIST → SELECT INBOX → UID FETCH checkpoint+1:checkpoint+200
```

Fetched metadata is parsed before Room is opened. It is then committed in batches of at most 200 messages. Every batch transaction writes canonical messages, mailbox UID membership, flags and labels, and the mailbox checkpoint together. A failed transaction cannot advance the checkpoint. The checkpoint records mailbox, account, `UIDVALIDITY`, highest known UID, generation, and final-success time.

On a `UIDVALIDITY` change, GlassMail clears only that mailbox's UID memberships, increments the checkpoint generation, then re-adds memberships from the new response. Canonical messages are retained; Gmail messages re-use their `X-GM-MSGID` canonical identity when present. Old UIDs are never reused as identities.

Local actions are applied in one Room transaction with a `PendingMutationEntity`. States are `PENDING`, `IN_FLIGHT`, and `FAILED_PERMANENT`; successful server acknowledgement deletes the record. Transient transport errors return the mutation to `PENDING` with an incremented retry count. Authentication and protocol/server-rejection errors become permanent failures. Cancellation is rethrown.

During metadata reconciliation, active local mutation intent overlays stale server flags: pending read/unread controls `\\Seen`, star/unstar controls `\\Flagged`, and delete controls `\\Deleted`. Archive removes local mailbox membership immediately and stores its target UID in the mutation record so it can be sent later. Pending labels remain in `message_labels` until their IMAP acknowledgement.

Normal synchronization fetches envelope/header/flag/label/thread metadata only. Full bodies and attachment bytes are not fetched. `MessageEntity` and `AttachmentEntity` expose `NOT_FETCHED`, `FETCHING`, `AVAILABLE`, and `FAILED` download states for future on-demand retrieval.

The first page starts at UID 1 and later pages start after the committed checkpoint, so mailbox history is progressively enumerated without retaining a full mailbox in memory. The checkpoint advances to the requested UID boundary, not merely the greatest returned UID: IMAP UID spaces are sparse, so an empty range still makes durable progress. A committed page with more UIDs is continued with WorkManager backoff; once history reaches `UIDNEXT`, subsequent runs are incremental. Live end-to-end Gmail validation remains unverified.
