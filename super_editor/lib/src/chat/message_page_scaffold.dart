import 'dart:math';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_keyboard/super_keyboard.dart';

/// A scaffold for a chat experience in which a conversation thread is
/// displayed, with a message editor mounted to the bottom of the chat area.
///
/// In the case of an app running on a phone, this scaffold is typically used
/// for the entire screen. On a tablet, this scaffold might be used for just a
/// chat pane.
///
/// The bottom sheet in this scaffold supports various sizing modes. These modes
/// can be queried and altered with a given [controller].
class MessagePageScaffold extends RenderObjectWidget {
  const MessagePageScaffold({
    super.key,
    this.controller,
    required this.contentBuilder,
    required this.bottomSheetBuilder,
    this.bottomSheetMinimumTopGap = 200,
    this.bottomSheetMinimumHeight = 150,
    this.bottomSheetCollapsedMaximumHeight = double.infinity,
  });

  final MessagePageController? controller;

  /// Builds the content within this scaffold, e.g., a chat conversation thread.
  final MessagePageScaffoldContentBuilder contentBuilder;

  /// Builds the bottom sheet within this scaffold, e.g., a chat message editor.
  final WidgetBuilder bottomSheetBuilder;

  /// When dragging the bottom sheet up, or when filling it with content,
  /// this is the minimum gap allowed between the sheet and the top of this
  /// scaffold.
  ///
  /// When the bottom sheet reaches the minimum gap, it stops getting taller,
  /// and its content scrolls.
  final double bottomSheetMinimumTopGap;

  /// The shortest that the bottom sheet can ever be, regardless of content or
  /// height mode.
  final double bottomSheetMinimumHeight;

  /// The maximum height that the bottom sheet can expand to, as the intrinsic height
  /// of the content increases.
  ///
  /// E.g., The user starts with a single line of text and then starts inserting
  /// newlines. As the user continues to add newlines, this height is where the sheet
  /// stops growing taller.
  ///
  /// This height applies when the sheet is collapsed, i.e., not expanded. If the user
  /// expands the sheet, then the maximum height of the sheet would be the maximum allowed
  /// layout height, minus [bottomSheetMinimumTopGap].
  final double bottomSheetCollapsedMaximumHeight;

  @override
  RenderObjectElement createElement() {
    return MessagePageElement(this);
  }

  @override
  RenderMessagePageScaffold createRenderObject(BuildContext context) {
    return RenderMessagePageScaffold(
      context as MessagePageElement,
      controller,
      bottomSheetMinimumTopGap: bottomSheetMinimumTopGap,
      bottomSheetMinimumHeight: bottomSheetMinimumHeight,
      bottomSheetCollapsedMaximumHeight: bottomSheetCollapsedMaximumHeight,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderMessagePageScaffold renderObject) {
    renderObject
      ..bottomSheetMinimumTopGap = bottomSheetMinimumTopGap
      ..bottomSheetMinimumHeight = bottomSheetMinimumHeight
      ..bottomSheetCollapsedMaximumHeight = bottomSheetCollapsedMaximumHeight;

    if (controller != null) {
      renderObject.controller = controller!;
    }
  }
}

/// Builder that builds the content subtree within a [MessagePageScaffold].
typedef MessagePageScaffoldContentBuilder = Widget Function(BuildContext context, double bottomSpacing);

/// Height sizing policy for a bottom sheet within a [MessagePageScaffold].
enum BottomSheetMode {
  /// The bottom sheet is as small possible, showing a partial display of its
  /// overall content.
  preview,

  /// The bottom sheet is intrinsically sized, making itself as tall as it
  /// wants, so long as it doesn't exceed the maximum height.
  intrinsic,

  /// The user is dragging the sheet - it's exactly the height needed to match
  /// the user's finger position, clamped between a minimum and maximum height.
  dragging,

  /// The user released a drag and the sheet is animating either to an
  /// [intrinsic] or [expanded] position.
  settling,

  /// The sheet is forced to be as tall as it can be, up to the maximum height.
  expanded;
}

/// Controller for a [MessagePageScaffold].
class MessagePageController with ChangeNotifier {
  MessagePageSheetHeightPolicy get sheetHeightPolicy => _sheetHeightPolicy;
  MessagePageSheetHeightPolicy _sheetHeightPolicy = MessagePageSheetHeightPolicy.minimumHeight;
  set sheetHeightPolicy(MessagePageSheetHeightPolicy policy) {
    if (policy == _sheetHeightPolicy) {
      return;
    }

    _sheetHeightPolicy = policy;
    notifyListeners();
  }

  bool get isPreview =>
      _collapsedMode == MessagePageSheetCollapsedMode.preview && //
      !isSliding &&
      !isDragging;

  bool get isIntrinsic =>
      _collapsedMode == MessagePageSheetCollapsedMode.intrinsic && //
      !isSliding &&
      !isDragging;

  MessagePageSheetCollapsedMode get collapsedMode => _collapsedMode;
  var _collapsedMode = MessagePageSheetCollapsedMode.preview;
  set collapsedMode(MessagePageSheetCollapsedMode newMode) {
    if (newMode == _collapsedMode) {
      return;
    }

    _collapsedMode = newMode;
    notifyListeners();
  }

  bool get isCollapsed =>
      _desiredSheetMode == MessagePageSheetMode.collapsed && //
      !isSliding &&
      !isDragging;

  bool get isExpanded =>
      _desiredSheetMode == MessagePageSheetMode.expanded && //
      !isSliding &&
      !isDragging;

  bool get isSliding => _isSliding;
  bool _isSliding = false;
  set isSliding(bool newValue) {
    if (newValue == _isSliding) {
      return;
    }

    _isSliding = newValue;
    notifyListeners();
  }

  MessagePageSheetMode get desiredSheetMode => _desiredSheetMode;
  MessagePageSheetMode _desiredSheetMode = MessagePageSheetMode.collapsed;
  set desiredSheetMode(MessagePageSheetMode sheetMode) {
    if (sheetMode == _desiredSheetMode) {
      return;
    }

    _desiredSheetMode = sheetMode;
    notifyListeners();
  }

  /// Sets the bottom sheet's desired mode to `collapsed`.
  ///
  /// Even in the collapsed mode, the sheet might be taller or shorter
  /// than the stable collapsed height, because the user can drag the
  /// sheet, and the sheet also animates from the drag position to the
  /// desired mode.
  void collapse() {
    if (_desiredSheetMode == MessagePageSheetMode.collapsed) {
      return;
    }

    _desiredSheetMode = MessagePageSheetMode.collapsed;
    notifyListeners();
  }

  /// Sets the bottom sheet's desired mode to `expanded`.
  ///
  /// Even in the expanded mode, the sheet might be taller or shorter
  /// than the stable expanded height, because the user can drag the
  /// sheet, and the sheet also animates from the drag position to the
  /// desired mode.
  void expand() {
    if (_desiredSheetMode == MessagePageSheetMode.expanded) {
      return;
    }

    _desiredSheetMode = MessagePageSheetMode.expanded;
    notifyListeners();
  }

  /// The user's current drag interaction with the editor sheet.
  MessagePageDragMode get dragMode => _dragMode;
  MessagePageDragMode _dragMode = MessagePageDragMode.idle;

  bool get isIdle => dragMode == MessagePageDragMode.idle;

  bool get isDragging => dragMode == MessagePageDragMode.dragging;

  /// When the user is dragging up/down on the editor, this is the desired
  /// y-value of the top edge of the editor area.
  ///
  /// This y-value may not be precisely respected, e.g., the user drags so far
  /// up that this value exceeds the max y-value allowed for the editor.
  double? get desiredGlobalTopY => _desiredGlobalTopY;
  double? _desiredGlobalTopY;

  void onDragStart(double desiredGlobalTopY) {
    assert(
      _dragMode == MessagePageDragMode.idle,
      'You called onDragStart() while a drag is in progress. You need to end one drag before starting another.',
    );

    _dragMode = MessagePageDragMode.dragging;
    _desiredGlobalTopY = desiredGlobalTopY;

    notifyListeners();
  }

  void onDragUpdate(double desiredGlobalTopY) {
    assert(
      _dragMode == MessagePageDragMode.dragging,
      'You must call onDragStart() before calling onDragUpdate()',
    );
    if (desiredGlobalTopY == _desiredGlobalTopY) {
      return;
    }

    _desiredGlobalTopY = desiredGlobalTopY;

    notifyListeners();
  }

  void onDragEnd() {
    assert(
      _dragMode == MessagePageDragMode.dragging,
      'You must call onDragStart() before calling onDragEnd()',
    );

    _dragMode = MessagePageDragMode.idle;
    _desiredGlobalTopY = null;

    notifyListeners();
  }

  /// The bottom spacing that was most recently used to build the scaffold.
  ///
  /// This is a debug value and should only be used for logging.
  final debugMostRecentBottomSpacing = ValueNotifier<double?>(null);
}

enum MessagePageSheetHeightPolicy {
  minimumHeight('minimum'),
  intrinsicHeight('intrinsic');

  const MessagePageSheetHeightPolicy(this.name);

  final String name;
}

enum MessagePageSheetCollapsedMode {
  /// The bottom sheet should be explicitly sized with a preview of its content.
  preview('preview'),

  /// The bottom sheet should be sized intrinsically, clamped by a minimum and
  /// maximum height.
  intrinsic('intrinsic');

  const MessagePageSheetCollapsedMode(this.name);

  final String name;
}

enum MessagePageSheetMode {
  collapsed('collapsed'),
  expanded('expanded');

  const MessagePageSheetMode(this.name);

  final String name;
}

enum MessagePageDragMode {
  idle('idle'),
  dragging('dragging');

  const MessagePageDragMode(this.name);

  final String name;
}

/// `Element` for a [MessagePageScaffold] widget.
class MessagePageElement extends RenderObjectElement {
  MessagePageElement(MessagePageScaffold super.widget);

  Element? _content;
  Element? _bottomSheet;

  @override
  MessagePageScaffold get widget => super.widget as MessagePageScaffold;

  @override
  RenderMessagePageScaffold get renderObject => super.renderObject as RenderMessagePageScaffold;

  @override
  void mount(Element? parent, Object? newSlot) {
    messagePageElementLog.info('MessagePageElement - mounting');
    super.mount(parent, newSlot);

    _content = inflateWidget(
      // Run initial build with zero bottom spacing because we haven't
      // run layout on the message editor yet, which determines the content
      // bottom spacing.
      widget.contentBuilder(this, 0),
      _contentSlot,
    );

    _bottomSheet = inflateWidget(widget.bottomSheetBuilder(this), _bottomSheetSlot);
  }

  @override
  void activate() {
    messagePageElementLog.info('MessagePageElement - activating');
    _didActivateSinceLastBuild = false;
    super.activate();
  }

  // Whether this `Element` has been built since the last time `activate()` was run.
  var _didActivateSinceLastBuild = false;

  @override
  void deactivate() {
    messagePageElementLog.info('MessagePageElement - deactivating');
    _didDeactivateSinceLastBuild = false;
    super.deactivate();
  }

  // Whether this `Element` has been built since the last time `deactivate()` was run.
  bool _didDeactivateSinceLastBuild = false;

  @override
  void unmount() {
    messagePageElementLog.info('MessagePageElement - unmounting');
    super.unmount();
  }

  @override
  void markNeedsBuild() {
    super.markNeedsBuild();

    // Invalidate our content child's layout.
    //
    // Typically, nothing needs to be done in this method for children, because
    // typically the superclass marks children as needing to rebuild and that's
    // it. But our content only builds during layout. Therefore, to schedule a
    // build for our content, we need to request a new layout pass, which we do
    // here.
    //
    // Note: `markNeedsBuild()` is called when ancestor inherited widgets change
    //       their value. Failure to honor this method would result in our
    //       subtrees missing rebuilds related to ancestors changing.
    _content?.renderObject?.markNeedsLayout();
  }

  @override
  void performRebuild() {
    super.performRebuild();

    // Rebuild our bottom sheet widget.
    //
    // We don't rebuild our content widget because we only want content to
    // build during layout.
    updateChild(_bottomSheet, widget.bottomSheetBuilder(this), _bottomSheetSlot);
  }

  void buildContent(double bottomSpacing) {
    messagePageElementLog.info('MessagePageElement ($hashCode) - (re)building content');
    widget.controller?.debugMostRecentBottomSpacing.value = bottomSpacing;

    owner!.buildScope(this, () {
      if (_content == null) {
        _content = inflateWidget(
          widget.contentBuilder(this, bottomSpacing),
          _contentSlot,
        );
      } else {
        _content = super.updateChild(
          _content,
          widget.contentBuilder(this, bottomSpacing),
          _contentSlot,
        );
      }
    });

    // The activation and deactivation processes involve visiting children, which
    // we must honor, but the visitation happens some time after the actual call
    // to activate and deactivate. So we remember when activation and deactivation
    // happened, and now that we've built the `_content`, we clear those flags because
    // we assume whatever visitation those processes need to do is now done, since
    // we did a build. To learn more about this situation, look at `visitChildren`.
    _didActivateSinceLastBuild = false;
    _didDeactivateSinceLastBuild = false;
  }

  @override
  void update(MessagePageScaffold newWidget) {
    super.update(newWidget);

    _content = updateChild(_content, widget.contentBuilder(this, 0), _contentSlot) ?? _content;
    _bottomSheet = updateChild(_bottomSheet, widget.bottomSheetBuilder(this), _bottomSheetSlot);
  }

  @override
  Element? updateChild(Element? child, Widget? newWidget, Object? newSlot) {
    if (newSlot == _contentSlot) {
      // Only rebuild the content during layout because it depends upon bottom
      // spacing. Mark needs layout so that we ensure a rebuild happens.
      renderObject.markNeedsLayout();
      return null;
    }

    return super.updateChild(child, newWidget, newSlot);
  }

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    assert(
      _isChatScaffoldSlot(slot!),
      'Invalid ChatScaffold child slot: $slot',
    );

    renderObject.insertChild(child, slot!);
  }

  @override
  void moveRenderObjectChild(
    RenderObject child,
    Object? oldSlot,
    Object? newSlot,
  ) {
    assert(
      child.parent == renderObject,
      'Render object protocol violation - tried to move a render object within a parent that already owns it.',
    );
    assert(
      oldSlot != null,
      'Render object protocol violation - tried to move a render object with a null oldSlot',
    );
    assert(
      newSlot != null,
      'Render object protocol violation - tried to move a render object with a null newSlot',
    );
    assert(
      _isChatScaffoldSlot(oldSlot!),
      'Invalid ChatScaffold child slot: $oldSlot',
    );
    assert(
      _isChatScaffoldSlot(newSlot!),
      'Invalid ChatScaffold child slot: $newSlot',
    );
    assert(
      child is RenderBox,
      'Expected RenderBox child but was given: ${child.runtimeType}',
    );

    if (child is! RenderBox) {
      return;
    }

    if (oldSlot == _contentSlot && newSlot == _bottomSheetSlot) {
      renderObject._bottomSheet = child;
    } else if (oldSlot == _bottomSheetSlot && newSlot == _contentSlot) {
      renderObject._content = child;
    }
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    assert(
      child is RenderBox,
      'Invalid child type (${child.runtimeType}), expected RenderBox',
    );
    assert(
      child.parent == renderObject,
      'Render object protocol violation - tried to remove render object that is not owned by this parent',
    );
    assert(
      slot != null,
      'Render object protocol violation - tried to remove a render object for a null slot',
    );
    assert(
      _isChatScaffoldSlot(slot!),
      'Invalid ChatScaffold child slot: $slot',
    );

    renderObject.removeChild(child, slot!);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_bottomSheet != null) {
      visitor(_bottomSheet!);
    }

    // Building the `_content` is tricky and we're still not sure how to do it
    // correctly. Originally, we refused to visit `_content` when `WidgetsBinding.instance.locked`
    // is `true`. The original warning about this was the following:
    //
    // WARNING: Do not visit content when "locked". If you do, then the pipeline
    // owner will collect that child for rebuild, e.g., for hot reload, and the
    // pipeline owner will tell it to build before the message editor is laid
    // out. We only want the content to build during the layout phase, after the
    // message editor is laid out.
    //
    // However, error stacktraces have been showing up for a while whenever the tree
    // structure adds/removes widgets in the tree. One way to see this was to open the
    // Flutter debugger and enable the widget selector. This adds the widget selector
    // widget to tree, and seems to trigger the bug:
    //
    //        'package:flutter/src/widgets/framework.dart': Failed assertion: line 6164 pos 14:
    //        '_dependents.isEmpty': is not true.
    //
    // This happens because when this `Element` runs `deactivate()`, its super class visits
    // all the children to deactivate them, too. When that happens, we're apparently
    // locked, so we weren't visiting `_content`. This resulted in an error for any
    // `_content` subtree widget that setup an `InheritedWidget` dependency, because
    // that dependency didn't have a chance to release.
    //
    // To deal with deactivation, I tried adding a flag during deactivation so that
    // we visit `_content` during deactivation. I then discovered that the visitation
    // related to deactivation happens sometime after the call to `deactivate()`. So instead
    // of only allowing visitation during `deactivate()`, I tracked whether this `Element`
    // was in a deactivated state, and allowed visitation when in a deactivated state.
    //
    // I then found that there's a similar issue during `activate()`. This also needs to
    // recursively activate the subtree `Element`s, sometime after the call to `activate()`.
    // Therefore, whether activated or deactivated, we need to allow visitation, but we're
    // always either activated or deactivated, so this approach needed to be further adjusted.
    //
    // Presently, when `activate()` or `deactivate()` runs, a flag is set for each one.
    // When either of those flags are `true`, we allow visitation. We reset those flags
    // during the building of `_content`, as a way to recognize when the activation or
    // deactivation process must be finished.
    //
    // For reference, when hot restarting or hot reloading if we don't enable visitation
    // during activation, we get the following error:
    //
    //    The following assertion was thrown during performLayout():
    //    'package:flutter/src/widgets/framework.dart': Failed assertion: line 4323 pos 7: '_lifecycleState ==
    //     _ElementLifecycle.active &&
    //           newWidget != widget &&
    //           Widget.canUpdate(widget, newWidget)': is not true.

    // FIXME: locked is supposed to be private. We're using it as a proxy
    //        indication for when the build owner wants to build. Find an
    //        appropriate way to distinguish this.
    // ignore: invalid_use_of_protected_member
    if (!WidgetsBinding.instance.locked || !_didActivateSinceLastBuild || !_didDeactivateSinceLastBuild) {
      if (_content != null) {
        visitor(_content!);
      }
    }
  }
}

/// `RenderObject` for a [MessagePageScaffold] widget.
///
/// Must be associated with an `Element` of type [MessagePageElement].
class RenderMessagePageScaffold extends RenderBox {
  RenderMessagePageScaffold(
    this._element,
    MessagePageController? controller, {
    required double bottomSheetMinimumTopGap,
    required double bottomSheetMinimumHeight,
    required double bottomSheetCollapsedMaximumHeight,
  })  : _bottomSheetMinimumTopGap = bottomSheetMinimumTopGap,
        _bottomSheetMinimumHeight = bottomSheetMinimumHeight,
        _bottomSheetCollapsedMaximumHeight = bottomSheetCollapsedMaximumHeight {
    _controller = controller ?? MessagePageController();
    _attachToController();
  }

  @override
  void dispose() {
    _element = null;
    super.dispose();
  }

  late Ticker _ticker;
  late VelocityTracker _velocityTracker;
  late Stopwatch _velocityStopwatch;
  late double _expandedHeight;
  late double _previewHeight;
  late double _intrinsicHeight;

  SpringSimulation? _simulation;
  MessagePageSheetMode? _simulationGoalMode;
  double? _simulationGoalHeight;

  MessagePageElement? _element;

  BottomSheetMode? _overrideSheetMode;
  BottomSheetMode get bottomSheetMode {
    if (_overrideSheetMode != null) {
      return _overrideSheetMode!;
    }

    if (_simulation != null) {
      return BottomSheetMode.settling;
    }

    if (_controller.isDragging) {
      return BottomSheetMode.dragging;
    }

    if (_controller.isExpanded) {
      return BottomSheetMode.expanded;
    }

    if (_controller.isPreview) {
      return BottomSheetMode.preview;
    }

    return BottomSheetMode.intrinsic;
  }

  // ignore: avoid_setters_without_getters
  set controller(MessagePageController controller) {
    if (controller == _controller) {
      return;
    }

    _detachFromController();
    _controller = controller;
    _attachToController();
  }

  late MessagePageController _controller;
  MessagePageDragMode _currentDragMode = MessagePageDragMode.idle;
  double? _currentDesiredGlobalTopY;
  double? _desiredDragHeight;
  bool _isExpandingOrCollapsing = false;
  double _animatedHeight = 300;
  double _animatedVelocity = 0;

  void _attachToController() {
    _currentDragMode = _controller.dragMode;
    _controller.addListener(_onControllerChange);

    markNeedsLayout();
  }

  void _onControllerChange() {
    // We might change the controller in this listener call, so we stop
    // listening to the controller during this function.
    _controller.removeListener(_onControllerChange);
    var didChange = false;

    if (_currentDragMode != _controller.dragMode) {
      switch (_controller.dragMode) {
        case MessagePageDragMode.dragging:
          // The user just started dragging.
          _onDragStart();
        case MessagePageDragMode.idle:
          // The user just stopped dragging.
          _onDragEnd();
      }

      _currentDragMode = _controller.dragMode;
      didChange = true;
    }

    if (_controller.dragMode == MessagePageDragMode.dragging &&
        _currentDesiredGlobalTopY != _controller.desiredGlobalTopY) {
      // TODO: don't invalidate layout if we've reached max height and the Y value went higher
      _currentDesiredGlobalTopY = _controller.desiredGlobalTopY;

      final pageGlobalBottom = localToGlobal(Offset(0, size.height)).dy;
      _desiredDragHeight = pageGlobalBottom - max(_currentDesiredGlobalTopY!, _bottomSheetMinimumTopGap);
      _expandedHeight = size.height - _bottomSheetMinimumTopGap;

      _velocityTracker.addPosition(
        _velocityStopwatch.elapsed,
        Offset(0, _currentDesiredGlobalTopY!),
      );

      didChange = true;
    }

    if (didChange) {
      markNeedsLayout();
    }

    // Restore our listener relationship with our controller now that
    // our reaction is finished.
    _controller.addListener(_onControllerChange);
  }

  void _onDragStart() {
    _velocityTracker = VelocityTracker.withKind(PointerDeviceKind.touch);
    _velocityStopwatch = Stopwatch()..start();
  }

  void _onDragEnd() {
    if (SuperKeyboard.instance.mobileGeometry.value.keyboardState == KeyboardState.closing) {
      // To avoid a stuttering collapse animation, when dragging ends and the keyboard
      // is closing, we immediately jump to a collapsed preview mode. If we animated
      // like normal, then on every frame as the keyboard gets shorter, we have to
      // restart the animation simulation, which results in a stuttering, buggy animation.
      _velocityStopwatch.stop();

      _isExpandingOrCollapsing = false;
      _desiredDragHeight = null;
      _controller.desiredSheetMode = MessagePageSheetMode.collapsed;
      _controller.collapsedMode = MessagePageSheetCollapsedMode.preview;
      return;
    }

    _velocityStopwatch.stop();

    final velocity = _velocityTracker.getVelocityEstimate()?.pixelsPerSecond.dy ?? 0;

    _startBottomSheetHeightSimulation(velocity: velocity);
  }

  void _startBottomSheetHeightSimulation({
    required double velocity,
    MessagePageSheetMode? desiredSheetMode,
  }) {
    _ticker.stop();

    final minimizedHeight = switch (_controller.collapsedMode) {
      MessagePageSheetCollapsedMode.preview => _previewHeight,
      MessagePageSheetCollapsedMode.intrinsic => min(_intrinsicHeight, _bottomSheetCollapsedMaximumHeight),
    };

    _controller.desiredSheetMode = desiredSheetMode ??
        (velocity.abs() > 500 //
            ? velocity < 0
                ? MessagePageSheetMode.expanded
                : MessagePageSheetMode.collapsed
            : (_expandedHeight - _desiredDragHeight!).abs() < (_desiredDragHeight! - minimizedHeight).abs()
                ? MessagePageSheetMode.expanded
                : MessagePageSheetMode.collapsed);

    _updateBottomSheetHeightSimulation(velocity: velocity);
  }

  /// Replaces a running bottom sheet height simulation with a newly computed
  /// simulation based on the current render object metrics.
  ///
  /// This method can be called even if no `_simulation` currently exists.
  /// However, callers must ensure that `_controller.desiredSheetMode` is
  /// already set to the desired value. This method doesn't try to alter the
  /// desired sheet mode.
  void _updateBottomSheetHeightSimulation({
    required double velocity,
  }) {
    final minimizedHeight = switch (_controller.collapsedMode) {
      MessagePageSheetCollapsedMode.preview => _previewHeight,
      MessagePageSheetCollapsedMode.intrinsic => min(_intrinsicHeight, _bottomSheetCollapsedMaximumHeight),
    };

    _controller.isSliding = true;

    final startHeight = _bottomSheet!.size.height;
    _simulationGoalMode = _controller.desiredSheetMode;
    final newSimulationGoalHeight =
        _simulationGoalMode! == MessagePageSheetMode.expanded ? _expandedHeight : minimizedHeight;
    if ((newSimulationGoalHeight - startHeight).abs() < 1) {
      // We're already at the destination. Fizzle.
      _animatedHeight = newSimulationGoalHeight;
      _animatedVelocity = 0;
      _isExpandingOrCollapsing = false;
      _desiredDragHeight = null;
      _ticker.stop();
      return;
    }
    if (newSimulationGoalHeight == _simulationGoalHeight) {
      // We're already simulating to this height. We short-circuit when the goal
      // hasn't changed so that we don't get rapidly oscillating simulation artifacts.
      return;
    }
    _simulationGoalHeight = newSimulationGoalHeight;
    _isExpandingOrCollapsing = true;

    _ticker.stop();

    messagePageLayoutLog.info('Creating expand/collapse simulation:');
    messagePageLayoutLog.info(
      ' - Desired sheet mode: ${_controller.desiredSheetMode}',
    );
    messagePageLayoutLog.info(' - Minimized height: $minimizedHeight');
    messagePageLayoutLog.info(' - Expanded height: $_expandedHeight');
    messagePageLayoutLog.info(
      ' - Drag height on release: $_desiredDragHeight',
    );
    messagePageLayoutLog.info(' - Final height: $_simulationGoalHeight');
    messagePageLayoutLog.info(' - Initial velocity: $velocity');

    _simulation = SpringSimulation(
      const SpringDescription(
        mass: 1,
        stiffness: 500,
        damping: 45,
      ),
      startHeight, // Start value
      _simulationGoalHeight!, // End value
      // Invert velocity because we measured velocity moving down the screen, but we
      // want to apply velocity to the height of the sheet. A positive screen velocity
      // corresponds to a negative sheet height velocity.
      -velocity, // Initial velocity.
    );

    _ticker.start();
  }

  void _detachFromController() {
    _controller.removeListener(_onControllerChange);

    _currentDragMode = MessagePageDragMode.idle;
    _desiredDragHeight = null;
    _currentDesiredGlobalTopY = null;
  }

  RenderBox? _content;

  RenderBox? _bottomSheet;

  /// The smallest allowable gap between the top of the editor and the top of
  /// the screen.
  ///
  /// If the user drags higher than this point, the editor will remain at a
  /// height that preserves this gap.
  // ignore: avoid_setters_without_getters
  set bottomSheetMinimumTopGap(double newValue) {
    if (newValue == _bottomSheetMinimumTopGap) {
      return;
    }

    _bottomSheetMinimumTopGap = newValue;

    // FIXME: Only invalidate layout if this change impacts the current rendering.
    markNeedsLayout();
  }

  double _bottomSheetMinimumTopGap;

  // ignore: avoid_setters_without_getters
  set bottomSheetMinimumHeight(double newValue) {
    if (newValue == _bottomSheetMinimumHeight) {
      return;
    }

    _bottomSheetMinimumHeight = newValue;

    // FIXME: Only invalidate layout if this change impacts the current rendering.
    markNeedsLayout();
  }

  double _bottomSheetMinimumHeight;

  set bottomSheetMaximumHeight(double newValue) {
    if (newValue == _bottomSheetMaximumHeight) {
      return;
    }

    _bottomSheetMaximumHeight = newValue;

    // FIXME: Only invalidate layout if this change impacts the current rendering.
    markNeedsLayout();
  }

  double _bottomSheetMaximumHeight = double.infinity;

  set bottomSheetCollapsedMaximumHeight(double newValue) {
    if (newValue == _bottomSheetCollapsedMaximumHeight) {
      return;
    }

    _bottomSheetCollapsedMaximumHeight = newValue;

    // FIXME: Only invalidate layout if this change impacts the current rendering.
    markNeedsLayout();
  }

  double _bottomSheetCollapsedMaximumHeight = double.infinity;

  /// Whether this render object's layout information or its content
  /// layout information is dirty.
  ///
  /// This is set to `true` when `markNeedsLayout` is called and it's
  /// set to `false` after laying out the content.
  bool get bottomSheetNeedsLayout => _bottomSheetNeedsLayout;
  bool _bottomSheetNeedsLayout = true;

  /// Whether we are at the middle of a [performLayout] call.
  bool _runningLayout = false;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);

    _ticker = Ticker(_onExpandCollapseTick);

    visitChildren((child) {
      child.attach(owner);
    });
  }

  void _onExpandCollapseTick(Duration elapsedTime) {
    final seconds = elapsedTime.inMilliseconds / 1000;
    _animatedHeight = _simulation!.x(seconds).clamp(_bottomSheetMinimumHeight, _bottomSheetMaximumHeight);
    _animatedVelocity = _simulation!.dx(seconds);

    if (_simulation!.isDone(seconds)) {
      _ticker.stop();

      _simulation = null;
      _simulationGoalMode = null;
      _simulationGoalHeight = null;
      _animatedVelocity = 0;

      _isExpandingOrCollapsing = false;
      _currentDesiredGlobalTopY = null;
      _desiredDragHeight = null;

      _controller.isSliding = false;
    }

    markNeedsLayout();
  }

  @override
  void detach() {
    // IMPORTANT: we must detach ourselves before detaching our children.
    // This is a Flutter framework requirement.
    super.detach();

    _ticker.dispose();

    // Detach our children.
    visitChildren((child) {
      child.detach();
    });
  }

  @override
  void markNeedsLayout() {
    super.markNeedsLayout();

    if (_runningLayout) {
      // We are already in a layout phase. When we call
      // ChatScaffoldElement.buildLayers, markNeedsLayout is called again. We
      // don't want to mark the message editor as dirty, because otherwise the
      // content will never build.
      return;
    }
    _bottomSheetNeedsLayout = true;
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    final childDiagnostics = <DiagnosticsNode>[];

    if (_content != null) {
      childDiagnostics.add(_content!.toDiagnosticsNode(name: 'content'));
    }
    if (_bottomSheet != null) {
      childDiagnostics.add(_bottomSheet!.toDiagnosticsNode(name: 'message_editor'));
    }

    return childDiagnostics;
  }

  void insertChild(RenderObject child, Object slot) {
    assert(
      _isChatScaffoldSlot(slot),
      'Render object protocol violation - tried to insert child for invalid slot ($slot)',
    );

    if (slot == _contentSlot) {
      _content = child as RenderBox;
    } else if (slot == _bottomSheetSlot) {
      _bottomSheet = child as RenderBox;
    }

    adoptChild(child);
  }

  void removeChild(RenderObject child, Object slot) {
    assert(
      _isChatScaffoldSlot(slot),
      'Render object protocol violation - tried to remove a child for an invalid slot ($slot)',
    );

    if (slot == _contentSlot) {
      _content = null;
    } else if (slot == _bottomSheetSlot) {
      _bottomSheet = null;
    }

    dropChild(child);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (_content != null) {
      visitor(_content!);
    }
    if (_bottomSheet != null) {
      visitor(_bottomSheet!);
    }
  }

  @override
  void performLayout() {
    messagePageLayoutLog.info('---------- LAYOUT -------------');
    messagePageLayoutLog.info('Laying out RenderChatScaffold');
    messagePageLayoutLog
        .info('Sheet mode: ${_controller.desiredSheetMode}, collapsed mode: ${_controller.collapsedMode}');
    if (_content == null) {
      size = Size.zero;
      _bottomSheetNeedsLayout = false;
      return;
    }

    _runningLayout = true;

    size = constraints.biggest;
    _bottomSheetMaximumHeight = size.height - _bottomSheetMinimumTopGap;

    messagePageLayoutLog.info(
      "Measuring the bottom sheet's preview height",
    );
    // Do a throw-away layout pass to get the preview height of the bottom
    // sheet, bounded within its min/max height.
    _overrideSheetMode = BottomSheetMode.preview;
    _previewHeight = _bottomSheet!.computeDryLayout(constraints.copyWith(minHeight: 0)).height;

    // Switch back to a real layout pass.
    _overrideSheetMode = null;
    messagePageLayoutLog.info(
      ' - Bottom sheet bounded preview height: $_previewHeight, min height: $_bottomSheetMinimumHeight, max height: $_bottomSheetMaximumHeight',
    );

    messagePageLayoutLog.info(
      "Measuring the bottom sheet's intrinsic height",
    );
    // Do a throw-away layout pass to get the intrinsic height of the bottom sheet.
    _intrinsicHeight = _calculateBoundedIntrinsicHeight(
      constraints.copyWith(minHeight: 0),
    );
    messagePageLayoutLog.info(
      ' - Bottom sheet bounded intrinsic height: $_intrinsicHeight, min height: $_bottomSheetMinimumHeight, max height: $_bottomSheetMaximumHeight',
    );

    final isDragging = !_isExpandingOrCollapsing && _desiredDragHeight != null;

    final minimizedHeight = switch (_controller.collapsedMode) {
      MessagePageSheetCollapsedMode.preview => _previewHeight,
      MessagePageSheetCollapsedMode.intrinsic => _intrinsicHeight,
    };

    // Max height depends on whether we're collapsed or expanded.
    final bottomSheetConstraints = constraints.copyWith(
      minHeight: minimizedHeight,
      maxHeight: _bottomSheetMaximumHeight,
    );

    if (_isExpandingOrCollapsing) {
      messagePageLayoutLog.info('>>>>>>>> Expanding or collapsing animation');
      // We may have started animating with the keyboard up and since then it
      // has closed, or vis-a-versa. Check for any changes in our destination
      // height. If it's changed, recreate the simulation to stop at the new
      // destination.
      final currentDestinationHeight = switch (_simulationGoalMode!) {
        MessagePageSheetMode.collapsed => switch (_controller.collapsedMode) {
            MessagePageSheetCollapsedMode.preview => _previewHeight,
            MessagePageSheetCollapsedMode.intrinsic => _intrinsicHeight,
          },
        MessagePageSheetMode.expanded => _bottomSheetMaximumHeight,
      };
      if (currentDestinationHeight != _simulationGoalHeight) {
        // A simulation is running. It's destination height no longer matches
        // the destination height that we want. Update the simulation with newly
        // computed metrics.
        _updateBottomSheetHeightSimulation(velocity: _animatedVelocity);
      }

      final minimumHeight = min(
          _controller.collapsedMode == MessagePageSheetCollapsedMode.preview ? _previewHeight : _intrinsicHeight,
          _bottomSheetCollapsedMaximumHeight);
      final animatedHeight = _animatedHeight.clamp(minimumHeight, _bottomSheetMaximumHeight);

      _bottomSheet!.layout(
        bottomSheetConstraints.copyWith(
          minHeight: max(animatedHeight - 1, 0),
          // ^ prevent a layout boundary
          maxHeight: animatedHeight,
        ),
        parentUsesSize: true,
      );
    } else if (isDragging) {
      messagePageLayoutLog.info('>>>>>>>> User dragging');
      messagePageLayoutLog.info(
        ' - drag height: $_desiredDragHeight, minimized height: $minimizedHeight',
      );

      final minimumHeight = min(minimizedHeight, _bottomSheetCollapsedMaximumHeight);

      final strictHeight = _desiredDragHeight!.clamp(minimumHeight, _bottomSheetMaximumHeight);

      messagePageLayoutLog.info(' - bounded drag height: $strictHeight');
      _bottomSheet!.layout(
        bottomSheetConstraints.copyWith(
          minHeight: max(strictHeight - 1, 0),
          // ^ prevent layout boundary
          maxHeight: strictHeight,
        ),
        parentUsesSize: true,
      );
    } else if (_controller.desiredSheetMode == MessagePageSheetMode.expanded) {
      messagePageLayoutLog.info('>>>>>>>> Stationary expanded');
      messagePageLayoutLog.info(
        'Running layout and forcing editor height to the max: $_expandedHeight',
      );

      _bottomSheet!.layout(
        bottomSheetConstraints.copyWith(
          minHeight: max(_expandedHeight - 1, 0),
          // ^ Prevent a layout boundary.
          maxHeight: _expandedHeight,
        ),
        parentUsesSize: true,
      );
    } else {
      messagePageLayoutLog.info('>>>>>>>> Minimized');
      messagePageLayoutLog.info('Running standard editor layout with constraints: $bottomSheetConstraints');
      _bottomSheet!.layout(
        bottomSheetConstraints.copyWith(
          minHeight: 0,
          maxHeight: min(_bottomSheetCollapsedMaximumHeight, _bottomSheetMaximumHeight),
        ),
        parentUsesSize: true,
      );
    }

    (_bottomSheet!.parentData! as BoxParentData).offset = Offset(0, size.height - _bottomSheet!.size.height);
    _bottomSheetNeedsLayout = false;
    messagePageLayoutLog.info('Bottom sheet height: ${_bottomSheet!.size.height}');

    // Now that we know the size of the message editor, build the content based
    // on the bottom spacing needed to push above the editor.
    final bottomSpacing = _bottomSheet!.size.height;
    messagePageLayoutLog.info('');
    messagePageLayoutLog.info('Building chat scaffold content');
    invokeLayoutCallback((constraints) {
      _element!.buildContent(bottomSpacing);
    });
    messagePageLayoutLog.info('Laying out chat scaffold content');
    _content!.layout(constraints, parentUsesSize: true);
    messagePageLayoutLog.info('Content layout size: ${_content!.size}');

    _runningLayout = false;
    messagePageLayoutLog.info('Done laying out RenderChatScaffold');
    messagePageLayoutLog.info('---------- END LAYOUT ---------');
  }

  double _calculateBoundedIntrinsicHeight(BoxConstraints constraints) {
    messagePageLayoutLog.info('Running dry layout on bottom sheet content to find the intrinsic height...');
    messagePageLayoutLog.info(' - Bottom sheet constraints: $constraints');
    messagePageLayoutLog.info(' - Controller desired sheet mode: ${_controller.collapsedMode}');
    _overrideSheetMode = BottomSheetMode.intrinsic;
    messagePageLayoutLog.info(' - Override sheet mode: $_overrideSheetMode');

    final bottomSheetHeight = _bottomSheet!
        .computeDryLayout(
          constraints.copyWith(minHeight: 0, maxHeight: double.infinity),
        )
        .height;

    _overrideSheetMode = null;
    messagePageLayoutLog.info(" - Child's self-chosen height is: $bottomSheetHeight");
    messagePageLayoutLog.info(
      " - Clamping child's height within [$_bottomSheetMinimumHeight, $_bottomSheetMaximumHeight]",
    );

    final boundedIntrinsicHeight = bottomSheetHeight.clamp(
      _bottomSheetMinimumHeight,
      _bottomSheetMaximumHeight,
    );
    messagePageLayoutLog.info(
      ' - Bottom sheet intrinsic bounded height: $boundedIntrinsicHeight',
    );
    return boundedIntrinsicHeight;
  }

  @override
  bool hitTestChildren(
    BoxHitTestResult result, {
    required Offset position,
  }) {
    // First, hit-test the message editor, which sits on top of the
    // content.
    if (_bottomSheet != null) {
      final childParentData = _bottomSheet!.parentData! as BoxParentData;

      final didHit = result.addWithPaintOffset(
        offset: childParentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          return _bottomSheet!.hitTest(result, position: transformed);
        },
      );

      if (didHit) {
        return true;
      }
    }

    // Second, hit-test the content, which sits beneath the message
    // editor.
    if (_content != null) {
      final didHit = _content!.hitTest(result, position: position);
      if (didHit) {
        // NOTE: I'm not sure if we're supposed to report ourselves when a child
        //       is hit, or if just the child does that.
        result.add(BoxHitTestEntry(this, position));
        return true;
      }
    }

    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    messagePagePaintLog.info('---------- PAINT ------------');
    if (_content != null) {
      messagePagePaintLog.info('Painting content');
      context.paintChild(_content!, offset);
    }

    if (_bottomSheet != null) {
      messagePagePaintLog.info(
        'Painting message editor - y-offset: ${size.height - _bottomSheet!.size.height}',
      );
      context.paintChild(
        _bottomSheet!,
        offset + (_bottomSheet!.parentData! as BoxParentData).offset,
      );
    }
    messagePagePaintLog.info('---------- END PAINT ------------');
  }

  @override
  void setupParentData(covariant RenderObject child) {
    child.parentData = BoxParentData();
  }
}

bool _isChatScaffoldSlot(Object slot) => slot == _contentSlot || slot == _bottomSheetSlot;

const _contentSlot = 'content';
const _bottomSheetSlot = 'bottom_sheet';

/// Widget that switches its child constraints between a [previewHeight],
/// intrinsic height, and filled height.
///
/// This widget is intended to be used around a `SuperEditor`, within the bottom
/// sheet in a [MessagePageScaffold] to size the `SuperEditor` correctly based
/// on whether the editor is in preview mode, collapsed, being dragged,
/// is animating, or is expanded.
class BottomSheetEditorHeight extends SingleChildRenderObjectWidget {
  const BottomSheetEditorHeight({
    required this.previewHeight,
    super.key,
    super.child,
  });

  /// The exact height to be used for the editor when in preview mode.
  ///
  /// Overflowing content is clipped.
  final double previewHeight;

  @override
  RenderMessageEditorHeight createRenderObject(BuildContext context) {
    return RenderMessageEditorHeight(
      previewHeight: previewHeight,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMessageEditorHeight renderObject,
  ) {
    renderObject.previewHeight = previewHeight;
  }
}

class RenderMessageEditorHeight extends RenderBox
    with RenderObjectWithChildMixin<RenderBox>, RenderProxyBoxMixin<RenderBox> {
  RenderMessageEditorHeight({
    required double previewHeight,
  }) : _previewHeight = previewHeight;

  double _previewHeight;
  // ignore: avoid_setters_without_getters
  set previewHeight(double newValue) {
    if (newValue == _previewHeight) {
      return;
    }

    _previewHeight = newValue;
    markNeedsLayout();
  }

  @override
  void markNeedsLayout() {
    super.markNeedsLayout();

    // Force our ancestor scaffold to invalidate layout, too.
    //
    // There was an issue when integrating this within a client app.
    // For example, a previous bug:
    //  1. Open the editor
    //  2. Fill it with enough content to push to max height
    //  3. Drag down to close the keyboard
    //  Bug: The sheet stays expanded.
    //
    // It was found that while this RenderMessageEditorHeight was running
    // layout correctly in this situation, the MessagePageScaffold wasn't
    // running layout, which caused the sheet to stay at its previous height.
    //
    // This problem was not found in the MessagePageScaffold demo app. Not sure
    // what the difference was.
    //
    // If we find a missing layout invalidation for MessagePageScaffold, and we
    // make this call superfluous, then remove this.
    final ancestorMessagePageScaffold = _findAncestorMessagePageScaffold();
    // Ancestor scaffold might be null during various lifecycle events, e.g.,
    // `dropChild()` calls `markNeedsLayout()`, but when we're dropping our
    // children, we have likely already been dropped by our parent, too.
    if (ancestorMessagePageScaffold != null) {
      ancestorMessagePageScaffold.markNeedsLayout();
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    messageEditorHeightLog.info('MessageEditorHeight - computeDryLayout()');
    messageEditorHeightLog.info(' - Constraints: $constraints');

    final ancestorChatScaffold = _findAncestorMessagePageScaffold();
    messageEditorHeightLog.info(' - Ancestor chat scaffold: $ancestorChatScaffold');

    final heightMode = ancestorChatScaffold?.bottomSheetMode;
    if (heightMode == null) {
      messageEditorHeightLog.info(
        " - Couldn't find an ancestor chat scaffold. Deferring to natural layout.",
      );
      return _doIntrinsicLayout(constraints, doDryLayout: true);
    }

    messageEditorHeightLog.info(
      ' - Bottom sheet mode from chat scaffold: $heightMode',
    );

    switch (heightMode) {
      case BottomSheetMode.preview:
        // Preview mode imposes a specific height on the bottom sheet.
        messageEditorHeightLog.info(' - Desired bottom sheet preview height: $_previewHeight');

        // We want to be a specific height. Get as close as we can.
        final constrainedHeight = constraints.constrainDimensions(
          double.infinity,
          _previewHeight,
        );

        messageEditorHeightLog.info(' - Constrained bottom sheet preview height: $constrainedHeight');
        return constrainedHeight;
      case BottomSheetMode.dragging:
      case BottomSheetMode.settling:
      case BottomSheetMode.expanded:
      case BottomSheetMode.intrinsic:
        // In regular layout, dragging, settling, and expanded would impose
        // their own height on us. However, the purpose of dry layout is to
        // report our natural size. Therefore, in all of these cases, we run
        // intrinsic size layout.
        return _doIntrinsicLayout(constraints, doDryLayout: true);
    }
  }

  @override
  void performLayout() {
    messageEditorHeightLog.info('MessageEditorHeight - performLayout()');
    messageEditorHeightLog.info(' - Constraints: $constraints');

    final ancestorChatScaffold = _findAncestorMessagePageScaffold();
    messageEditorHeightLog.info(' - Ancestor chat scaffold: $ancestorChatScaffold');

    final heightMode = ancestorChatScaffold?.bottomSheetMode;
    if (heightMode == null) {
      messageEditorHeightLog.info(
        " - Couldn't find an ancestor chat scaffold. Deferring to natural layout.",
      );
      size = _doIntrinsicLayout(constraints, doDryLayout: true);
      messageEditorHeightLog.info(' - Our reported size: $size');
      return;
    }

    messageEditorHeightLog.info(
      ' - Bottom sheet mode from chat scaffold: $heightMode',
    );

    switch (heightMode) {
      case BottomSheetMode.preview:
        // Preview mode imposes a specific height on the bottom sheet.
        messageEditorHeightLog.info(' - Forcing bottom sheet to preview height: $_previewHeight');

        // We want to be a specific height. Get as close as we can.
        size = constraints.constrainDimensions(
          double.infinity,
          _previewHeight,
        );
        messageEditorHeightLog.info(
          ' - Constraints constrained to preview height: $_previewHeight',
        );
        child?.layout(
          constraints.copyWith(
            minHeight: max(size.height - 1, 0),
            // ^ prevent layout boundary
            maxHeight: size.height,
          ),
          parentUsesSize: true,
        );

        messageEditorHeightLog.info(
          ' - Child preview height: ${child?.size.height}',
        );
        return;
      case BottomSheetMode.dragging:
      case BottomSheetMode.settling:
      case BottomSheetMode.expanded:
        // Whether dragging, animating, or fully expanded, these conditions
        // want to stipulate exactly how tall the bottom sheet should be.
        messageEditorHeightLog.info(' - Mode $heightMode - Filling available height');
        if (!constraints.hasBoundedHeight) {
          messageEditorHeightLog.info('   - No bounded height was provided. Deferring to child');
          size = _doIntrinsicLayout(constraints);
          messageEditorHeightLog.info(' - Our reported size: $size');
          return;
        }

        messageEditorHeightLog.info(
          ' - Using our given bounded height: ${constraints.maxHeight}',
        );
        // The available height is bounded. Fill it.
        size = constraints.biggest;
        child?.layout(
          constraints.copyWith(
            minHeight: max(size.height - 1, 0),
            // ^ Prevent a layout boundary.
            maxHeight: size.height,
          ),
          parentUsesSize: true,
        );
        messageEditorHeightLog.info(
          ' - Child filled height: ${child?.size.height}',
        );
        return;
      case BottomSheetMode.intrinsic:
        size = _doIntrinsicLayout(constraints);
        messageEditorHeightLog.info(' - Our reported size: $size');
        return;
    }
  }

  Size _doIntrinsicLayout(
    BoxConstraints constraints, {
    bool doDryLayout = false,
  }) {
    messageEditorHeightLog.info(' - Measuring child intrinsic height. Constraints: $constraints');

    final child = this.child;
    if (child == null) {
      return constraints.constrain(Size(constraints.constrainWidth(), 0));
    }

    var childConstraints = constraints.copyWith(
      minWidth: constraints.maxWidth,
      minHeight: 0,
      maxHeight: constraints.maxHeight,
    );

    late final Size intrinsicSize;
    if (doDryLayout) {
      intrinsicSize = child.computeDryLayout(childConstraints);
    } else {
      child.layout(childConstraints, parentUsesSize: true);
      intrinsicSize = child.size;
    }

    messageEditorHeightLog.info(' - Child intrinsic height: ${intrinsicSize.height}');
    return constraints.constrain(intrinsicSize);
  }

  RenderMessagePageScaffold? _findAncestorMessagePageScaffold() {
    var ancestor = parent;
    while (ancestor != null && ancestor is! RenderMessagePageScaffold) {
      ancestor = ancestor.parent;
    }

    return ancestor as RenderMessagePageScaffold?;
  }
}
