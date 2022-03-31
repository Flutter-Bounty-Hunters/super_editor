import 'package:characters/characters.dart';

// Match any characters we want skip over while moving by word. This will match
// Unicode graphemes with a General_Category value in:
// - Punctuation (P), such as ".", "-", and "。"
// - Separator (Z), such as " " (space), and "　" (ideographic space)
// See http://www.unicode.org/reports/tr44/#GC_Values_Table for details on
// on the Unicode General_Category property.
final _separatorRegex = RegExp(r'^[\p{Z}\p{P}]$', unicode: true);

extension CharacterMovement on String {
  /// Returns the code point index of the character that sits
  /// at the next start of word upstream from the given
  /// [textOffset] code point index.
  ///
  /// Examples:
  ///   |word up -> `null`
  ///   wo|rd up -> `0`
  ///   word| up -> `0`
  ///   word |up -> `0`
  ///   word up| -> `5`
  int? moveOffsetUpstreamByWord(int textOffset) {
    if (textOffset < 0 || textOffset > length) {
      throw Exception("Index '$textOffset' is out of string range. Length: $length");
    }

    if (textOffset == 0) {
      return null;
    }

    // Create a character range, initially with zero length
    // Note that the getter for this object is confusingly named: it is an iterator but includes lots of functionality
    // beyond that interface, most importantly for us a range over this string that can be manipulated in terms of
    // characters
    final range = characters.iterator;
    // Expand the range so it reaches from the start of the string to the initial text offset. The text offset is passed
    // to us in terms of bytes but the iterator deals in grapheme clusters, so we need to manually count the length of
    // each cluster as until we reach the desired offset
    var remainingOffset = textOffset;
    range.expandWhile((char) {
      remainingOffset -= char.length;
      return remainingOffset >= 0;
    });
    // Shrink the range from the end as long it does not end in a word. This accounts for cases where the text offset
    // starts in between words. After this expansion we know the range ends on a word character
    range.dropBackWhile((char) => _separatorRegex.hasMatch(char));
    // Shrink the range from the back until it reaches a non-word character. After this expansion we know that the range
    // ends on the first character of a word, which is the next word upstream from the initial text offset
    range.dropBackWhile((char) => !_separatorRegex.hasMatch(char));
    // The range now reaches from the start of the string to our new text offset. Calculate that offset using the
    // range's string length and return it
    final current = range.current;
    return current.length;
  }

  /// Returns the code point index of the character that sits
  /// [characterCount] upstream from the given [textOffset] code
  /// point index.
  ///
  /// Examples:
  ///   |a💙c -> `null`
  ///   a|💙c -> `0`
  ///   a💙|c -> `1`
  ///   a💙c| -> `3` (notice that we moved 2 units due to emoji length)
  int? moveOffsetUpstreamByCharacter(int textOffset, {int characterCount = 1}) {
    if (textOffset == 0) {
      return null;
    }

    return _moveOffsetByCharacter(textOffset, characterCount, TextAffinity.upstream);
  }

  /// Returns the code point index of the character that sits
  /// after the end of the next word downstream from the given
  /// [textOffset] code point index.
  ///
  /// Examples:
  ///   |word up -> `4`
  ///   wo|rd up -> `4`
  ///   word| up -> `7`
  ///   word |up -> `7`
  ///   word up| -> `null`
  int? moveOffsetDownstreamByWord(int textOffset) {
    if (textOffset < 0 || textOffset > length) {
      throw Exception("Index '$textOffset' is out of string range. Length: $length");
    }

    if (textOffset == length) {
      return null;
    }

    // Create a character range, initially with zero length
    // Note that the getter for this object is confusingly named: it is an iterator but includes lots of functionality
    // beyond that interface, most importantly for us a range over this string that can be manipulated in terms of
    // characters
    final range = characters.iterator;
    // Expand the range so it reaches from the start of the string to the initial text offset. The text offset is passed
    // to us in terms of bytes but the iterator deals in grapheme clusters, so we need to manually count the length of
    // each cluster as until we reach the desired offset
    var remainingOffset = textOffset;
    range.expandWhile((char) {
      remainingOffset -= char.length;
      return remainingOffset >= 0;
    });
    // Expand the range forward as long it does not end in a word. This accounts for cases where the text offset starts
    // in between words. After this expansion we know the range ends on a word character
    range.expandWhile((char) => _separatorRegex.hasMatch(char));
    // Expand the range forward until it reaches a non-word character. After this expansion we know that the range ends
    // on the last character of a word, which is the next word downstream from the initial text offset
    range.expandWhile((char) => !_separatorRegex.hasMatch(char));
    // The range now reaches from the start of the string to our new text offset. Calculate that offset using the
    // range's string length and return it
    return range.current.length;
  }

  /// Returns the code point index of the character that sits
  /// [characterCount] downstream from given [textOffset] code
  /// point index.
  ///
  /// Examples:
  ///   |a💙c -> `1`
  ///   a|💙c -> `3` (notice that we moved 2 units due to emoji length)
  ///   a💙|c -> `4`
  ///   a💙c| -> `null`
  int? moveOffsetDownstreamByCharacter(int textOffset, {int characterCount = 1}) {
    if (textOffset == length) {
      return null;
    }

    return _moveOffsetByCharacter(textOffset, characterCount, TextAffinity.downstream);
  }

  int? _moveOffsetByCharacter(int textOffset, int characterCount, TextAffinity affinity) {
    if (textOffset < 0 || textOffset > length) {
      throw Exception("Index '$textOffset' is out of string range. Length: $length");
    }

    // Create a character range, initially with zero length
    // Note that the getter for this object is confusingly named: it is an iterator but includes lots of functionality
    // beyond that interface, most importantly for us a range over this string that can be manipulated in terms of
    // characters
    final range = characters.iterator;
    var remainingOffset = textOffset;
    // Expand the range so it reaches from the start of the string to the initial text offset. The text offset is passed
    // to us in terms of bytes but the iterator deals in grapheme clusters, so we need to manually count the length of
    // each cluster as until we reach the desired offset
    range.expandWhile((char) {
      remainingOffset -= char.length;
      return remainingOffset >= 0;
    });
    // Verify that the move is possible with the requested character count
    if (affinity == TextAffinity.downstream && range.stringAfterLength < characterCount) {
      return null;
    }
    if (affinity == TextAffinity.upstream && range.current.length < characterCount) {
      return null;
    }
    // Expand or contract the range by the requested number of characters
    if (affinity == TextAffinity.downstream) {
      range.expandNext(characterCount);
    } else {
      range.dropLast(characterCount);
    }
    // The range now reaches from the start of the string to our new text offset. Calculate that offset using the
    // range's string length and return it
    return range.current.length;
  }
}
