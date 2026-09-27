import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail_domain_mail/glassmail_domain_mail.dart';

void main() {
  test('draft statuses retain the exact Room string encoding', () {
    expect(DraftStatus.draft.storageValue, 'DRAFT');
    expect(DraftStatus.uncertain.storageValue, 'UNCERTAIN');
    expect(DraftStatus.fromStorageValue('SENDING'), DraftStatus.sending);
    expect(
      () => DraftStatus.fromStorageValue('unknown'),
      throwsFormatException,
    );
  });

  test('operation results keep failures as values like Kotlin Result', () {
    final MailOperationResult<int> result = MailOperationFailure(
      UnsupportedError('unavailable'),
    );

    expect(result, isA<MailOperationFailure<int>>());
    expect(
        (result as MailOperationFailure<int>).error, isA<UnsupportedError>());
  });

  test('normalizes address separators and deduplicates case-insensitively', () {
    expect(
      normalizeAddresses(
          'Alice@example.com; bob@example.com\nALICE@example.com'),
      ['Alice@example.com', 'bob@example.com'],
    );
  });

  test('validates addresses and sanitizes attachment names', () {
    expect(validateAddresses(['alice@example.com']), isTrue);
    expect(validateAddresses(['not-an-address']), isFalse);
    expect(sanitizeAttachmentName(r'C:\temp\résumé.pdf'), 'r_sum_.pdf');
    expect(sanitizeAttachmentName('///'), 'attachment');
  });

  test('reply helpers exclude the owner and preserve first recipient spelling',
      () {
    final message = ReceivedMailHeaders(
      replyTo: ['Reply@example.com'],
      to: ['me@example.com', 'reply@EXAMPLE.com'],
      cc: ['other@example.com'],
      messageId: '<latest>',
      references: ['<first>'],
    );

    expect(
      replyAllRecipients(message, 'ME@example.com'),
      ['Reply@example.com', 'other@example.com'],
    );
    expect(referencesForReply(message.messageId, message.references),
        ['<first>', '<latest>']);
    expect(replySubject(' Re: hello'), ' Re: hello');
    expect(forwardSubject('hello'), 'Fwd: hello');
  });

  test('message size accounts for UTF-8 body and base64 attachment expansion',
      () {
    final mail = OutgoingMail(
      operationId: 'op',
      accountId: 'account',
      from: 'me@example.com',
      to: const ['you@example.com'],
      subject: 'Subject',
      body: 'é',
      attachments: [
        OutgoingAttachment(
          fileName: 'photo.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 3,
          openStream: () => const Stream.empty(),
        ),
      ],
    );

    expect(estimatedOutgoingMessageBytes(mail), 2 + 4 + 1024 + 16384);
  });

  test('domain data values compare by content with immutable collection fields',
      () {
    final draft = MailDraft(
      draftId: 'draft',
      accountId: 'account',
      to: ['one@example.test', 'two@example.test'],
      references: ['<first>', '<second>'],
      attachments: const [
        DraftAttachment(
          uri: 'file:///tmp/report.pdf',
          fileName: 'report.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 42,
        ),
      ],
    );
    final equivalentDraft = MailDraft(
      draftId: 'draft',
      accountId: 'account',
      to: ['one@example.test', 'two@example.test'],
      references: ['<first>', '<second>'],
      attachments: const [
        DraftAttachment(
          uri: 'file:///tmp/report.pdf',
          fileName: 'report.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 42,
        ),
      ],
    );

    expect(draft, equivalentDraft);
    expect(draft.hashCode, equivalentDraft.hashCode);
    expect(
      const MarkReadMutation(
        accountId: 'account',
        messageId: 'message',
        read: true,
      ),
      const MarkReadMutation(
        accountId: 'account',
        messageId: 'message',
        read: true,
      ),
    );
    expect(
      () => draft.to.add('later@example.test'),
      throwsUnsupportedError,
    );
  });
}
