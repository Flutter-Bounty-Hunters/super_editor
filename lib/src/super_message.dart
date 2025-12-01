```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class SuperMessage extends StatefulWidget {
  final List<Widget> children;

  const SuperMessage({Key? key, required this.children}) : super(key: key);

  @override
  _SuperMessageState createState() => _SuperMessageState();
}

class _SuperMessageState extends State<SuperMessage> {
  late TextSelection _selection;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _selection = TextSelection.collapsed(offset: 0);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (TapDownDetails details) {
        final RenderEditable renderEditable = context.findRenderObject() as RenderEditable;
        setState(() {
          _selection = renderEditable.textEditingValue.selection;
        });
      },
      onPanUpdate: (DragUpdateDetails details) {
        final RenderEditable renderEditable = context.findRenderObject() as RenderEditable;
        setState(() {
          _selection = renderEditable.textEditingValue.selection.extendToOffset(details.globalPosition.dx.toInt());
        });
      },
      child: Focus(
        focusNode: _focusNode,
        child: SelectableText.rich(
          TextSpan(children: widget.children),
          selection: _selection,
          onSelectionChanged: (TextSelection selection, SelectionChangedCause cause) {
            setState(() {
              _selection = selection;
            });
          },
        ),
      ),
    );
  }
}
```
