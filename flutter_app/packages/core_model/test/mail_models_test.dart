import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail_core_model/glassmail_core_model.dart';

void main() {
  const inbox = ImapSelectedMailbox(
    uidValidity: 7,
    uidNext: 401,
    messageCount: 250,
  );

  test('empty sparse UID page continues through the requested boundary', () {
    final page = GmailInboxSnapshot(
      capabilities: const {},
      mailboxes: const [],
      inbox: inbox,
      messages: const [],
      requestedThroughUid: 200,
    );

    expect(page.hasMoreUids, isTrue);
  });

  test(
    'last page stops when the requested boundary reaches UIDNEXT minus one',
    () {
      final page = GmailInboxSnapshot(
        capabilities: const {},
        mailboxes: const [],
        inbox: inbox,
        messages: const [],
        requestedThroughUid: 400,
      );

      expect(page.hasMoreUids, isFalse);
    },
  );

  test('Gmail capability and collection values preserve source semantics', () {
    final originalCapabilities = {'X-GM-EXT-1'};
    final originalFlags = {'\\Seen'};
    final metadata = ImapMessageMetadata(
      uid: 17,
      flags: originalFlags,
      gmailMessageId: '21',
      gmailThreadId: '22',
      labels: const {'INBOX'},
      subject: 'Subject',
      sender: 'sender@example.com',
      sentAtEpochMillis: null,
      sizeBytes: null,
    );
    final page = GmailInboxSnapshot(
      capabilities: originalCapabilities,
      mailboxes: const [],
      inbox: inbox,
      messages: [metadata],
    );
    originalCapabilities.clear();
    originalFlags.clear();

    expect(page.supportsGmailExtensions, isTrue);
    expect(page.messages.single.flags, contains('\\Seen'));
    expect(() => page.messages.add(metadata), throwsUnsupportedError);
    expect(
      () => page.messages.single.labels.add('STARRED'),
      throwsUnsupportedError,
    );
  });

  test(
    'Kotlin data class values compare by content, including collections',
    () {
      final first = GmailInboxSnapshot(
        capabilities: {'IMAP4rev1', 'X-GM-EXT-1'},
        mailboxes: [
          ImapMailbox(name: 'INBOX', attributes: {'\\HasNoChildren'}),
        ],
        inbox: inbox,
        messages: [
          ImapMessageMetadata(
            uid: 17,
            flags: {'\\Seen', '\\Flagged'},
            gmailMessageId: '21',
            gmailThreadId: '22',
            labels: {'INBOX', 'STARRED'},
            subject: 'Subject',
            sender: 'sender@example.com',
            sentAtEpochMillis: null,
            sizeBytes: null,
          ),
        ],
        requestedThroughUid: 400,
      );
      final sameValue = GmailInboxSnapshot(
        capabilities: {'X-GM-EXT-1', 'IMAP4rev1'},
        mailboxes: [
          ImapMailbox(name: 'INBOX', attributes: {'\\HasNoChildren'}),
        ],
        inbox: const ImapSelectedMailbox(
          uidValidity: 7,
          uidNext: 401,
          messageCount: 250,
        ),
        messages: [
          ImapMessageMetadata(
            uid: 17,
            flags: {'\\Flagged', '\\Seen'},
            gmailMessageId: '21',
            gmailThreadId: '22',
            labels: {'STARRED', 'INBOX'},
            subject: 'Subject',
            sender: 'sender@example.com',
            sentAtEpochMillis: null,
            sizeBytes: null,
          ),
        ],
        requestedThroughUid: 400,
      );

      expect(first, sameValue);
      expect(first.hashCode, sameValue.hashCode);
      expect(
        const MailSyncSuccess(messageCount: 1, gmailExtensionsEnabled: true),
        const MailSyncSuccess(messageCount: 1, gmailExtensionsEnabled: true),
      );
      expect(
        const MailSyncFailure(MailSyncError.network),
        const MailSyncFailure(MailSyncError.network),
      );
    },
  );
}
