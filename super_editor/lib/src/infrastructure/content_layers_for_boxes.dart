import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/content_layers.dart';

/// A [ContentLayers] widget that's implemented to work with Render Boxes.
class BoxContentLayers extends ContentLayers {
  const BoxContentLayers({
    super.key,
    super.underlays = const [],
    required super.content,
    super.overlays = const [],
  });

  @override
  RenderBoxContentLayers createRenderObject(BuildContext context) {
    return RenderBoxContentLayers(context as ContentLayersElement);
  }
}

/// `RenderObject` for a [BoxContentLayers] widget.
///
/// Must be given an `Element` of type [ContentLayersElement].
class RenderBoxContentLayers extends RenderBox implements RenderContentLayers {
  RenderBoxContentLayers(this._element);

  @override
  void dispose() {
    _element = null;
    super.dispose();
  }

  ContentLayersElement? _element;

  final _underlays = <RenderBox>[];
  RenderBox? _content;
  final _overlays = <RenderBox>[];

  @override
  bool get contentNeedsLayout => _contentNeedsLayout;
  bool _contentNeedsLayout = true;

  /// Whether we are in the middle of a [performLayout] call.
  bool _runningLayout = false;

  @override
  void attach(PipelineOwner owner) {
    contentLayersLog.info("Attaching RenderBoxContentLayers to owner: $owner");
    super.attach(owner);

    visitChildren((child) {
      child.attach(owner);
    });
  }

  @override
  void detach() {
    contentLayersLog.info("detach()'ing RenderBoxContentLayers from pipeline");
    // IMPORTANT: we must detach ourselves before detaching our children.
    // This is a Flutter framework requirement.
    super.detach();

    // Detach our children.
    visitChildren((child) {
      child.detach();
    });
  }

  @override
  void markNeedsLayout() {
    super.markNeedsLayout();

    if (_runningLayout) {
      // We are already in a layout phase.
      //
      // When we call ContentLayerElement.buildLayers, markNeedsLayout is called again.
      // We don't want to mark the content as dirty, because otherwise the layers will
      // never build.
      return;
    }
    _contentNeedsLayout = true;
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    final childDiagnostics = <DiagnosticsNode>[];

    if (_content != null) {
      childDiagnostics.add(_content!.toDiagnosticsNode(name: "content"));
    }

    for (int i = 0; i < _underlays.length; i += 1) {
      childDiagnostics.add(_underlays[i].toDiagnosticsNode(name: "underlay-$i"));
    }
    for (int i = 0; i < _overlays.length; i += 1) {
      childDiagnostics.add(_overlays[i].toDiagnosticsNode(name: "overlay-#$i"));
    }

    return childDiagnostics;
  }

  @override
  void insertChild(RenderBox child, Object slot) {
    assert(isContentLayersSlot(slot));

    if (slot == contentSlot) {
      _content = child;
    } else if (slot is UnderlaySlot) {
      _underlays.insert(slot.index, child);
    } else if (slot is OverlaySlot) {
      _overlays.insert(slot.index, child);
    }

    adoptChild(child);
  }

  @override
  void moveChildLayer(RenderBox child, Object oldSlot, Object newSlot) {
    assert(oldSlot is UnderlaySlot || oldSlot is OverlaySlot);
    assert(newSlot is UnderlaySlot || newSlot is OverlaySlot);

    if (oldSlot is UnderlaySlot) {
      assert(_underlays.contains(child));
      _underlays.remove(child);
    } else if (oldSlot is OverlaySlot) {
      assert(_overlays.contains(child));
      _overlays.remove(child);
    }

    if (newSlot is UnderlaySlot) {
      _underlays.insert(newSlot.index, child);
    } else if (newSlot is OverlaySlot) {
      _overlays.insert(newSlot.index, child);
    }
  }

  @override
  void removeChild(RenderBox child, Object slot) {
    assert(isContentLayersSlot(slot));

    if (slot == contentSlot) {
      _content = null;
    } else if (slot is UnderlaySlot) {
      _underlays.remove(child);
    } else if (slot is OverlaySlot) {
      _overlays.remove(child);
    }

    dropChild(child);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (_content != null) {
      visitor(_content!);
    }

    for (final RenderBox child in _underlays) {
      visitor(child);
    }

    for (final RenderBox child in _overlays) {
      visitor(child);
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _content?.computeDryLayout(constraints) ?? Size.zero;

  @override
  double computeMinIntrinsicWidth(double height) => _content?.computeMinIntrinsicWidth(height) ?? 0.0;

  @override
  double computeMaxIntrinsicWidth(double height) => _content?.computeMaxIntrinsicWidth(height) ?? 0.0;

  @override
  double computeMinIntrinsicHeight(double width) => _content?.computeMinIntrinsicHeight(width) ?? 0.0;

  @override
  double computeMaxIntrinsicHeight(double width) => _content?.computeMaxIntrinsicHeight(width) ?? 0.0;

  @override
  void performLayout() {
    contentLayersLog.info("Laying out BoxContentLayers");
    if (_content == null) {
      size = Size.zero;
      _contentNeedsLayout = false;
      return;
    }

    _runningLayout = true;

    // Always layout the content first, so that layers can inspect the content layout.
    contentLayersLog.fine("Laying out content - $_content");
    _content!.layout(constraints, parentUsesSize: true);
    contentLayersLog.fine("Content after layout: $_content");

    // The size of the layers, and the our size, is exactly the same as the content.
    size = _content!.size;

    _contentNeedsLayout = false;

    // Build the underlay and overlays during the layout phase so that they can inspect an
    // up-to-date content layout.
    //
    // This behavior is what allows us to avoid layers that are always one frame behind the
    // content changes.
    contentLayersLog.fine("Building layers");
    invokeLayoutCallback((constraints) {
      // Usually, widgets are built during the build phase, but we're building the layers
      // during layout phase, so we need to explicitly tell Flutter to build all elements.
      _element!.owner!.buildScope(_element!, () {
        _element!.buildLayers();
      });
    });
    contentLayersLog.finer("Done building layers");

    contentLayersLog.fine("Laying out layers (${_underlays.length} underlays, ${_overlays.length} overlays)");
    // Layout the layers below and above the content.
    final layerConstraints = BoxConstraints.tight(size);

    for (final underlay in _underlays) {
      contentLayersLog.fine("Laying out underlay: $underlay");
      underlay.layout(layerConstraints);
    }
    for (final overlay in _overlays) {
      contentLayersLog.fine("Laying out overlay: $overlay");
      overlay.layout(layerConstraints);
    }

    _runningLayout = false;
    contentLayersLog.finer("Done laying out layers");
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_content == null) {
      return false;
    }

    // Run hit tests in reverse-paint order.
    bool didHit = false;

    // First, hit-test overlays.
    for (final overlay in _overlays) {
      didHit = overlay.hitTest(result, position: position);
      if (didHit) {
        return true;
      }
    }

    // Second, hit-test the content.
    didHit = _content!.hitTest(result, position: position);
    if (didHit) {
      return true;
    }

    // Third, hit-test the underlays.
    for (final underlay in _underlays) {
      didHit = underlay.hitTest(result, position: position) || didHit;
      if (didHit) {
        return true;
      }
    }

    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_content == null) {
      return;
    }

    // First, paint the underlays.
    for (final underlay in _underlays) {
      context.paintChild(underlay, offset);
    }

    // Second, paint the content.
    context.paintChild(_content!, offset);

    // Third, paint the overlays.
    for (final overlay in _overlays) {
      context.paintChild(overlay, offset);
    }
  }
}
