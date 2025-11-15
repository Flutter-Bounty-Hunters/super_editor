import 'package:attributed_text/attributed_text.dart';

/// An [Attribution] that sets the font size of text based on a given size
/// name, e.g., "huge", "large", "normal", "small".
class NamedFontSizeAttribution implements Attribution {
  const NamedFontSizeAttribution(this.fontSizeName);

  /// The ID that determines whether two overlapping attributions conflict
  /// with each other (aren't allowed to overlap).
  ///
  /// In the case of [NamedFontSizeAttribution], this ID needs to match
  /// [FontSizeAttribution] because they both impact font size in the final
  /// display.
  @override
  String get id => "font_size";

  /// The name of the font size to use for the text attributed with this
  /// attribution, e.g., "huge", "large", "normal", "small".
  final String fontSizeName;

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NamedFontSizeAttribution && runtimeType == other.runtimeType && fontSizeName == other.fontSizeName;

  @override
  int get hashCode => fontSizeName.hashCode;
}
