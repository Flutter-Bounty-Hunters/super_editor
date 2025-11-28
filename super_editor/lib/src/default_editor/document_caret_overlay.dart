import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/infrastructure/documents/document_layers.dart';
import 'package:super_editor/src/infrastructure/flutter/empty_box.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// Document overlay that paints a caret with the given [caretStyle].
class CaretDocumentOverlay extends DocumentLayoutLayerStatefulWidget {
  const CaretDocumentOverlay({
    Key? key,
    required this.composer,
    required this.documentLayoutResolver,
    this.caretStyle = const CaretStyle(
      width: 2,
      color: Colors.black,
    ),
    this.platformOverride,
    this.displayOnAllPlatforms = false,
    this.displayCaretWithExpandedSelection = true,
    this.blinkTimingMode = BlinkTimingMode.ticker,
  }) : super(key: key);

  /// The editor's [DocumentComposer], which reports the current selection.
  final DocumentComposer composer;

  /// Delegate that returns a reference to the editor's [DocumentLayout], so
  /// that the current selection can be mapped to an (x,y) offset and a height.
  final DocumentLayout Function() documentLayoutResolver;

  /// The visual style of the caret that this overlay paints.
  final CaretStyle caretStyle;

  /// The platform to use to determine caret behavior, defaults to [defaultTargetPlatform].
  final TargetPlatform? platformOverride;

  /// Whether to display a caret on all platforms, including mobile.
  ///
  /// By default, the caret is only displayed on desktop.
  final bool displayOnAllPlatforms;

  /// Whether to display the caret when the selection is expanded.
  ///
  /// Defaults to `true`.
  final bool displayCaretWithExpandedSelection;

  /// The timing mechanism used to blink, e.g., `Ticker` or `Timer`.
  ///
  /// `Timer`s are not expected to work in tests.
  final BlinkTimingMode blinkTimingMode;

  @override
  DocumentLayoutLayerState<CaretDocumentOverlay, Rect?> createState() => CaretDocumentOverlayState();
}

@visibleForTesting
class CaretDocumentOverlayState extends DocumentLayoutLayerState<CaretDocumentOverlay, Rect?>
    with SingleTickerProviderStateMixin {
  late final BlinkController _blinkController;

  @override
  void initState() {
    super.initState();

    switch (widget.blinkTimingMode) {
      case BlinkTimingMode.ticker:
        _blinkController = BlinkController(tickerProvider: this);
      case BlinkTimingMode.timer:
        _blinkController = BlinkController.withTimer();
    }

    widget.composer.selectionNotifier.addListener(_onSelectionChange);

    _startOrStopBlinking();
  }

  @override
  void didUpdateWidget(CaretDocumentOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.composer != oldWidget.composer) {
      oldWidget.composer.selectionNotifier.removeListener(_onSelectionChange);
      widget.composer.selectionNotifier.addListener(_onSelectionChange);

      _startOrStopBlinking();
    }
  }

  @override
  void dispose() {
    widget.composer.selectionNotifier.removeListener(_onSelectionChange);

    _blinkController.dispose();

    super.dispose();
  }

  @visibleForTesting
  bool get isCaretVisible => _blinkController.opacity == 1.0 && !_shouldHideCaretForExpandedSelection;

  /// Returns `true` if the selection is currently expanded, and we want to hide the caret when
  /// the selection is expanded.
  ///
  /// Returns `false` if the selection is collapsed or `null`, or if we want to show the caret
  /// when the selection is expanded.
  bool get _shouldHideCaretForExpandedSelection {
    if (widget.composer.selection?.isCollapsed != false) {
      return false;
    }
    final extent = widget.composer.selection!.extent;
    // it would hide caret either if it was configured globally, or if current CompositeNode at extent position decides to
    return !widget.displayCaretWithExpandedSelection ||
        !widget.documentLayoutResolver().displayCaretForExpandedSelectionWithExtent(extent);
  }

  @visibleForTesting
  Duration get caretFlashPeriod => _blinkController.flashPeriod;

  void _onSelectionChange() {
    _updateCaretFlash();

    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      // The Flutter pipeline isn't running. Schedule a re-build and re-position the caret.
      setState(() {
        // The caret is positioned in the build() call.
      });
    }
  }

  void _startOrStopBlinking() {
    // TODO: allow a configurable policy as to whether to show the caret at all when the selection is expanded: https://github.com/superlistapp/super_editor/issues/234
    final wantsToBlink = widget.composer.selection != null;
    if (wantsToBlink && _blinkController.isBlinking) {
      return;
    }
    if (!wantsToBlink && !_blinkController.isBlinking) {
      return;
    }

    wantsToBlink //
        ? _blinkController.startBlinking()
        : _blinkController.stopBlinking();
  }

  void _updateCaretFlash() {
    // TODO: allow a configurable policy as to whether to show the caret at all when the selection is expanded: https://github.com/superlistapp/super_editor/issues/234
    final documentSelection = widget.composer.selection;
    if (documentSelection == null) {
      _blinkController.stopBlinking();
      return;
    }

    _blinkController.jumpToOpaque();
    _startOrStopBlinking();
  }

  @override
  Rect? computeLayoutDataWithDocumentLayout(
      BuildContext contentLayersContext, BuildContext documentContext, DocumentLayout documentLayout) {
    final documentSelection = widget.composer.selection;
    if (documentSelection == null) {
      return null;
    }

    final selectedComponent = documentLayout.getComponentByNodeId(widget.composer.selection!.extent.nodeId);
    if (selectedComponent == null) {
      // Assume that we're in a momentary transitive state where the document layout
      // just gained or lost a component. We expect this method ot run again in a moment
      // to correct for this.
      return null;
    }

    Rect caretRect =
        documentLayout.getEdgeForPosition(documentSelection.extent)!.translate(-widget.caretStyle.width / 2, 0.0);

    final overlayBox = context.findRenderObject() as RenderBox?;
    if (overlayBox != null && overlayBox.hasSize && caretRect.left + widget.caretStyle.width >= overlayBox.size.width) {
      // Ajust the caret position to make it entirely visible because it's currently placed
      // partially or entirely outside of the layers' bounds. This can happen for downstream selections
      // of block components that take all the available width.
      caretRect = Rect.fromLTWH(
        overlayBox.size.width - widget.caretStyle.width,
        caretRect.top,
        caretRect.width,
        caretRect.height,
      );
    }

    return caretRect;
  }

  @override
  Widget doBuild(BuildContext context, Rect? caret) {
    // By default, don't show a caret on mobile because SuperEditor displays
    // mobile carets and handles elsewhere. This can be overridden by settings
    // `displayOnAllPlatforms` to true.
    final platform = widget.platformOverride ?? defaultTargetPlatform;
    if (!widget.displayOnAllPlatforms && (platform == TargetPlatform.android || platform == TargetPlatform.iOS)) {
      return const EmptyBox();
    }

    if (_shouldHideCaretForExpandedSelection) {
      return const EmptyBox();
    }

    // Use a RepaintBoundary so that caret flashing doesn't invalidate our
    // ancestor painting.
    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (caret != null)
              Positioned(
                top: caret.top,
                left: caret.left,
                height: caret.height,
                child: AnimatedBuilder(
                  animation: _blinkController,
                  builder: (context, child) {
                    return Container(
                      key: DocumentKeys.caret,
                      width: widget.caretStyle.width,
                      decoration: BoxDecoration(
                        color: widget.caretStyle.color.withValues(alpha: _blinkController.opacity),
                        borderRadius: widget.caretStyle.borderRadius,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
