import 'package:attributed_text/attributed_text.dart';
import 'package:collection/collection.dart';
import 'package:super_editor/src/default_editor/attributions.dart';

extension AttributedTextToHtml on AttributedText {
  String toHtml({
    int? start,
    int? end,
    InlineHtmlSerializerChain serializers = defaultInlineHtmlSerializers,
  }) {
    // Pull out the part of this text that we want to encode.
    final substring = start != null || end != null ? copyText(start ?? 0, end ?? length) : this;

    // Write this attributed text to HTML.
    final htmlBuffer = StringBuffer();
    int textIndex = 0;

    substring.visitAttributions(
      CallbackAttributionVisitor(
        visitAttributions: (
          AttributedText fullText,
          int index,
          Set<Attribution> startingAttributions,
          Set<Attribution> endingAttributions,
        ) {
          // Encode the content between the last set of tags and just before
          // this offset.
          if (index > 0) {
            htmlBuffer.write(fullText.substring(textIndex, index));
          }

          // Encode opening tags before the character at this index.
          if (startingAttributions.isNotEmpty) {
            final tags = startingAttributions
                .map((a) => _encodeTag(serializers, a, TagType.opening))
                .nonNulls
                .sorted(_sortOpeningTags);
            if (tags.isNotEmpty) {
              htmlBuffer.write(tags.join(""));
            }
          }

          // Write the character at this index.
          htmlBuffer.write(fullText[index]);

          // Encode closing tags after the character at this index.
          if (endingAttributions.isNotEmpty) {
            final tags = endingAttributions
                .map((a) => _encodeTag(serializers, a, TagType.closing))
                .nonNulls
                .sorted(_sortClosingTags);
            if (tags.isNotEmpty) {
              htmlBuffer.write(tags.join(""));
            }
          }

          textIndex = index + 1;
        },
        onVisitEnd: () {
          // TODO: consider changing this behavior in attributed_text because
          //       it's unexpected that we wouldn't be passed all the
          //       attributions that end at the end of the string. In other
          //       words, `visitAttributions` stops one segment too soon.
          // Append the final string segment.
          if (textIndex < substring.length) {
            htmlBuffer.write(substring.substring(textIndex));

            // Encode final ending tags.
            final endingAttributions = getAllAttributionsAt(length - 1);
            if (endingAttributions.isNotEmpty) {
              final tags = endingAttributions
                  .map((a) => _encodeTag(serializers, a, TagType.closing))
                  .nonNulls
                  .sorted(_sortClosingTags);
              if (tags.isNotEmpty) {
                htmlBuffer.write(tags.join(""));
              }
            }
          }
        },
      ),
    );

    return htmlBuffer.toString();
  }

  String? _encodeTag(InlineHtmlSerializerChain serializers, Attribution attribution, TagType tagType) {
    for (final serializer in serializers) {
      final tag = serializer(attribution, tagType);
      if (tag != null) {
        return tag;
      }
    }

    return null;
  }

  int _sortOpeningTags(String tagA, String tagB) {
    // Sort opening tags alphabetically, to give us a consistent ordering.
    return tagA.compareTo(tagB);
  }

  int _sortClosingTags(String tagA, String tagB) {
    // Sort in the opposite order as starting tags, so tags end from inside out.
    return -_sortOpeningTags(tagA, tagB);
  }
}

enum TagType {
  opening,
  closing;
}

const defaultInlineHtmlSerializers = [
  defaultBoldHtmlSerializer,
  defaultItalicsHtmlSerializer,
  defaultUnderlineHtmlSerializer,
  defaultStrikethroughHtmlSerializer,
  defaultCodeHtmlSerializer,
  defaultLinkHtmlSerializer,
];

/// A priority-order list of [InlineHtmlSerializer]s, which can be used to serialize
/// text segments from a document to inline HTML.
typedef InlineHtmlSerializerChain = List<InlineHtmlSerializer>;

/// A function that (maybe) serializes the given [attribution] to an HTML tag.
typedef InlineHtmlSerializer = String? Function(Attribution attribution, TagType tagType);

String? defaultBoldHtmlSerializer(Attribution attribution, TagType tagType) {
  if (attribution != boldAttribution) {
    return null;
  }

  return switch (tagType) {
    TagType.opening => '<strong>',
    TagType.closing => '</strong>',
  };
}

String? defaultItalicsHtmlSerializer(Attribution attribution, TagType tagType) {
  if (attribution != italicsAttribution) {
    return null;
  }

  return switch (tagType) {
    TagType.opening => '<i>',
    TagType.closing => '</i>',
  };
}

String? defaultUnderlineHtmlSerializer(Attribution attribution, TagType tagType) {
  if (attribution != underlineAttribution) {
    return null;
  }

  return switch (tagType) {
    TagType.opening => '<u>',
    TagType.closing => '</u>',
  };
}

String? defaultStrikethroughHtmlSerializer(Attribution attribution, TagType tagType) {
  if (attribution != strikethroughAttribution) {
    return null;
  }

  return switch (tagType) {
    TagType.opening => '<s>',
    TagType.closing => '</s>',
  };
}

String? defaultCodeHtmlSerializer(Attribution attribution, TagType tagType) {
  if (attribution != codeAttribution) {
    return null;
  }

  return switch (tagType) {
    TagType.opening => '<code>',
    TagType.closing => '</code>',
  };
}

String? defaultLinkHtmlSerializer(Attribution attribution, TagType tagType) {
  if (attribution is! LinkAttribution) {
    return null;
  }

  return switch (tagType) {
    TagType.opening => '<a href="${attribution.plainTextUri}">',
    TagType.closing => '</a>',
  };
}
