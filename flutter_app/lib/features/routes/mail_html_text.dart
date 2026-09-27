/// Converts untrusted HTML mail into plain text for Flutter's text widgets.
///
/// This is deliberately not an HTML renderer: it never loads images, follows
/// links, or creates platform views. Mail content remains inert selectable
/// text, including content with malformed markup.
String mailHtmlToPlainText(String html) {
  var text = html
      .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
      .replaceAll(
        RegExp(
          r'<(script|style|iframe|object|embed|svg|math|form)\b[^>]*>[\s\S]*?</\1\s*>',
          caseSensitive: false,
        ),
        '',
      );
  text = text.replaceAllMapped(
    RegExp(r'<img\b([^>]*)>', caseSensitive: false),
    (match) {
      final alt = RegExp(
        r'''\balt\s*=\s*(["'])(.*?)\1''',
        caseSensitive: false,
      ).firstMatch(match.group(1) ?? '')?.group(2)?.trim();
      return alt == null || alt.isEmpty ? '[image omitted]' : '[$alt]';
    },
  );
  text = text
      .replaceAllMapped(
        RegExp(r'<\s*(br|hr)\b[^>]*>', caseSensitive: false),
        (_) => '\n',
      )
      .replaceAllMapped(
        RegExp(
          r'</\s*(p|div|li|tr|h[1-6]|blockquote|pre)\s*>',
          caseSensitive: false,
        ),
        (_) => '\n',
      )
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAllMapped(
        RegExp(r'&#(x[0-9a-f]+|[0-9]+);', caseSensitive: false),
        (match) {
          final entity = match.group(1)!;
          final point = entity.startsWith('x') || entity.startsWith('X')
              ? int.tryParse(entity.substring(1), radix: 16)
              : int.tryParse(entity);
          if (point == null || point <= 0 || point > 0x10ffff) return '';
          return String.fromCharCode(point);
        },
      );
  return text
      .replaceAll(RegExp(r'[ \t\x0B\f]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
