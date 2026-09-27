import 'dart:io';
import 'dart:typed_data';

import 'package:glassmail_core_imap/glassmail_core_imap.dart';
import 'package:glassmail_core_model/glassmail_core_model.dart';
import 'package:glassmail_domain_mail/glassmail_domain_mail.dart';

import 'outgoing_mail_queue.dart';

abstract interface class MailDraftRemoteSource {
  Future<List<ImapRemoteDraft>> fetch({
    required String email,
    required Uint8List credentialUtf8,
  });

  Future<void> save({
    required String email,
    required Uint8List credentialUtf8,
    required MailDraft draft,
  });

  Future<void> delete({
    required String email,
    required Uint8List credentialUtf8,
    required String draftId,
    int? remoteUid,
    int? remoteUidValidity,
  });
}

typedef DraftImapConnector = Future<ImapClient> Function();
typedef DraftAttachmentStream =
    Stream<List<int>> Function(DraftAttachment attachment);

/// Uses stable Message-IDs and UIDPLUS-scoped deletion for remote Drafts.
final class ImapMailDraftRemoteSource implements MailDraftRemoteSource {
  ImapMailDraftRemoteSource({
    DraftImapConnector? connect,
    DraftAttachmentStream? openAttachment,
  }) : _connect = connect ?? ImapClient.connect,
       _openAttachment = openAttachment ?? _fileAttachmentStream;

  final DraftImapConnector _connect;
  final DraftAttachmentStream _openAttachment;

  @override
  Future<List<ImapRemoteDraft>> fetch({
    required String email,
    required Uint8List credentialUtf8,
  }) async {
    final client = await _connect();
    try {
      await client.login(email, credentialUtf8);
      return await client.fetchRemoteDrafts();
    } finally {
      await client.close();
    }
  }

  @override
  Future<void> save({
    required String email,
    required Uint8List credentialUtf8,
    required MailDraft draft,
  }) async {
    final client = await _connect();
    try {
      await client.login(email, credentialUtf8);
      final folders = await client.listMailboxes();
      final draftsMailbox = _findMailbox(folders);
      if (draftsMailbox == null) {
        throw const ImapProtocolException(
          'Server did not advertise a Drafts mailbox',
        );
      }
      await client.selectMailbox(draftsMailbox);
      final outgoing = OutgoingMail(
        operationId: draft.draftId,
        accountId: draft.accountId,
        from: email,
        to: draft.to,
        cc: draft.cc,
        bcc: draft.bcc,
        subject: draft.subject,
        body: draft.body,
        inReplyTo: draft.inReplyTo,
        references: draft.references,
        attachments: draft.attachments
            .map(
              (attachment) => OutgoingAttachment(
                uri: attachment.uri,
                fileName: attachment.fileName,
                mimeType: attachment.mimeType,
                sizeBytes: attachment.sizeBytes,
                openStream: () => _openAttachment(attachment),
              ),
            )
            .toList(growable: false),
      );
      final raw = await RawMailComposer.compose(
        outgoing,
        sentAtEpochMillis: draft.updatedAtEpochMillis,
        allowEmptyRecipients: true,
      );
      await client.replaceRemoteDraft(
        draft.draftId,
        raw,
        draftsMailbox: draftsMailbox,
      );
    } finally {
      await client.close();
    }
  }

  @override
  Future<void> delete({
    required String email,
    required Uint8List credentialUtf8,
    required String draftId,
    int? remoteUid,
    int? remoteUidValidity,
  }) async {
    final client = await _connect();
    try {
      await client.login(email, credentialUtf8);
      final mailbox = _findMailbox(await client.listMailboxes());
      if (mailbox == null) return;
      final selected = await client.selectMailbox(mailbox);
      if (remoteUid != null) {
        if (remoteUidValidity != null &&
            selected.uidValidity != remoteUidValidity) {
          return;
        }
        await client.deleteDraftUid(remoteUid);
      } else {
        await client.deleteDraft(draftId);
      }
    } finally {
      await client.close();
    }
  }
}

String? _findMailbox(List<ImapMailboxRecord> mailboxes) =>
    mailboxes
        .where(
          (mailbox) => mailbox.attributes.any(
            (attribute) => attribute.toLowerCase() == r'\drafts',
          ),
        )
        .map((mailbox) => mailbox.name)
        .firstOrNull ??
    const ['[Gmail]/Drafts', 'Drafts', 'Draft']
        .where(
          (name) => mailboxes.any(
            (mailbox) => mailbox.name.toLowerCase() == name.toLowerCase(),
          ),
        )
        .firstOrNull;

Stream<List<int>> _fileAttachmentStream(DraftAttachment attachment) {
  final uri = Uri.tryParse(attachment.uri);
  if (uri != null && uri.scheme.isNotEmpty && uri.scheme != 'file') {
    throw FormatException(
      'Draft attachment must be app-local or use a configured provider',
    );
  }
  return File(
    uri?.scheme == 'file' ? uri!.toFilePath() : attachment.uri,
  ).openRead();
}
