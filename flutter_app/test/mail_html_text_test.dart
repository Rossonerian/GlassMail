import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail/features/routes/mail_html_text.dart';

void main() {
  test(
    'keeps HTML mail inert while retaining readable text and alt labels',
    () {
      final text = mailHtmlToPlainText('''
      <div onclick="steal()"><b>Read this</b>
        <img src="https://tracker.invalid/pixel" onerror="steal()" alt="Offer">
        <a href="javascript:steal()">unsafe link</a>
      </div>
      <script>steal()</script><style>body{display:none}</style>
      <iframe src="https://tracker.invalid">remote</iframe>
      <form><input value="private"></form><!-- comment -->
    ''');

      expect(text, 'Read this\n[Offer]\nunsafe link');
      expect(text, isNot(contains('tracker.invalid')));
      expect(text, isNot(contains('steal')));
      expect(text, isNot(contains('<')));
    },
  );

  test('decodes safe text entities and treats malformed markup as text', () {
    expect(
      mailHtmlToPlainText('<p>A &amp; B &lt; C &#x1F680;</p><img src=x>'),
      'A & B < C 🚀\n[image omitted]',
    );
  });
}
