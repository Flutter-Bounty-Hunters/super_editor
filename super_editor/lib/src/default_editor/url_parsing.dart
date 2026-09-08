import 'package:attributed_text/attributed_text.dart';
import 'package:linkify/linkify.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/text.dart';

/// Centralized utility for parsing and extracting URLs and email addresses
/// within text for Super Editor linkification (used by typing reactions and paste).
class UrlParser {
  const UrlParser._();

  /// Options used when parsing URLs with [linkify].
  static const linkifyOptions = LinkifyOptions(
    humanize: false,
    looseUrl: true,
  );

  /// Linkifiers used for email and URL extraction.
  static const emailLinkifiers = [EmailLinkifier()];
  static const urlLinkifiers = [UrlLinkifier()];

  /// Parses the [word] as [Uri], prepending "https://" if it doesn't start
  /// with "http://" or "https://", or returning a `mailto:` [Uri] if it's an email address.
  ///
  /// Returns `null` if the given [word] does not contain a single valid URL or email.
  static Uri? tryToParseUrl(String word) {
    // First, try extracting emails.
    final extractedEmails = linkify(
      word,
      options: linkifyOptions,
      linkifiers: emailLinkifiers,
    );
    final int emailCount = extractedEmails.fold(0, (value, element) => element is EmailElement ? value + 1 : value);
    if (emailCount == 1) {
      // Found exactly one email. Create and return a link attribution.
      final emailElement = extractedEmails.first as EmailElement;
      return Uri(
        scheme: "mailto",
        path: emailElement.emailAddress,
      );
    }

    // Second, try extracting HTTP URLs.
    final extractedLinks = linkify(
      word,
      options: linkifyOptions,
      linkifiers: urlLinkifiers,
    );
    final int linkCount = extractedLinks.fold(0, (value, element) => element is UrlElement ? value + 1 : value);
    if (linkCount == 1) {
      // Found exactly 1 URL. Create and return an attribution.
      try {
        // Try to parse the word as a link.
        final uri = Uri.parse(word);
        if (uri.hasScheme) {
          // URL is fully specified. Return it.
          return uri;
        }

        // The URL is missing a scheme. Add "https:" and re-parse.
        return Uri.parse("https://$word");
      } catch (exception) {
        // Something went wrong parsing the link. Fizzle.
        return null;
      }
    }

    // Third, try directly parsing a non-http URL.
    if (word.contains("://")) {
      return Uri.tryParse(word);
    }

    // Didn't find a URL in the given text.
    return null;
  }

  /// Finds all URLs and email addresses in the given [text] and returns an [AttributedSpans],
  /// which contains [LinkAttribution]s that span each URL.
  static AttributedSpans findUrlSpansInText(String text) {
    final AttributedSpans linkAttributionSpans = AttributedSpans();

    final wordBoundaries = text.calculateAllWordBoundaries();

    for (final wordBoundary in wordBoundaries) {
      final word = wordBoundary.textInside(text);

      // The word is a single URL. Linkify it.
      final uri = tryToParseUrl(word);
      if (uri == null) {
        // This word isn't a URI.
        continue;
      }

      final startOffset = wordBoundary.start;
      // -1 because TextPosition's offset indexes the character after the
      // selection, not the final character in the selection.
      final endOffset = wordBoundary.end - 1;

      // Add link attribution.
      linkAttributionSpans.addAttribution(
        newAttribution: LinkAttribution.fromUri(uri),
        start: startOffset,
        end: endOffset,
      );
    }

    return linkAttributionSpans;
  }
}
