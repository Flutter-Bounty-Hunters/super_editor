import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/flutter/render_box.dart';

/// Extension that accesses a [Finder]'s results assuming it finds a [RenderBox].
extension RenderBoxAccess on Finder {
  /// Assumes this [Finder] found a single [RenderBox] and returns that [RenderBox]'s
  /// bounds in the global coordinate space.
  Rect get globalRect => asRenderBox.globalRect;

  /// Assumes this [Finder] found a single [RenderBox] and returns that [RenderBox].
  RenderBox get asRenderBox => evaluate().first.renderObject as RenderBox;
}
