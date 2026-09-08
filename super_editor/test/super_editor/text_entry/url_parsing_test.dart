import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('UrlParser', () {
    group('tryToParseUrl', () {
      test('parses full https URL', () {
        final uri = UrlParser.tryToParseUrl('https://example.com/test');
        expect(uri, Uri.parse('https://example.com/test'));
      });

      test('parses full http URL', () {
        final uri = UrlParser.tryToParseUrl('http://example.com');
        expect(uri, Uri.parse('http://example.com'));
      });

      test('prepends https to URL without scheme', () {
        final uri = UrlParser.tryToParseUrl('www.google.com');
        expect(uri, Uri.parse('https://www.google.com'));
      });

      test('parses email address to mailto scheme', () {
        final uri = UrlParser.tryToParseUrl('user@example.com');
        expect(uri, Uri.parse('mailto:user@example.com'));
      });

      test('parses non-http scheme with ://', () {
        final uri = UrlParser.tryToParseUrl('git://github.com/repo');
        expect(uri, Uri.parse('git://github.com/repo'));
      });

      test('returns null for non-URL word', () {
        expect(UrlParser.tryToParseUrl('hello'), isNull);
        expect(UrlParser.tryToParseUrl('just-a-word'), isNull);
      });
    });

    group('findUrlSpansInText', () {
      test('finds single URL in text', () {
        final spans = UrlParser.findUrlSpansInText('Visit https://flutter.dev today');
        final linkSpans = spans.getAttributionSpansByFilter((attr) => attr is LinkAttribution);
        expect(linkSpans.length, 1);
        expect(linkSpans.first.start, 6);
        expect(linkSpans.first.end, 24);
        expect((linkSpans.first.attribution as LinkAttribution).url, Uri.parse('https://flutter.dev'));
      });

      test('finds multiple URLs and emails in text', () {
        final spans = UrlParser.findUrlSpansInText('Check google.com or email help@test.org now');
        final linkSpans = spans.getAttributionSpansByFilter((attr) => attr is LinkAttribution).toList();
        expect(linkSpans.length, 2);
        expect((linkSpans[0].attribution as LinkAttribution).url, Uri.parse('https://google.com'));
        expect((linkSpans[1].attribution as LinkAttribution).url, Uri.parse('mailto:help@test.org'));
      });

      test('returns empty spans for text with no URLs', () {
        final spans = UrlParser.findUrlSpansInText('There are no links in this sentence.');
        final linkSpans = spans.getAttributionSpansByFilter((attr) => attr is LinkAttribution);
        expect(linkSpans, isEmpty);
      });
    });
  });
}
