import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_text_layout/super_text_layout.dart';

void main() {
  group('SuperEditor > inline widgets >', () {
    testWidgetsOnAllPlatforms('does not invalidate layout when selection changes', (tester) async {
      await tester
          .createDocument()
          .withCustomContent(
            MutableDocument(
              nodes: [
                ParagraphNode(
                  id: '1',
                  text: AttributedText('Hello, world!', null, {
                    7: const _NamedPlaceHolder('world'),
                  }),
                ),
              ],
            ),
          )
          .useStylesheet(
            defaultStylesheet.copyWith(
              inlineWidgetBuilders: [_boxPlaceHolderBuilder],
            ),
          )
          .pump();

      // Place the caret at the beginning of the paragraph.
      await tester.placeCaretInParagraph('1', 0);

      // Keep track of whether of not the layout was invalidated.
      bool wasLayoutInvalidated = false;

      final renderParagraph = find
          .byType(LayoutAwareRichText) //
          .evaluate()
          .first
          .findRenderObject() as RenderLayoutAwareParagraph;
      renderParagraph.onMarkNeedsLayout = () {
        wasLayoutInvalidated = true;
      };

      // Place the selection somewhere else.
      await tester.placeCaretInParagraph('1', 2);

      // Ensure the layout was not invalidated.
      expect(wasLayoutInvalidated, isFalse);
    });
  });
}

/// A builder that renders a [ColoredBox] for a [_NamedPlaceHolder].
Widget? _boxPlaceHolderBuilder(BuildContext context, TextStyle textStyle, Object placeholder) {
  if (placeholder is! _NamedPlaceHolder) {
    return null;
  }

  return KeyedSubtree(
    key: ValueKey('placeholder-${placeholder.name}'),
    child: LineHeight(
      style: textStyle,
      child: const SizedBox(
        width: 24,
        child: ColoredBox(
          color: Colors.yellow,
        ),
      ),
    ),
  );
}

/// A placeholder that is identified by a name.
class _NamedPlaceHolder {
  const _NamedPlaceHolder(this.name);

  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _NamedPlaceHolder && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}
