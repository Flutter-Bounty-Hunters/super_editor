import 'package:attributed_text/attributed_text.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/infrastructure/serialization/quill/content/formatting.dart';

/// An inline Quill Delta format that applies a color to text.
class ColorDeltaFormat extends FilterByNameInlineDeltaFormat {
  static const _color = "color";

  const ColorDeltaFormat() : super(_color);

  @override
  Attribution? createAttribution(String value) {
    if (!value.startsWith("#")) {
      throw Exception("Unknown color value: '$value' - expected it to start with '#'");
    }
    if (value.length != 7 && value.length != 9) {
      throw Exception("Unknown color value: '$value' - expected either #rrggbb or #aarrggbb");
    }

    late final int colorValue;
    if (value.length == 7) {
      // Value is "#rrggbb" - we need to add full alpha to avoid leading zeros.
      colorValue = int.parse(value.substring(1), radix: 16) + 0xFF000000;
    } else {
      // Value is #aarrggbb.
      colorValue = int.parse(value.substring(1), radix: 16);
    }
    final color = Color(colorValue);

    return ColorAttribution(color);
  }
}

/// An inline Quill Delta format that applies a background color (highlight) to text.
class BackgroundColorDeltaFormat extends FilterByNameInlineDeltaFormat {
  static const _background = "background";

  const BackgroundColorDeltaFormat() : super(_background);

  @override
  Attribution? createAttribution(String value) {
    if (!value.startsWith("#")) {
      throw Exception("Unknown color value: '$value' - expected it to start with '#'");
    }
    if (value.length != 7 && value.length != 9) {
      throw Exception("Unknown color value: '$value' (length ${value.length}) - expected either #rrggbb or #aarrggbb");
    }

    late final int colorValue;
    if (value.length == 7) {
      // Value is "#rrggbb" - we need to add full alpha to avoid leading zeros.
      colorValue = int.parse(value.substring(1), radix: 16) + 0xFF000000;
    } else {
      // Value is #aarrggbb.
      colorValue = int.parse(value.substring(1), radix: 16);
    }
    final color = Color(colorValue);

    return BackgroundColorAttribution(color);
  }
}

/// An inline Quill Delta format that makes text superscript or subscript.
class ScriptDeltaFormat extends FilterByNameInlineDeltaFormat {
  static const _script = "script";
  static const _superscript = "super";
  static const _subscript = "sub";

  const ScriptDeltaFormat() : super(_script);

  @override
  Attribution? createAttribution(String value) {
    if (value == _superscript) {
      return superscriptAttribution;
    }
    if (value == _subscript) {
      return subscriptAttribution;
    }

    // TODO: log that we received an unknown script value.
    return null;
  }
}

/// An inline Quill Delta format that applies a font family to text.
class FontFamilyDeltaFormat extends FilterByNameInlineDeltaFormat {
  static const _font = "font";

  const FontFamilyDeltaFormat() : super(_font);

  @override
  Attribution? createAttribution(Object value) {
    return FontFamilyAttribution(value as String);
  }
}

/// An inline Quill Delta format that applies a named or numerical size to text.
class SizeDeltaFormat extends FilterByNameInlineDeltaFormat {
  static const _size = "size";

  const SizeDeltaFormat() : super(_size);

  @override
  Attribution? createAttribution(Object value) {
    if (value is num) {
      final size = value.toDouble();
      return FontSizeAttribution(size);
    }

    if (value is String) {
      return NamedFontSizeAttribution(value);
    }

    // TODO: log unknown size value.
    return null;
  }
}

/// An inline Quill Delta format that applies a link to text.
class LinkDeltaFormat extends FilterByNameInlineDeltaFormat {
  static const _link = "link";

  const LinkDeltaFormat() : super(_link);

  @override
  Attribution? createAttribution(String value) {
    return LinkAttribution(value);
  }
}

/// An [InlineDeltaFormat] that filters out any operation that doesn't have
/// an attribute with the given [name].
abstract class FilterByNameInlineDeltaFormat implements InlineDeltaFormat {
  const FilterByNameInlineDeltaFormat(this.name);

  final String name;

  @override
  Attribution? from(Operation operation) {
    if (!operation.hasAttribute(name)) {
      return null;
    }

    return createAttribution(operation.attributes![name]);
  }

  @protected
  Attribution? createAttribution(String value);
}

/// An [InlineDeltaFormat] that applies a given [attribution] to text whenever
/// that text insertion includes an attribute with the given [name].
///
/// This class removes verbosity when writing [InlineDeltaFormat]s where the
/// existence of an attribute name means that a known attribution should be
/// applied.
class NamedInlineDeltaFormat implements InlineDeltaFormat {
  const NamedInlineDeltaFormat(this.name, this.attribution);

  final String name;
  final Attribution attribution;

  @override
  Attribution? from(Operation operation) {
    if (!operation.hasAttribute(name)) {
      return null;
    }

    return attribution;
  }
}

/// Given a Quill Delta text insertion operation, inspects the delta's attributes and then
/// returns an attribution that should be applied to the [AttributedText] created by the
/// insertion operation.
///
/// For example, a bold inline delta format might inspect an operation for an attribute
/// called "bold". Upon finding an attribute called "bold", that inline delta format
/// would return a [boldAttribution], which the parser would then apply to the Super Editor
/// document.
abstract interface class InlineDeltaFormat {
  Attribution? from(Operation operation);
}

abstract interface class InlineEmbedFormat {
  bool insert(Editor editor, DocumentComposer composer, Map<String, dynamic> embed);
}

class InlineEmbed {
  const InlineEmbed(this.text, this.data);

  final AttributedText text;
  final Object? data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InlineEmbed && runtimeType == other.runtimeType && text == other.text && data == other.data;

  @override
  int get hashCode => text.hashCode ^ data.hashCode;
}
