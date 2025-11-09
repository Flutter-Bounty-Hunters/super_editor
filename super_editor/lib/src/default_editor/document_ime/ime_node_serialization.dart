import 'package:super_editor/src/core/document.dart';

abstract class ImeNodeSerialization {
  String toImeText();
  NodePosition nodePositionFromImeOffset(int imeOffset);
  int imeOffsetFromNodePosition(covariant NodePosition position);
}
