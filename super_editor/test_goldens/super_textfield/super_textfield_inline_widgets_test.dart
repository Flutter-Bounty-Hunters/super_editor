import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_test.dart';
import 'package:super_editor/super_text_field_test.dart';

Future<void> main() async {
  await loadAppFonts();

  group('SuperTextField > inline widgets >', () {
    group('single line >', () {
      testGoldensOnMac(
        'displays caret at upstream side of inline widget',
        (tester) async {
          await _pumpSingleLineTestApp(tester);

          // Place the caret at the upstream side of the inline widget.
          await tester.placeCaretInSuperTextField(7);

          await screenMatchesGolden(tester, 'super-text-field_inline_widgets_single_line_caret_upstream');
        },
        windowSize: goldenSizeSmall,
      );

      testGoldensOnMac(
        'displays caret at downstream side of inline widget',
        (tester) async {
          await _pumpSingleLineTestApp(tester);

          // Place the caret at the downstream side of the inline widget.
          await tester.placeCaretInSuperTextField(8);

          await screenMatchesGolden(tester, 'super-text-field_inline_widgets_single_line_caret_downstream');
        },
        windowSize: goldenSizeSmall,
      );

      testGoldensOnMac(
        'displays selection box when selecting inline widget',
        (tester) async {
          await _pumpSingleLineTestApp(
            tester,
            initialSelection: const TextSelection(baseOffset: 7, extentOffset: 8),
          );

          await screenMatchesGolden(tester, 'super-text-field_inline_widgets_single_line_selection_box_single');
        },
        windowSize: goldenSizeSmall,
      );

      testGoldensOnMac(
        'displays selection box upstream near inline widget',
        (tester) async {
          await _pumpSingleLineTestApp(
            tester,
            initialSelection: const TextSelection(baseOffset: 0, extentOffset: 7),
          );

          await screenMatchesGolden(tester, 'super-text-field_inline_widgets_single_line_selection_box_upstream');
        },
        windowSize: goldenSizeSmall,
      );

      testGoldensOnMac(
        'displays selection box downstream near inline widget',
        (tester) async {
          await _pumpSingleLineTestApp(
            tester,
            initialSelection: const TextSelection(baseOffset: 8, extentOffset: 14),
          );

          await screenMatchesGolden(tester, 'super-text-field_inline_widgets_single_line_selection_box_downstream');
        },
        windowSize: goldenSizeSmall,
      );

      testGoldensOnMac(
        'displays selection box when selecting over inline widget',
        (tester) async {
          await _pumpSingleLineTestApp(
            tester,
            initialSelection: const TextSelection(baseOffset: 0, extentOffset: 14),
          );

          await screenMatchesGolden(tester, 'super-text-field_inline_widgets_single_line_selection_box_over');
        },
        windowSize: goldenSizeSmall,
      );
    });

    group('multi line >', () {
      testGoldensOnMac(
        'displays caret at upstream side of inline widget',
        (tester) async {
          await _pumpMultiLineTestApp(tester);

          // Place the caret at the upstream side of the inline widget.
          await tester.placeCaretInSuperTextField(27);

          await screenMatchesGolden(tester, 'super-text-field_inline_widgets_multi_line_caret_upstream');
        },
        windowSize: goldenSizeSmall,
      );

      testGoldensOnMac(
        'displays caret at downstream side of inline widget',
        (tester) async {
          await _pumpMultiLineTestApp(tester);

          // Place the caret at the downstream side of the inline widget.
          await tester.placeCaretInSuperTextField(28);

          await screenMatchesGolden(tester, 'super-text-field_inline_widgets_multi_line_caret_downstream');
        },
        windowSize: goldenSizeSmall,
      );

      testGoldensOnMac(
        'displays selection box when selecting inline widget',
        (tester) async {
          await _pumpMultiLineTestApp(
            tester,
            initialSelection: const TextSelection(baseOffset: 27, extentOffset: 28),
          );

          await screenMatchesGolden(tester, 'super-text-field_inline_widgets_multi_line_selection_box_single');
        },
        windowSize: goldenSizeSmall,
      );

      testGoldensOnMac(
        'displays selection box upstream near inline widget',
        (tester) async {
          await _pumpMultiLineTestApp(
            tester,
            initialSelection: const TextSelection(baseOffset: 0, extentOffset: 27),
          );

          await screenMatchesGolden(tester, 'super-text-field_inline_widgets_multi_line_selection_box_upstream');
        },
        windowSize: goldenSizeSmall,
      );

      testGoldensOnMac(
        'displays selection box downstream near inline widget',
        (tester) async {
          await _pumpMultiLineTestApp(
            tester,
            initialSelection: const TextSelection(baseOffset: 28, extentOffset: 53),
          );

          await screenMatchesGolden(tester, 'super-text-field_inline_widgets_multi_line_selection_box_downstream');
        },
        windowSize: goldenSizeSmall,
      );

      testGoldensOnMac(
        'displays selection box when selecting over inline widget',
        (tester) async {
          await _pumpMultiLineTestApp(
            tester,
            initialSelection: const TextSelection(baseOffset: 0, extentOffset: 53),
          );

          await screenMatchesGolden(tester, 'super-text-field_inline_widgets_multi_line_selection_box_over');
        },
        windowSize: goldenSizeSmall,
      );
    });
  });
}

/// Pump a test app with a [SuperTextField] that renders a [ColoredBox] for each
/// [_NamedPlaceHolder] in the text, with an inline widget at offset 7.
Future<void> _pumpSingleLineTestApp(
  WidgetTester tester, {
  TextSelection? initialSelection,
}) async {
  final controller = AttributedTextEditingController(
    text: AttributedText(
      'before  after',
      null,
      {
        7: const _NamedPlaceHolder('1'),
      },
    ),
    selection: initialSelection,
  );
  await _pumpTestApp(tester, controller: controller);
}

/// Pump a test app with a [SuperTextField] that renders a [ColoredBox] for each
/// [_NamedPlaceHolder] in the text, with an inline widget at offset 27.
Future<void> _pumpMultiLineTestApp(
  WidgetTester tester, {
  TextSelection? initialSelection,
}) async {
  final controller = AttributedTextEditingController(
    text: AttributedText(
      'first line of text \nbefore  after\nthird line of text',
      null,
      {
        27: const _NamedPlaceHolder('1'),
      },
    ),
    selection: initialSelection,
  );
  await _pumpTestApp(tester, controller: controller);
}

/// Pump a test app with a [SuperTextField] that renders a [ColoredBox] for each
/// [_NamedPlaceHolder] in the text.
Future<void> _pumpTestApp(
  WidgetTester tester, {
  required AttributedTextEditingController controller,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: SizedBox(
              height: 300,
              child: SuperTextField(
                textController: controller,
                textStyleBuilder: (attributions) => const TextStyle(
                  // Use Roboto so that goldens show real text.
                  fontFamily: 'Roboto',
                  fontSize: 18,
                  color: Colors.black,
                ),
                inlineWidgetBuilders: const [
                  _boxPlaceHolderBuilder,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
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

// A placeholder that is identified by a name.
class _NamedPlaceHolder {
  const _NamedPlaceHolder(this.name);

  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _NamedPlaceHolder && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}
