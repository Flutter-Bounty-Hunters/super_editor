import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/render_sliver_ext.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../super_editor/supereditor_test_tools.dart';

void main() {
  group("Content layers", () {
    testWidgets(
      "build without any layers",
      (tester) async {
        await _pumpScaffold(
          tester,
          _layoutVariant.currentValue!,
          child: _layoutVariant.currentValue! == _LayoutMode.slivers
              ? SliverContentLayers(
                  content: (_) => SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // The content should be able to take up whatever width it wants, within the available space.
                        // The height is infinite because `ContentLayers` is a sliver.
                        expect(constraints.isTight, isFalse);
                        expect(constraints.maxWidth, _windowSize.width);
                        expect(constraints.maxHeight, double.infinity);

                        return SizedBox.fromSize(size: _windowSize);
                      },
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // The content should be able to take up whatever width and height it wants, within the
                    // available space.
                    expect(constraints.isTight, isFalse);
                    expect(constraints.maxWidth, _windowSize.width);
                    expect(constraints.maxHeight, _windowSize.height);

                    return SizedBox.fromSize(size: _windowSize);
                  },
                ),
        );

        // Getting here without an error means the test passes.
      },
      variant: _layoutVariant,
    );

    testWidgets(
      "build with a single underlay and is same size as content",
      (tester) async {
        await _pumpScaffold(
          tester,
          _layoutVariant.currentValue!,
          child: _layoutVariant.currentValue! == _LayoutMode.slivers
              ? SliverContentLayers(
                  content: (_) => SliverToBoxAdapter(
                    child: SizedBox.fromSize(size: _windowSize),
                  ),
                  underlays: [
                    _buildSizeValidatingLayer(),
                  ],
                )
              : BoxContentLayers(
                  content: (_) => SizedBox.fromSize(size: _windowSize),
                  underlays: [
                    _buildSizeValidatingLayer(),
                  ],
                ),
        );

        // Getting here without an error means the test passes.
      },
      variant: _layoutVariant,
    );

    testWidgets(
      "build with a single overlay and is same size as content",
      (tester) async {
        await _pumpScaffold(
          tester,
          _layoutVariant.currentValue!,
          child: _layoutVariant.currentValue! == _LayoutMode.slivers
              ? SliverContentLayers(
                  content: (_) => SliverToBoxAdapter(
                    child: SizedBox.fromSize(size: _windowSize),
                  ),
                  overlays: [
                    _buildSizeValidatingLayer(),
                  ],
                )
              : BoxContentLayers(
                  content: (_) => SizedBox.fromSize(size: _windowSize),
                  overlays: [
                    _buildSizeValidatingLayer(),
                  ],
                ),
        );

        // Getting here without an error means the test passes.
      },
      variant: _layoutVariant,
    );

    testWidgets(
      "build with a single underlay and overlay and they are the same size as content",
      (tester) async {
        await _pumpScaffold(
          tester,
          _layoutVariant.currentValue!,
          child: _layoutVariant.currentValue! == _LayoutMode.slivers
              ? SliverContentLayers(
                  content: (_) => SliverToBoxAdapter(
                    child: SizedBox.fromSize(size: _windowSize),
                  ),
                  underlays: [
                    _buildSizeValidatingLayer(),
                  ],
                  overlays: [
                    _buildSizeValidatingLayer(),
                  ],
                )
              : BoxContentLayers(
                  content: (_) => SizedBox.fromSize(size: _windowSize),
                  underlays: [
                    _buildSizeValidatingLayer(),
                  ],
                  overlays: [
                    _buildSizeValidatingLayer(),
                  ],
                ),
        );

        // Getting here without an error means the test passes.
      },
      variant: _layoutVariant,
    );

    testWidgets(
      "build with multiple underlays and overlays and they are the same size as content",
      (tester) async {
        await _pumpScaffold(
          tester,
          _layoutVariant.currentValue!,
          child: _layoutVariant.currentValue! == _LayoutMode.slivers
              ? SliverContentLayers(
                  content: (_) => SliverToBoxAdapter(
                    child: SizedBox.fromSize(size: _windowSize),
                  ),
                  underlays: [
                    _buildSizeValidatingLayer(),
                    _buildSizeValidatingLayer(),
                    _buildSizeValidatingLayer(),
                  ],
                  overlays: [
                    _buildSizeValidatingLayer(),
                    _buildSizeValidatingLayer(),
                    _buildSizeValidatingLayer(),
                  ],
                )
              : BoxContentLayers(
                  content: (_) => SizedBox.fromSize(size: _windowSize),
                  underlays: [
                    _buildSizeValidatingLayer(),
                    _buildSizeValidatingLayer(),
                    _buildSizeValidatingLayer(),
                  ],
                  overlays: [
                    _buildSizeValidatingLayer(),
                    _buildSizeValidatingLayer(),
                    _buildSizeValidatingLayer(),
                  ],
                ),
        );

        // Getting here without an error means the test passes.
      },
      variant: _layoutVariant,
    );

    testWidgets(
      "rebuilds layers when they setState()",
      (tester) async {
        final contentRebuildSignal = ValueNotifier<int>(0);
        final contentBuildTracker = ValueNotifier<int>(0);

        final underlayRebuildSignal = ValueNotifier<int>(0);
        final underlayBuildTracker = ValueNotifier<int>(0);

        final overlayRebuildSignal = ValueNotifier<int>(0);
        final overlayBuildTracker = ValueNotifier<int>(0);

        await _pumpScaffold(
          tester,
          _layoutVariant.currentValue!,
          child: _layoutVariant.currentValue! == _LayoutMode.slivers
              ? SliverContentLayers(
                  content: (onBuildScheduled) => _RebuildableWidget(
                    rebuildSignal: contentRebuildSignal,
                    buildTracker: contentBuildTracker,
                    onBuildScheduled: onBuildScheduled,
                    child: SliverToBoxAdapter(
                      child: SizedBox.fromSize(size: _windowSize),
                    ),
                  ),
                  underlays: [
                    (context) => _RebuildableContentLayerWidget(
                          rebuildSignal: underlayRebuildSignal,
                          buildTracker: underlayBuildTracker,
                          child: const SizedBox(),
                        ),
                  ],
                  overlays: [
                    (context) => _RebuildableContentLayerWidget(
                          rebuildSignal: overlayRebuildSignal,
                          buildTracker: overlayBuildTracker,
                          child: const SizedBox(),
                        ),
                  ],
                )
              : BoxContentLayers(
                  content: (onBuildScheduled) => _RebuildableWidget(
                    rebuildSignal: contentRebuildSignal,
                    buildTracker: contentBuildTracker,
                    onBuildScheduled: onBuildScheduled,
                    child: SizedBox.fromSize(size: _windowSize),
                  ),
                  underlays: [
                    (context) => _RebuildableContentLayerWidget(
                          rebuildSignal: underlayRebuildSignal,
                          buildTracker: underlayBuildTracker,
                          child: const SizedBox(),
                        ),
                  ],
                  overlays: [
                    (context) => _RebuildableContentLayerWidget(
                          rebuildSignal: overlayRebuildSignal,
                          buildTracker: overlayBuildTracker,
                          child: const SizedBox(),
                        ),
                  ],
                ),
        );
        expect(contentBuildTracker.value, 1);
        expect(underlayBuildTracker.value, 1);
        expect(overlayBuildTracker.value, 1);

        // Tell the underlay widget to rebuild itself.
        underlayRebuildSignal.value += 1;
        await tester.pump();
        expect(underlayBuildTracker.value, 2);
        expect(contentBuildTracker.value, 1);

        // Tell the overlay widget to rebuild itself.
        overlayRebuildSignal.value += 1;
        await tester.pump();
        expect(overlayBuildTracker.value, 2);
        expect(contentBuildTracker.value, 1);
      },
      variant: _layoutVariant,
    );

    testWidgets(
      "lays out the content before building the layers during full tree build",
      (tester) async {
        final didContentLayout = ValueNotifier<bool>(false);
        bool didUnderlayLayout = false;

        await _pumpScaffold(
          tester,
          _layoutVariant.currentValue!,
          child: _layoutVariant.currentValue! == _LayoutMode.slivers
              ? SliverContentLayers(
                  content: (_) => _SliverLayoutTrackingWidget(
                    onLayout: () {
                      didContentLayout.value = true;
                    },
                    child: SliverToBoxAdapter(
                      child: SizedBox.fromSize(size: _windowSize),
                    ),
                  ),
                  underlays: [
                    (context) {
                      expect(didContentLayout.value, isTrue);
                      didUnderlayLayout = true;
                      return const ContentLayerProxyWidget(
                        child: SizedBox(),
                      );
                    },
                  ],
                  overlays: [
                    (context) {
                      expect(didContentLayout.value, isTrue);
                      expect(didUnderlayLayout, isTrue);
                      return const ContentLayerProxyWidget(
                        child: SizedBox(),
                      );
                    },
                  ],
                )
              : BoxContentLayers(
                  content: (_) => _BoxLayoutTrackingWidget(
                    onLayout: () {
                      didContentLayout.value = true;
                    },
                    child: SizedBox.fromSize(size: _windowSize),
                  ),
                  underlays: [
                    (context) {
                      expect(didContentLayout.value, isTrue);
                      didUnderlayLayout = true;
                      return const ContentLayerProxyWidget(
                        child: SizedBox(),
                      );
                    },
                  ],
                  overlays: [
                    (context) {
                      expect(didContentLayout.value, isTrue);
                      expect(didUnderlayLayout, isTrue);
                      return const ContentLayerProxyWidget(
                        child: SizedBox(),
                      );
                    },
                  ],
                ),
        );

        // Getting here without an error means the test passes.
      },
      variant: _layoutVariant,
    );

    testWidgets(
      "lays out the content before building the layers when the content root rebuilds",
      (tester) async {
        final rebuildSignal = ValueNotifier<int>(0);
        final buildTracker = ValueNotifier<int>(0);
        final contentLayoutCount = ValueNotifier<int>(0);
        final layerLayoutCount = ValueNotifier<int>(0);

        await _pumpScaffold(
          tester,
          _layoutVariant.currentValue!,
          child: _layoutVariant.currentValue! == _LayoutMode.slivers
              ? SliverContentLayers(
                  content: (onBuildScheduled) => _RebuildableWidget(
                    rebuildSignal: rebuildSignal,
                    buildTracker: buildTracker,
                    onBuildScheduled: onBuildScheduled,
                    child: _SliverLayoutTrackingWidget(
                      onLayout: () {
                        contentLayoutCount.value += 1;
                      },
                      child: SliverToBoxAdapter(
                        child: SizedBox.fromSize(size: _windowSize),
                      ),
                    ),
                  ),
                  underlays: [
                    (context) {
                      expect(contentLayoutCount.value, layerLayoutCount.value + 1);
                      return const ContentLayerProxyWidget(
                        child: SizedBox(),
                      );
                    },
                  ],
                  overlays: [
                    (context) {
                      expect(contentLayoutCount.value, layerLayoutCount.value + 1);
                      layerLayoutCount.value += 1;
                      return const ContentLayerProxyWidget(
                        child: SizedBox(),
                      );
                    },
                  ],
                )
              : BoxContentLayers(
                  content: (onBuildScheduled) => _RebuildableWidget(
                    rebuildSignal: rebuildSignal,
                    buildTracker: buildTracker,
                    onBuildScheduled: onBuildScheduled,
                    child: _BoxLayoutTrackingWidget(
                      onLayout: () {
                        contentLayoutCount.value += 1;
                      },
                      child: SizedBox.fromSize(size: _windowSize),
                    ),
                  ),
                  underlays: [
                    (context) {
                      expect(contentLayoutCount.value, layerLayoutCount.value + 1);
                      return const ContentLayerProxyWidget(
                        child: SizedBox(),
                      );
                    },
                  ],
                  overlays: [
                    (context) {
                      expect(contentLayoutCount.value, layerLayoutCount.value + 1);
                      layerLayoutCount.value += 1;
                      return const ContentLayerProxyWidget(
                        child: SizedBox(),
                      );
                    },
                  ],
                ),
        );
        expect(buildTracker.value, 1);

        // Tell the content widget to rebuild itself.
        rebuildSignal.value += 1;
        await tester.pump();

        // We expect build and layout to run twice. First, during the initial pump. Second,
        // after we tell the content to rebuild.
        expect(buildTracker.value, 2);
        expect(contentLayoutCount.value, 2);
        expect(layerLayoutCount.value, 2);
      },
      variant: _layoutVariant,
    );

    testWidgets(
      "lays out the content before building the layers when a content descendant rebuilds",
      (tester) async {
        final rebuildSignal = ValueNotifier<int>(0);
        final buildTracker = ValueNotifier<int>(0);
        final contentLayoutCount = ValueNotifier<int>(0);
        final layerLayoutCount = ValueNotifier<int>(0);

        await _pumpScaffold(
          tester,
          _layoutVariant.currentValue!,
          child: _layoutVariant.currentValue! == _LayoutMode.slivers
              ? SliverContentLayers(
                  // Place a couple stateful widgets above the _RebuildableWidget to ensure that
                  // when a widget deeper in the tree rebuilds, we still rebuild ContentLayers.
                  content: (_) => _NoRebuildWidget(
                    child: _NoRebuildWidget(
                      child: _RebuildableWidget(
                        rebuildSignal: rebuildSignal,
                        buildTracker: buildTracker,
                        // We don't pass in the onBuildScheduled callback here because we're simulating
                        // an entire subtree that a client might provide as content.
                        child: _SliverLayoutTrackingWidget(
                          onLayout: () {
                            contentLayoutCount.value += 1;
                          },
                          child: SliverToBoxAdapter(
                            child: SizedBox.fromSize(size: _windowSize),
                          ),
                        ),
                      ),
                    ),
                  ),
                  underlays: [
                    (context) {
                      expect(contentLayoutCount.value, layerLayoutCount.value + 1);
                      return const ContentLayerProxyWidget(
                        child: SizedBox(),
                      );
                    },
                  ],
                  overlays: [
                    (context) {
                      expect(contentLayoutCount.value, layerLayoutCount.value + 1);
                      layerLayoutCount.value += 1;
                      return const ContentLayerProxyWidget(
                        child: SizedBox(),
                      );
                    },
                  ],
                )
              : BoxContentLayers(
                  // Place a couple stateful widgets above the _RebuildableWidget to ensure that
                  // when a widget deeper in the tree rebuilds, we still rebuild ContentLayers.
                  content: (_) => _NoRebuildWidget(
                    child: _NoRebuildWidget(
                      child: _RebuildableWidget(
                        rebuildSignal: rebuildSignal,
                        buildTracker: buildTracker,
                        // We don't pass in the onBuildScheduled callback here because we're simulating
                        // an entire subtree that a client might provide as content.
                        child: _BoxLayoutTrackingWidget(
                          onLayout: () {
                            contentLayoutCount.value += 1;
                          },
                          child: SizedBox.fromSize(size: _windowSize),
                        ),
                      ),
                    ),
                  ),
                  underlays: [
                    (context) {
                      expect(contentLayoutCount.value, layerLayoutCount.value + 1);
                      return const ContentLayerProxyWidget(
                        child: SizedBox(),
                      );
                    },
                  ],
                  overlays: [
                    (context) {
                      expect(contentLayoutCount.value, layerLayoutCount.value + 1);
                      layerLayoutCount.value += 1;
                      return const ContentLayerProxyWidget(
                        child: SizedBox(),
                      );
                    },
                  ],
                ),
        );
        expect(buildTracker.value, 1);
        expect(contentLayoutCount.value, 1);
        expect(layerLayoutCount.value, 1);

        // Tell the content widget to rebuild itself.
        rebuildSignal.value += 1;
        await tester.pump();

        // We expect build and layout to run twice. First, during the initial pump. Second,
        // after we tell the content to rebuild.
        expect(buildTracker.value, 2);
        expect(contentLayoutCount.value, 2);
        expect(layerLayoutCount.value, 2);
      },
      variant: _layoutVariant,
    );

    testWidgets(
      "re-uses layer Elements instead of always re-inflating layer Widgets",
      (tester) async {
        final rebuildSignal = ValueNotifier<int>(0);
        final buildTracker = ValueNotifier<int>(0);
        final contentKey = GlobalKey();
        final contentLayoutCount = ValueNotifier<int>(0);
        final underlayElementTracker = ValueNotifier<Element?>(null);
        Element? underlayElement;
        final overlayElementTracker = ValueNotifier<Element?>(null);
        Element? overlayElement;

        await _pumpScaffold(
          tester,
          _layoutVariant.currentValue!,
          child: _layoutVariant.currentValue! == _LayoutMode.slivers
              ? SliverContentLayers(
                  content: (_) => _RebuildableWidget(
                    key: contentKey,
                    rebuildSignal: rebuildSignal,
                    buildTracker: buildTracker,
                    // We don't pass in the onBuildScheduled callback here because we're simulating
                    // an entire subtree that a client might provide as content.
                    child: _SliverLayoutTrackingWidget(
                      onLayout: () {
                        contentLayoutCount.value += 1;
                      },
                      child: SliverToBoxAdapter(
                        child: SizedBox.fromSize(size: _windowSize),
                      ),
                    ),
                  ),
                  underlays: [
                    (context) => _RebuildableContentLayerWidget(
                          elementTracker: underlayElementTracker,
                          onBuild: () {
                            // Ensure that this layer can access the render object of the content.
                            final contentSliver = contentKey.currentContext!.findRenderObject() as RenderSliver?;
                            expect(contentSliver, isNotNull);
                            expect(contentSliver!.geometry, isNotNull);
                            final viewport = context.findAncestorRenderObjectOfType<RenderViewport>();
                            // Build happens during viewport layout, which is not finished at this point. So transform to viewport
                            // coordinate space is as far as we can go.
                            expect(contentSliver.localToGlobal(Offset.zero, ancestor: viewport), isNotNull);
                          },
                          child: const SizedBox.expand(),
                        ),
                  ],
                  overlays: [
                    (context) => _RebuildableContentLayerWidget(
                          elementTracker: overlayElementTracker,
                          onBuild: () {
                            // Ensure that this layer can access the render object of the content.
                            final contentSliver = contentKey.currentContext!.findRenderObject() as RenderSliver?;
                            expect(contentSliver, isNotNull);
                            expect(contentSliver!.geometry, isNotNull);
                            final viewport = context.findAncestorRenderObjectOfType<RenderViewport>();
                            // Build happens during viewport layout, which is not finished at this point. So transform to viewport
                            // coordinate space is as far as we can go.
                            expect(contentSliver.localToGlobal(Offset.zero, ancestor: viewport), isNotNull);
                          },
                          child: const SizedBox.expand(),
                        ),
                  ],
                )
              : BoxContentLayers(
                  content: (_) => _RebuildableWidget(
                    rebuildSignal: rebuildSignal,
                    buildTracker: buildTracker,
                    // We don't pass in the onBuildScheduled callback here because we're simulating
                    // an entire subtree that a client might provide as content.
                    child: _BoxLayoutTrackingWidget(
                      onLayout: () {
                        contentLayoutCount.value += 1;
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
                  underlays: [
                    (context) => _RebuildableContentLayerWidget(
                          elementTracker: underlayElementTracker,
                          child: const SizedBox.expand(),
                        ),
                  ],
                  overlays: [
                    (context) => _RebuildableContentLayerWidget(
                          elementTracker: overlayElementTracker,
                          child: const SizedBox.expand(),
                        ),
                  ],
                ),
        );
        expect(buildTracker.value, 1);

        underlayElement = underlayElementTracker.value;
        expect(underlayElement, isNotNull);

        overlayElement = overlayElementTracker.value;
        expect(overlayElement, isNotNull);

        // Tell the content widget to rebuild itself.
        rebuildSignal.value += 1;
        await tester.pump();

        // We expect build and layout to run twice. First, during the initial pump. Second,
        // after we tell the content to rebuild.
        expect(buildTracker.value, 2);
        expect(contentLayoutCount.value, 2);
        expect(underlayElementTracker.value, underlayElement);
        expect(overlayElementTracker.value, overlayElement);
      },
      variant: _layoutVariant,
    );

    testWidgets(
      "lets layers access inherited widgets",
      (tester) async {
        await _pumpScaffold(
          tester,
          _layoutVariant.currentValue!,
          child: _layoutVariant.currentValue! == _LayoutMode.slivers
              ? SliverContentLayers(
                  content: (_) => SliverToBoxAdapter(
                    child: SizedBox.fromSize(size: _windowSize),
                  ),
                  underlays: [
                    (context) {
                      // Ensure that this layer can access ancestors.
                      final directionality = Directionality.of(context);
                      expect(directionality, isNotNull);

                      return const ContentLayerProxyWidget(
                        child: SizedBox(),
                      );
                    },
                  ],
                  overlays: [
                    (context) {
                      // Ensure that this layer can access ancestors.
                      final directionality = Directionality.of(context);
                      expect(directionality, isNotNull);

                      return const ContentLayerProxyWidget(
                        child: SizedBox(),
                      );
                    },
                  ],
                )
              : BoxContentLayers(
                  content: (_) => SizedBox.fromSize(size: _windowSize),
                  underlays: [
                    (context) {
                      // Ensure that this layer can access ancestors.
                      final directionality = Directionality.of(context);
                      expect(directionality, isNotNull);

                      return const ContentLayerProxyWidget(
                        child: SizedBox(),
                      );
                    },
                  ],
                  overlays: [
                    (context) {
                      // Ensure that this layer can access ancestors.
                      final directionality = Directionality.of(context);
                      expect(directionality, isNotNull);

                      return const ContentLayerProxyWidget(
                        child: SizedBox(),
                      );
                    },
                  ],
                ),
        );

        // Getting here without an error means the test passes.
      },
      variant: _layoutVariant,
    );

    testWidgets("SuperEditor ContentLayers full rebuild", (tester) async {
      // This test recreates a nuanced timing scenario where rebuilding
      // all of SuperEditor, while also rebuilding its selection layer,
      // results in an attempt to access a dirty document layout during
      // selection layer build.

      final rebuildSignal = ValueNotifier<int>(0);

      final editorContext = tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .build();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _RebuildableContentLayerWidget(
              rebuildSignal: rebuildSignal,
              builder: (context) => SuperEditor(
                editor: editorContext.context.editor,
                inputSource: TextInputSource.keyboard,
              ),
            ),
          ),
        ),
      );

      await tester.placeCaretInParagraph("1", 0);

      // Insert a character so that the document content and the selection layer changes.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);

      // CRITICAL: We must request a full SuperEditor rebuild before starting to pump
      // another frame. This timing is critical to causing the content layout bug.
      //
      // This SuperEditor rebuild simulates a situation where a change in the editor
      // requests a rebuild of the content, rebuild of a layer, and also a rebuild
      // of the full editor, all in the same frame. This has happened, for example, in
      // the demo app where the user types text to create a tag. When the tag is
      // recognized, it includes a new character, a new caret position, and a new tag
      // display in the widget tree around the editor.
      rebuildSignal.value += 1;

      // Pumping this frame would trigger the build order bug if it still existed.
      await tester.pump();
    });
  });
}

Future<void> _pumpScaffold(
  WidgetTester tester,
  _LayoutMode layoutMode, {
  required Widget child,
}) async {
  addTearDown(() => tester.platformDispatcher.clearAllTestValues());

  tester.view
    ..physicalSize = _windowSize
    ..devicePixelRatio = 1.0;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: layoutMode == _LayoutMode.slivers
            ? CustomScrollView(
                slivers: [
                  child,
                ],
              )
            : child,
      ),
    ),
  );
}

final _layoutVariant = ValueVariant(_LayoutMode.values.toSet());

enum _LayoutMode {
  boxes,
  slivers;
}

// We control the window size in these tests so that we can easily compare and validate
// the layout sizes for underlays and overlays.
const _windowSize = Size(600, 1000);

/// Returns a [LayoutBuilder] that expects its constraints to be the same as the window,
/// used for quickly verifying the constraints given to underlays and overlays in
/// ContentLayers widgets in this test suite.
ContentLayerWidgetBuilder _buildSizeValidatingLayer() {
  return (context) => const _SizeValidatingLayer();
}

class _SizeValidatingLayer extends ContentLayerStatefulWidget {
  const _SizeValidatingLayer();

  @override
  ContentLayerState<ContentLayerStatefulWidget, Object> createState() => _SizeValidatingLayerState();
}

class _SizeValidatingLayerState extends ContentLayerState<_SizeValidatingLayer, Object> {
  @override
  Object? computeLayoutData(Element? contentElement, RenderObject? contentLayout) => null;

  @override
  Widget doBuild(BuildContext context, Object? layoutData) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _expectLayerConstraintsThatMatchContent(constraints);
        return const SizedBox();
      },
    );
  }
}

void _expectLayerConstraintsThatMatchContent(BoxConstraints constraints) {
  expect(constraints.isTight, isTrue);
  expect(constraints.maxWidth, _windowSize.width);
  expect(constraints.maxHeight, _windowSize.height);
}

/// A [StatefulWidget] that never rebuilds.
///
/// Used to inject an `Element` above another widget to test what happens when a descendant
/// rebuilds, and that descendant isn't the top-level widget in a subtree.
class _NoRebuildWidget extends StatefulWidget {
  const _NoRebuildWidget({
    Key? key,
    required this.child,
  }) : super(key: key);

  final Widget child;

  @override
  State<_NoRebuildWidget> createState() => _NoRebuildWidgetState();
}

class _NoRebuildWidgetState extends State<_NoRebuildWidget> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Widget that can be told to rebuild from the outside, and also tracks its build count.
class _RebuildableWidget extends StatefulWidget {
  const _RebuildableWidget({
    Key? key,
    this.rebuildSignal,
    this.buildTracker,
    // TODO(srawlins): `unused_element`, when reporting a parameter, is being
    // renamed to `unused_element_parameter`. For now, ignore each; when the SDK
    // constraint is >= 3.6.0, just ignore `unused_element_parameter`.
    // ignore: unused_element, unused_element_parameter
    this.elementTracker,
    this.onBuildScheduled,
    // TODO(srawlins): `unused_element`, when reporting a parameter, is being
    // renamed to `unused_element_parameter`. For now, ignore each; when the SDK
    // constraint is >= 3.6.0, just ignore `unused_element_parameter`.
    // ignore: unused_element, unused_element_parameter
    this.onBuild,
    this.builder,
    this.child,
  })  : assert(child != null || builder != null, "Must provide either a child OR a builder."),
        assert(child == null || builder == null, "Can't provide a child AND a builder. Choose one."),
        super(key: key);

  /// Signal that instructs this widget to call `setState()`.
  final Listenable? rebuildSignal;

  /// The number of times this widget has run `build()`.
  final ValueNotifier<int>? buildTracker;

  /// The [Element] that currently owns this `Widget` and its `State`.
  final ValueNotifier<Element?>? elementTracker;

  /// Callback that's invoked when this widget calls `setState()`.
  final VoidCallback? onBuildScheduled;

  /// Callback that's invoked during this widget's `build()` method.
  final VoidCallback? onBuild;

  final WidgetBuilder? builder;
  final Widget? child;

  @override
  State<_RebuildableWidget> createState() => _RebuildableWidgetState();
}

class _RebuildableWidgetState extends State<_RebuildableWidget> {
  @override
  void initState() {
    super.initState();
    widget.rebuildSignal?.addListener(_onRebuildSignal);
  }

  @override
  void didUpdateWidget(_RebuildableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.rebuildSignal != oldWidget.rebuildSignal) {
      oldWidget.rebuildSignal?.removeListener(_onRebuildSignal);
      widget.rebuildSignal?.addListener(_onRebuildSignal);
    }
  }

  @override
  void dispose() {
    widget.rebuildSignal?.removeListener(_onRebuildSignal);
    super.dispose();
  }

  void _onRebuildSignal() {
    setState(() {
      // rebuild
    });

    // Explicitly mark our RenderObject as needing layout so that we simulate content
    // that rebuilds because its layout changed. Without this call, we'd get a widget
    // rebuild, but we wouldn't trigger another content layout pass. We want that
    // layout pass so that our tests can inspect the order of operations and ensure that
    // when the content layout changes, the content is always laid out before layers.
    context.findRenderObject()?.markNeedsLayout();
  }

  // This override is a regrettable requirement for ContentLayers, which is needed so
  // that ContentLayers can remove the layers to prevent them from building during a
  // regular build phase when the content changes. This is the result of Flutter making
  // it impossible to monitor dirty subtrees, and making it impossible to control build
  // order.
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    widget.onBuildScheduled?.call();
  }

  @override
  Widget build(BuildContext context) {
    widget.buildTracker?.value += 1;
    widget.elementTracker?.value = context as Element;

    widget.onBuild?.call();

    return widget.child != null ? widget.child! : widget.builder!.call(context);
  }
}

/// Content layer that can be told to rebuild from the outside, and also tracks its build count.
class _RebuildableContentLayerWidget extends ContentLayerStatefulWidget {
  const _RebuildableContentLayerWidget({
    Key? key,
    this.rebuildSignal,
    this.buildTracker,
    this.elementTracker,
    // TODO(srawlins): `unused_element`, when reporting a parameter, is being
    // renamed to `unused_element_parameter`. For now, ignore each; when the SDK
    // constraint is >= 3.6.0, just ignore `unused_element_parameter`.
    // ignore: unused_element, unused_element_parameter
    this.onBuildScheduled,
    this.onBuild,
    this.builder,
    this.child,
  })  : assert(child != null || builder != null, "Must provide either a child OR a builder."),
        assert(child == null || builder == null, "Can't provide a child AND a builder. Choose one."),
        super(key: key);

  /// Signal that instructs this widget to call `setState()`.
  final Listenable? rebuildSignal;

  /// The number of times this widget has run `build()`.
  final ValueNotifier<int>? buildTracker;

  /// The [Element] that currently owns this `Widget` and its `State`.
  final ValueNotifier<Element?>? elementTracker;

  /// Callback that's invoked when this widget calls `setState()`.
  final VoidCallback? onBuildScheduled;

  /// Callback that's invoked during this widget's `build()` method.
  final VoidCallback? onBuild;

  final WidgetBuilder? builder;
  final Widget? child;

  @override
  ContentLayerState<ContentLayerStatefulWidget, Object> createState() => _RebuildableContentLayerWidgetState();
}

class _RebuildableContentLayerWidgetState extends ContentLayerState<_RebuildableContentLayerWidget, Object> {
  @override
  void initState() {
    super.initState();
    widget.rebuildSignal?.addListener(_onRebuildSignal);
  }

  @override
  void didUpdateWidget(_RebuildableContentLayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.rebuildSignal != oldWidget.rebuildSignal) {
      oldWidget.rebuildSignal?.removeListener(_onRebuildSignal);
      widget.rebuildSignal?.addListener(_onRebuildSignal);
    }
  }

  @override
  void dispose() {
    widget.rebuildSignal?.removeListener(_onRebuildSignal);
    super.dispose();
  }

  void _onRebuildSignal() {
    setState(() {
      // rebuild
    });

    // Explicitly mark our RenderObject as needing layout so that we simulate content
    // that rebuilds because its layout changed. Without this call, we'd get a widget
    // rebuild, but we wouldn't trigger another content layout pass. We want that
    // layout pass so that our tests can inspect the order of operations and ensure that
    // when the content layout changes, the content is always laid out before layers.
    context.findRenderObject()?.markNeedsLayout();
  }

  // This override is a regrettable requirement for ContentLayers, which is needed so
  // that ContentLayers can remove the layers to prevent them from building during a
  // regular build phase when the content changes. This is the result of Flutter making
  // it impossible to monitor dirty subtrees, and making it impossible to control build
  // order.
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    widget.onBuildScheduled?.call();
  }

  @override
  Object? computeLayoutData(Element? contentElement, RenderObject? contentLayout) => null;

  @override
  Widget doBuild(BuildContext context, Object? object) {
    widget.buildTracker?.value += 1;
    widget.elementTracker?.value = context as Element;

    widget.onBuild?.call();

    return widget.child != null ? widget.child! : widget.builder!.call(context);
  }
}

/// Widget that reports every time it runs layout as a Render Box.
class _BoxLayoutTrackingWidget extends SingleChildRenderObjectWidget {
  const _BoxLayoutTrackingWidget({
    required this.onLayout,
    required Widget child,
  }) : super(child: child);

  final VoidCallback onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderBoxLayoutTrackingWidget(onLayout);
  }
}

class _RenderBoxLayoutTrackingWidget extends RenderProxyBox {
  _RenderBoxLayoutTrackingWidget(this._onLayout);

  final VoidCallback _onLayout;

  @override
  void performLayout() {
    _onLayout();
    super.performLayout();
  }
}

/// Widget that reports every time it runs layout as a Sliver.
class _SliverLayoutTrackingWidget extends SingleChildRenderObjectWidget {
  const _SliverLayoutTrackingWidget({
    required this.onLayout,
    required Widget child,
  }) : super(child: child);

  final VoidCallback onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSliverLayoutTrackingWidget(onLayout);
  }
}

class _RenderSliverLayoutTrackingWidget extends RenderProxySliver {
  _RenderSliverLayoutTrackingWidget(this._onLayout);

  final VoidCallback _onLayout;

  @override
  void performLayout() {
    _onLayout();
    super.performLayout();
  }
}
