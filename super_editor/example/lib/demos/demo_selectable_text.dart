import 'package:flutter/material.dart' hide SelectableText;
import 'package:super_editor/super_editor.dart';

/// Demo of a variety of `SelectableText` configurations.
class SelectableTextDemo extends StatefulWidget {
  @override
  _SelectableTextDemoState createState() => _SelectableTextDemoState();
}

class _SelectableTextDemoState extends State<SelectableTextDemo> {
  final _demoText1 = const TextSpan(
    text: 'Super Editor',
    style: TextStyle(
      color: Color(0xFF444444),
      fontSize: 18,
      height: 1.4,
      fontWeight: FontWeight.bold,
    ),
    children: [
      TextSpan(
        text: ' is an open source text editor for Flutter projects.',
        style: TextStyle(
          color: Color(0xFF444444),
          fontSize: 18,
          height: 1.4,
          fontWeight: FontWeight.normal,
        ),
      ),
    ],
  );
  final _debugTextKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: SizedBox(
          width: 600,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitle('SuperSelectableText Widget'),
                const SizedBox(height: 24),
                _buildDemo(
                  title: 'EMPTY TEXT WITH CARET',
                  demo: SuperSelectableText.plain(
                    text: '',
                    textSelection: const TextSelection.collapsed(offset: 0),
                    showCaret: true,
                    style: const TextStyle(
                      color: Color(0xFF444444),
                      fontSize: 18,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildDemo(
                  title: 'TEXT WITHOUT SELECTION OR CARET',
                  demo: SuperSelectableText(
                    textSpan: _demoText1,
                  ),
                ),
                const SizedBox(height: 24),
                _buildDemo(
                  title: 'TEXT WITH CARET + COLLAPSED SELECTION',
                  demo: SuperSelectableText(
                    textSpan: _demoText1,
                    textSelection: TextSelection.collapsed(offset: _demoText1.toPlainText().length),
                    showCaret: true,
                  ),
                ),
                const SizedBox(height: 24),
                _buildDemo(
                  title: 'TEXT WITH LEFT-TO-RIGHT SELECTION + CARET',
                  demo: SuperSelectableText(
                    textSpan: _demoText1,
                    textSelection: const TextSelection(baseOffset: 0, extentOffset: 12),
                    showCaret: true,
                  ),
                ),
                const SizedBox(height: 24),
                _buildDemo(
                  title: 'TEXT WITH RIGHT-TO-LEFT SELECTION + CARET',
                  demo: SuperSelectableText(
                    textSpan: _demoText1,
                    textSelection: TextSelection(
                        baseOffset: _demoText1.toPlainText().length,
                        extentOffset: _demoText1.toPlainText().length - 17),
                    showCaret: true,
                  ),
                ),
                const SizedBox(height: 24),
                _buildDemo(
                  title: 'TEXT WITH FULL SELECTION + CARET, CUSTOM COLORS, CARET SHAPE, DEBUG PAINT',
                  demo: DebugSelectableTextDecorator(
                    selectableTextKey: _debugTextKey,
                    textLength: _demoText1.toPlainText().length,
                    showDebugPaint: true,
                    child: SuperSelectableText(
                      key: _debugTextKey,
                      textSpan: _demoText1,
                      textSelection: TextSelection(baseOffset: 0, extentOffset: _demoText1.toPlainText().length),
                      textSelectionDecoration: const TextSelectionDecoration(
                        selectionColor: Colors.yellow,
                      ),
                      showCaret: true,
                      textCaretFactory: TextCaretFactory(
                        color: Colors.red,
                        width: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF444444),
        fontSize: 32,
      ),
    );
  }

  Widget _buildDemo({
    required String title,
    required Widget demo,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: const BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(4),
              )),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        demo,
      ],
    );
  }
}
