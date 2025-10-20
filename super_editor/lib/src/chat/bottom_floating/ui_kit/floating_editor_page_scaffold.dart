import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_keyboard/super_keyboard.dart';

/// A page scaffold that displays page content in a [child], with a floating editor sitting above and at
/// the bottom of the [child].
class FloatingEditorPageScaffold<PanelType> extends StatefulWidget {
  const FloatingEditorPageScaffold({
    super.key,
    this.pageController,
    this.softwareKeyboardController,
    required this.pageBuilder,
    required this.editorSheet,
    this.keyboardPanelBuilder,
    this.shadowSheetBanner,
    this.style = const FloatingEditorStyle(),
  });

  final FloatingEditorPageController<PanelType>? pageController;
  final SoftwareKeyboardController? softwareKeyboardController;

  final FloatingEditorContentBuilder pageBuilder;

  final Widget? shadowSheetBanner;
  final Widget editorSheet;

  final KeyboardPanelBuilder<PanelType>? keyboardPanelBuilder;

  final FloatingEditorStyle style;

  @override
  State<FloatingEditorPageScaffold> createState() => _FloatingEditorPageScaffoldState<PanelType>();
}

class _FloatingEditorPageScaffoldState<PanelType> extends State<FloatingEditorPageScaffold<PanelType>>
    with TickerProviderStateMixin {
  late FloatingEditorPageController<PanelType> _pageController;
  late SoftwareKeyboardController _softwareKeyboardController;

  @override
  void initState() {
    super.initState();
    _softwareKeyboardController = widget.softwareKeyboardController ?? SoftwareKeyboardController();
    _pageController = widget.pageController ?? FloatingEditorPageController<PanelType>(_softwareKeyboardController);
  }

  @override
  void didUpdateWidget(covariant FloatingEditorPageScaffold<PanelType> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.pageController != oldWidget.pageController) {
      if (oldWidget.pageController == null) {
        _pageController.dispose();
      }
      _pageController = widget.pageController ?? FloatingEditorPageController<PanelType>(_softwareKeyboardController);
    }

    if (widget.softwareKeyboardController != oldWidget.softwareKeyboardController) {
      _softwareKeyboardController = widget.softwareKeyboardController ?? SoftwareKeyboardController();
    }
  }

  @override
  void dispose() {
    if (widget.pageController == null) {
      _pageController.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AboveKeyboardMessagePageScaffold<PanelType>(
      vsync: this,
      pageController: _pageController,
      contentBuilder: (contentContext, pageGeometry) {
        return MediaQuery.removePadding(
          context: contentContext,
          removeBottom: true,
          // ^ Remove bottom padding because if we don't, when the keyboard
          //   opens to edit the bottom sheet, this content behind the bottom
          //   sheet adds some phantom space at the bottom, slightly pushing
          //   it up for no reason.
          child: widget.pageBuilder(contentContext, pageGeometry),
        );
      },
      bottomSheetBuilder: (messageContext) {
        return FloatingChatBottomSheet(
          child: BottomFloatingChatSheet(
            messagePageController: _pageController,
            editorSheet: widget.editorSheet,
            shadowSheetBanner: widget.shadowSheetBanner,
            style: widget.style,
          ),
        );

        // // TODO: Figure out where this KeyboardScaffoldSafeArea goes and why. We have a number of different
        // //       scaffolds and sheets being composed. Where exactly do we want to push up above the keyboard,
        // //       and where do we need to place a KeyboardScaffoldSafeArea to satisfy the expectations of a
        // //       KeyboardPanelScaffold?
        // return KeyboardScaffoldSafeArea(
        //   child: FloatingChatBottomSheet(
        //     child: BottomFloatingChatSheet(
        //       messagePageController: _messagePageController,
        //       editorSheet: widget.editorSheet,
        //       shadowSheetBanner: widget.shadowSheetBanner,
        //       style: widget.style,
        //     ),
        //   ),
        // );
      },
      bottomSheetMinimumTopGap: widget.style.margin.top,
      bottomSheetMinimumHeight: widget.style.collapsedMinimumHeight,
      bottomSheetCollapsedMaximumHeight: widget.style.collapsedMaximumHeight,
      keyboardPanelBuilder: widget.keyboardPanelBuilder,
    );
  }
}

class FloatingEditorPageController<PanelType> extends MessagePageController {
  FloatingEditorPageController(
    this.softwareKeyboardController,
  );

  @override
  void dispose() {
    detach();
    super.dispose();
  }

  final SoftwareKeyboardController softwareKeyboardController;

  FloatingEditorPageControllerDelegate<PanelType>? _delegate;

  /// Whether this controller is currently attached to a delegate that
  /// knows how to open/close the software keyboard and keyboard panel.
  bool get hasDelegate => _delegate != null;

  /// Attaches this controller to a delegate that knows how to show a toolbar, open and
  /// close the software keyboard, and the keyboard panel.
  void attach(FloatingEditorPageControllerDelegate<PanelType> delegate) {
    editorImeLog.finer("[KeyboardPanelController] - Attaching to delegate: $delegate");
    _delegate = delegate;

    // TODO: Do we really need listener proxying? We have clients that want to listen to this
    //       controller, but we're notifying listeners from the delegate (render object). We should
    //       probably rework this to become simpler and more clear.
    for (final listener in _controllerListeners) {
      _delegate?.addListener(listener);
    }
  }

  /// Detaches this controller from its delegate.
  ///
  /// This controller can't open or close the software keyboard, or keyboard panel, while
  /// detached from a delegate that knows how to make that happen.
  void detach() {
    editorImeLog.finer("[KeyboardPanelController] - Detaching from delegate: $_delegate");
    for (final listener in _controllerListeners) {
      _delegate?.removeListener(listener);
    }

    _delegate = null;
  }

  /// Whether the delegate currently wants a keyboard panel to be open.
  ///
  /// This is expressed as "want" because the keyboard panel has transitory states,
  /// like opening and closing. Therefore, this property doesn't reflect actual
  /// visibility.
  bool get isSoftwareKeyboardOpen => _delegate?.isKeyboardPanelOpen ?? false;

  /// Shows the software keyboard, if it's hidden.
  void showSoftwareKeyboard() {
    _delegate?.showSoftwareKeyboard();
  }

  /// Hides (doesn't close) the software keyboard, if it's open.
  void hideSoftwareKeyboard() {
    _delegate?.hideSoftwareKeyboard();
  }

  /// Whether the delegate currently wants a keyboard panel to be open.
  ///
  /// This is expressed as "want" because the keyboard panel has transitory states,
  /// like opening and closing. Therefore, this property doesn't reflect actual
  /// visibility.
  bool get isKeyboardPanelOpen => _delegate?.isKeyboardPanelOpen ?? false;

  PanelType? get openPanel => _delegate?.openPanel;

  /// Shows the keyboard panel, if it's closed, and hides (doesn't close) the
  /// software keyboard, if it's open.
  void showKeyboardPanel(PanelType panel) => _delegate?.showKeyboardPanel(panel);

  /// Opens or closes the given [panel], depending on whether it's already open.
  ///
  /// If the panel is closed, the software keyboard will be opened.
  void toggleKeyboardPanel(PanelType panel) => _delegate?.toggleKeyboardPanel(panel);

  /// Hides the keyboard panel, if it's open.
  void hideKeyboardPanel() {
    _delegate?.hideKeyboardPanel();
  }

  /// Closes the software keyboard if it's open, or closes the keyboard panel if
  /// it's open, and fully closes the keyboard (IME) connection.
  void closeKeyboardAndPanel() {
    _delegate?.closeKeyboardAndPanel();
  }

  final _controllerListeners = <VoidCallback>{};

  @override
  void addListener(VoidCallback listener) {
    _controllerListeners.add(listener);
    _delegate?.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _controllerListeners.remove(listener);
    _delegate?.removeListener(listener);
  }

  /// The height that we believe the keyboard occupies.
  ///
  /// This is a debug value and should only be used for logging.
  final debugBestGuessKeyboardHeight = ValueNotifier<double?>(null);
}

abstract interface class FloatingEditorPageControllerDelegate<PanelType> implements ChangeNotifier {
  /// Whether this delegate currently wants the software keyboard to be open.
  ///
  /// This is expressed as "want" because the keyboard has transitory states,
  /// like opening and closing. Therefore, this property doesn't reflect actual
  /// visibility.
  bool get isSoftwareKeyboardOpen;

  /// Shows the software keyboard, if it's hidden.
  void showSoftwareKeyboard();

  /// Hides (doesn't close) the software keyboard, if it's open.
  void hideSoftwareKeyboard();

  /// Whether this delegate currently wants a keyboard panel to be open.
  ///
  /// This is expressed as "want" because the keyboard panel has transitory states,
  /// like opening and closing. Therefore, this property doesn't reflect actual
  /// visibility.
  bool get isKeyboardPanelOpen;

  PanelType? get openPanel;

  /// Shows the keyboard panel, if it's closed, and hides (doesn't close) the
  /// software keyboard, if it's open.
  void showKeyboardPanel(PanelType panel);

  /// Opens or closes the given [panel], depending on whether it's already open.
  ///
  /// If the panel is closed, the software keyboard will be opened.
  void toggleKeyboardPanel(PanelType panel);

  /// Hides the keyboard panel, if it's open.
  void hideKeyboardPanel();

  /// Closes the software keyboard if it's open, or closes the keyboard panel if
  /// it's open, and fully closes the keyboard (IME) connection.
  void closeKeyboardAndPanel();
}

/// A page scaffold that displays page content in a [child], with a floating editor sitting above and at
/// the bottom of the [child].
class _AboveKeyboardMessagePageScaffold<PanelType> extends RenderObjectWidget {
  const _AboveKeyboardMessagePageScaffold({
    super.key,
    required this.vsync,
    required this.pageController,
    required this.contentBuilder,
    required this.bottomSheetBuilder,
    this.bottomSheetMinimumTopGap = 200,
    this.bottomSheetMinimumHeight = 150,
    this.bottomSheetCollapsedMaximumHeight = double.infinity,
    this.keyboardPanelBuilder,
    this.fallbackKeyboardHeight = 250.0,
  });

  final TickerProvider vsync;

  final FloatingEditorPageController<PanelType> pageController;

  /// Builds the content within this scaffold, e.g., a chat conversation thread.
  final FloatingEditorContentBuilder contentBuilder;

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

  final KeyboardPanelBuilder<PanelType>? keyboardPanelBuilder;

  final double fallbackKeyboardHeight;

  @override
  RenderObjectElement createElement() {
    return _AboveKeyboardMessagePageElement<PanelType>(this);
  }

  @override
  _RenderAboveKeyboardPageScaffold<PanelType> createRenderObject(BuildContext context) {
    return _RenderAboveKeyboardPageScaffold<PanelType>(
      context as _AboveKeyboardMessagePageElement,
      pageController,
      vsync: vsync,
      viewId: View.of(context).viewId,
      bottomSheetMinimumTopGap: bottomSheetMinimumTopGap,
      bottomSheetMinimumHeight: bottomSheetMinimumHeight,
      bottomSheetCollapsedMaximumHeight: bottomSheetCollapsedMaximumHeight,
      mediaQueryBottomInsets: MediaQuery.viewInsetsOf(context).bottom,
      mediaQueryBottomPadding: MediaQuery.viewPaddingOf(context).bottom,
      fallbackKeyboardHeight: fallbackKeyboardHeight,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderAboveKeyboardPageScaffold<PanelType> renderObject) {
    renderObject
      ..pageController = pageController
      ..viewId = View.of(context).viewId
      ..bottomSheetMinimumTopGap = bottomSheetMinimumTopGap
      ..bottomSheetMinimumHeight = bottomSheetMinimumHeight
      ..bottomSheetCollapsedMaximumHeight = bottomSheetCollapsedMaximumHeight
      ..mediaQueryBottomInsets = MediaQuery.viewInsetsOf(context).bottom
      .._mediaQueryBottomPadding = MediaQuery.viewPaddingOf(context).bottom
      ..fallbackPanelHeight = fallbackKeyboardHeight;
  }
}

typedef FloatingEditorContentBuilder = Widget Function(BuildContext, FloatingEditorPageGeometry pageGeometry);

typedef KeyboardPanelBuilder<PanelType> = Widget Function(BuildContext, PanelType openPanel);

/// `Element` for a [FloatingEditorPageScaffold] widget.
class _AboveKeyboardMessagePageElement<PanelType> extends RenderObjectElement {
  _AboveKeyboardMessagePageElement(_AboveKeyboardMessagePageScaffold super.widget);

  Element? _content;
  Element? _bottomSheet;
  Element? _keyboardPanel;
  PanelType? _lastBuiltPanel;

  @override
  _AboveKeyboardMessagePageScaffold<PanelType> get widget =>
      super.widget as _AboveKeyboardMessagePageScaffold<PanelType>;

  @override
  _RenderAboveKeyboardPageScaffold get renderObject => super.renderObject as _RenderAboveKeyboardPageScaffold;

  @override
  void mount(Element? parent, Object? newSlot) {
    messagePageElementLog.info('ChatScaffoldElement - mounting');
    super.mount(parent, newSlot);

    _content = inflateWidget(
      // Run initial build with zero bottom spacing because we haven't
      // run layout on the message editor yet, which determines the content
      // bottom spacing.
      widget.contentBuilder(this, FloatingEditorPageGeometry.zero),
      _contentSlot,
    );

    _bottomSheet = inflateWidget(widget.bottomSheetBuilder(this), _bottomSheetSlot);

    if (widget.keyboardPanelBuilder != null && widget.pageController.openPanel != null) {
      updateOrInflateKeyboardPanel();
    }

    print("Element - mount() - adding listener to page controller");
    widget.pageController.addListener(markNeedsBuild);
  }

  @override
  void activate() {
    messagePageElementLog.info('ContentLayersElement - activating');
    _didActivateSinceLastBuild = false;
    super.activate();
  }

  // Whether this `Element` has been built since the last time `activate()` was run.
  var _didActivateSinceLastBuild = false;

  @override
  void deactivate() {
    messagePageElementLog.info('ContentLayersElement - deactivating');
    _didDeactivateSinceLastBuild = false;
    super.deactivate();
  }

  // Whether this `Element` has been built since the last time `deactivate()` was run.
  bool _didDeactivateSinceLastBuild = false;

  @override
  void unmount() {
    messagePageElementLog.info('ContentLayersElement - unmounting');
    print("Element - unmount() - removing page controller listener");
    widget.pageController.removeListener(markNeedsBuild);
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

    // Rebuild our child widgets, except for our content widget.
    //
    // We don't rebuild our content widget because we only want content to
    // build during layout.
    updateChild(_bottomSheet, widget.bottomSheetBuilder(this), _bottomSheetSlot);

    if (widget.pageController.isKeyboardPanelOpen) {
      updateOrInflateKeyboardPanel();
    }
  }

  void buildContent(FloatingEditorPageGeometry pageGeometry) {
    messagePageElementLog.info('ContentLayersElement ($hashCode) - (re)building layers');
    // FIXME: The concept of bottom spacing doesn't apply to this scaffold because we report two heights.
    widget.pageController.debugMostRecentBottomSpacing.value = pageGeometry.keyboardOrPanelHeight;

    owner!.buildScope(this, () {
      if (_content == null) {
        _content = inflateWidget(
          widget.contentBuilder(this, pageGeometry),
          _contentSlot,
        );
      } else {
        _content = super.updateChild(
          _content,
          widget.contentBuilder(this, pageGeometry),
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
  void update(_AboveKeyboardMessagePageScaffold newWidget) {
    // Remove listener on previous widget.
    print("Element - update() - removing listener from previous widget controller");
    widget.pageController.removeListener(markNeedsBuild);

    super.update(newWidget);

    _content =
        updateChild(_content, widget.contentBuilder(this, FloatingEditorPageGeometry.zero), _contentSlot) ?? _content;

    _bottomSheet = updateChild(_bottomSheet, widget.bottomSheetBuilder(this), _bottomSheetSlot);

    // The page controller may have been switched out for another one. We want to
    // take the same keyboard panel update behavior here that we take any time the
    // controller changes - possibly inflate, or update, or deactivate the keyboard
    // panel.
    final openPanel = widget.pageController.openPanel;
    if (openPanel != null && _keyboardPanel == null && widget.keyboardPanelBuilder != null) {
      // We want to show a keyboard panel, but we haven't built one yet. Build it.
      updateOrInflateKeyboardPanel();
    } else if (openPanel != null && openPanel != _lastBuiltPanel) {
      // The user switched to a different panel. Rebuild the keyboard panel widget.
      updateOrInflateKeyboardPanel();
    } else if (openPanel == null && _keyboardPanel != null) {
      // We don't want to show a keyboard panel, but we still have a keyboard panel
      // child. Throw it away.
      deactivateChild(_keyboardPanel!);
      _keyboardPanel = null;
      _lastBuiltPanel = null;
    }

    print("Element - update() - adding listener to new widget controller");
    widget.pageController.addListener(markNeedsBuild);
  }

  void updateOrInflateKeyboardPanel() {
    final panel = widget.pageController.openPanel;
    if (panel == null) {
      return;
    }

    if (_keyboardPanel == null) {
      _keyboardPanel = inflateWidget(
        widget.keyboardPanelBuilder!(this, panel),
        _keyboardPanelSlot,
      );
    } else {
      _keyboardPanel = updateChild(
        _keyboardPanel,
        widget.keyboardPanelBuilder!(this, panel),
        _keyboardPanelSlot,
      );
    }
    _lastBuiltPanel = panel;
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
    print("Element - insertRenderObjectChild - $child, slot: $slot");
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

    if (newSlot == _contentSlot) {
      renderObject._content = child;
    } else if (newSlot == _bottomSheetSlot) {
      renderObject._bottomSheet = child;
    } else if (newSlot == _keyboardPanelSlot) {
      renderObject._keyboardPanel = child;
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

    if (_keyboardPanel != null) {
      visitor(_keyboardPanel!);
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
    } else {
      print("NOT ALLOWING CHILD VISITATION!");
      print("StackTrace:\n${StackTrace.current}");
    }
  }
}

/// `RenderObject` for a [FloatingEditorPageScaffold] widget.
///
/// Must be associated with an `Element` of type [MessagePageElement].
class _RenderAboveKeyboardPageScaffold<PanelType> extends RenderBox
    implements FloatingEditorPageControllerDelegate<PanelType> {
  _RenderAboveKeyboardPageScaffold(
    this._element,
    FloatingEditorPageController pageController, {
    required TickerProvider vsync,
    required int viewId,
    required double bottomSheetMinimumTopGap,
    required double bottomSheetMinimumHeight,
    required double bottomSheetCollapsedMaximumHeight,
    required double mediaQueryBottomInsets,
    required double mediaQueryBottomPadding,
    double fallbackKeyboardHeight = 250.0,
  })  : _viewId = viewId,
        _bottomSheetMinimumTopGap = bottomSheetMinimumTopGap,
        _bottomSheetMinimumHeight = bottomSheetMinimumHeight,
        _bottomSheetCollapsedMaximumHeight = bottomSheetCollapsedMaximumHeight,
        _mediaQueryBottomInsets = mediaQueryBottomInsets,
        _mediaQueryBottomPadding = mediaQueryBottomPadding,
        _fallbackPanelHeight = fallbackKeyboardHeight {
    _pageController = pageController..attach(this);

    SuperKeyboard.instance.mobileGeometry.addListener(_onKeyboardHeightChange);

    _panelHeightController = AnimationController(
      // TODO: Should we create this AnimationController within a widget so that we don't need to pass a vsync to a render object?
      // TODO: If we do keep the vsync here, we need to figure out when in the render object lifecycle we need to pause, stop, and whether the widget needs to be able to provide a new vsync.
      vsync: vsync,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        print("Panel height change: ${_panelHeightController.value}%");
        markNeedsLayout();
      });

    _attachToPageController();

    _updateMaxPanelHeight();
  }

  @override
  void dispose() {
    _listeners.clear();
    _panelHeightController.dispose();
    _pageController.detach();

    SuperKeyboard.instance.mobileGeometry.removeListener(_onKeyboardHeightChange);

    _element = null;
    super.dispose();
  }

  /// The ID of the current Flutter view, which is needed to open the software keyboard.
  int _viewId;
  set viewId(int newViewId) {
    if (newViewId == _viewId) {
      return;
    }

    // TODO: What do we need to reset/clear as a result of changing to a different Flutter view?

    _viewId = newViewId;
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

  _AboveKeyboardMessagePageElement? _element;

  BottomSheetMode? _overrideSheetMode;
  BottomSheetMode get bottomSheetMode {
    if (_overrideSheetMode != null) {
      return _overrideSheetMode!;
    }

    if (_simulation != null) {
      return BottomSheetMode.settling;
    }

    if (_pageController.isDragging) {
      return BottomSheetMode.dragging;
    }

    if (_pageController.isExpanded) {
      return BottomSheetMode.expanded;
    }

    if (_pageController.isPreview) {
      return BottomSheetMode.preview;
    }

    return BottomSheetMode.intrinsic;
  }

  // ignore: avoid_setters_without_getters
  set pageController(FloatingEditorPageController controller) {
    if (controller == _pageController) {
      return;
    }

    _detachFromPageController();
    _pageController = controller;
    _attachToPageController();
  }

  late FloatingEditorPageController _pageController;
  MessagePageDragMode _currentDragMode = MessagePageDragMode.idle;
  double? _currentDesiredGlobalTopY;
  double? _desiredDragHeight;
  bool _isExpandingOrCollapsing = false;
  double _animatedHeight = 300;
  double _animatedVelocity = 0;

  void _attachToPageController() {
    _currentDragMode = _pageController.dragMode;
    _pageController.attach(this);
    _pageController.addListener(_onMessagePageControllerChange);

    markNeedsLayout();
  }

  void _onMessagePageControllerChange() {
    // We might change the controller in this listener call, so we stop
    // listening to the controller during this function.
    _pageController.removeListener(_onMessagePageControllerChange);
    var didChange = false;

    if (_currentDragMode != _pageController.dragMode) {
      switch (_pageController.dragMode) {
        case MessagePageDragMode.dragging:
          // The user just started dragging.
          _onDragStart();
        case MessagePageDragMode.idle:
          // The user just stopped dragging.
          _onDragEnd();
      }

      _currentDragMode = _pageController.dragMode;
      didChange = true;
    }

    if (_pageController.dragMode == MessagePageDragMode.dragging &&
        _currentDesiredGlobalTopY != _pageController.desiredGlobalTopY) {
      // TODO: don't invalidate layout if we've reached max height and the Y value went higher
      _currentDesiredGlobalTopY = _pageController.desiredGlobalTopY;

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
    _pageController.addListener(_onMessagePageControllerChange);
  }

  void _onDragStart() {
    _velocityTracker = VelocityTracker.withKind(PointerDeviceKind.touch);
    _velocityStopwatch = Stopwatch()..start();
  }

  void _onDragEnd() {
    _velocityStopwatch.stop();

    final velocity = _velocityTracker.getVelocityEstimate()?.pixelsPerSecond.dy ?? 0;

    _startBottomSheetHeightSimulation(velocity: velocity);
  }

  void _startBottomSheetHeightSimulation({
    required double velocity,
  }) {
    _ticker.stop();

    final minimizedHeight = switch (_pageController.collapsedMode) {
      MessagePageSheetCollapsedMode.preview => _previewHeight,
      MessagePageSheetCollapsedMode.intrinsic => min(_intrinsicHeight, _bottomSheetCollapsedMaximumHeight),
    };

    _pageController.desiredSheetMode = velocity.abs() > 500 //
        ? velocity < 0
            ? MessagePageSheetMode.expanded
            : MessagePageSheetMode.collapsed
        : (_expandedHeight - _desiredDragHeight!).abs() < (_desiredDragHeight! - minimizedHeight).abs()
            ? MessagePageSheetMode.expanded
            : MessagePageSheetMode.collapsed;

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
    final minimizedHeight = switch (_pageController.collapsedMode) {
      MessagePageSheetCollapsedMode.preview => _previewHeight,
      MessagePageSheetCollapsedMode.intrinsic => min(_intrinsicHeight, _bottomSheetCollapsedMaximumHeight),
    };

    _pageController.isSliding = true;

    final startHeight = _bottomSheet!.size.height;
    _simulationGoalMode = _pageController.desiredSheetMode;
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
      ' - Desired sheet mode: ${_pageController.desiredSheetMode}',
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

  void _detachFromPageController() {
    _pageController.removeListener(_onMessagePageControllerChange);
    _pageController.detach();

    _currentDragMode = MessagePageDragMode.idle;
    _desiredDragHeight = null;
    _currentDesiredGlobalTopY = null;
  }

  //----- START KEYBOARD PANEL DELEGATE IMPLEMENTATION ------
  double get _keyboardHeight {
    final keyboardGeometry = SuperKeyboard.instance.mobileGeometry.value;
    if (keyboardGeometry.keyboardHeight == null || keyboardGeometry.keyboardState != KeyboardState.open) {
      // Defer to standard Flutter MediaQuery value.
      return _mediaQueryBottomInsets;
    }

    return keyboardGeometry.keyboardHeight!;
  }

  double _bestGuessMaxKeyboardHeight = 0.0;

  double _mediaQueryBottomInsets = 0.0;
  set mediaQueryBottomInsets(double newInsets) {
    if (newInsets == _mediaQueryBottomInsets) {
      return;
    }

    _mediaQueryBottomInsets = newInsets;
    markNeedsLayout();
  }

  double _fallbackPanelHeight = 250.0;
  set fallbackPanelHeight(double newHeight) {
    _fallbackPanelHeight = newHeight;
  }

  double _mediaQueryBottomPadding = 0.0;
  set mediaQueryBottomPadding(double newPadding) {
    if (newPadding == _mediaQueryBottomPadding) {
      return;
    }

    _mediaQueryBottomPadding = newPadding;
    markNeedsLayout();
  }

  /// The height of the visible panel at this moment.
  late final AnimationController _panelHeightController;
  late Animation<double> _panelHeight;

  /// The currently visible panel.
  PanelType? _activePanel;

  /// Whether the software keyboard should be displayed, instead of the keyboard panel.
  bool get wantsToShowSoftwareKeyboard => _wantsToShowSoftwareKeyboard;
  bool _wantsToShowSoftwareKeyboard = false;

  @override
  bool get isSoftwareKeyboardOpen => _wantsToShowSoftwareKeyboard;

  /// Shows the software keyboard, if it's hidden.
  @override
  void showSoftwareKeyboard() {
    print("showSoftwareKeyboard()");
    // _wantsToShowKeyboardPanel = false;
    _wantsToShowSoftwareKeyboard = true;
    _pageController.softwareKeyboardController.open(viewId: _viewId);
    // Note: We don't animate the panel away because as the panel goes
    //       down, it drags the bottom sheet down with it, until the
    //       bottom sheet hits the keyboard as the keyboard comes up.
    //       Instead, we keep the bottom sheet around until the keyboard
    //       fully opens.

    // TODO: do we need to mark layout? paint?

    // Notify delegate listeners.
    notifyListeners();
  }

  /// Hides (doesn't close) the software keyboard, if it's open.
  @override
  void hideSoftwareKeyboard() {
    _wantsToShowSoftwareKeyboard = false;
    _pageController.softwareKeyboardController.hide();

    // TODO: do we need to mark layout? paint?

    // Notify delegate listeners.
    notifyListeners();

    _maybeAnimatePanelClosed();
  }

  /// Whether a keyboard panel should be displayed instead of the software keyboard.
  bool get wantsToShowKeyboardPanel => _wantsToShowKeyboardPanel;
  bool _wantsToShowKeyboardPanel = false;

  @override
  bool get isKeyboardPanelOpen => _wantsToShowKeyboardPanel;

  @override
  PanelType? get openPanel => _activePanel;

  /// Shows the keyboard panel, if it's closed, and hides (doesn't close) the
  /// software keyboard, if it's open.
  @override
  void showKeyboardPanel(PanelType panel) {
    print("FloatingEditorPageScaffold - showKeyboardPanel()");
    _wantsToShowKeyboardPanel = true;
    _wantsToShowSoftwareKeyboard = false;
    _activePanel = panel;

    if (SuperKeyboard.instance.mobileGeometry.value.keyboardState == KeyboardState.open) {
      // The keyboard is fully open. We'd like for the panel to immediately
      // appear behind the keyboard as it closes, so that we don't have a
      // bunch of jumping around for the widgets mounted to the top of the
      // keyboard.
      print("Jumping panel height to 100%");
      _panelHeightController.value = 1.0;
    } else {
      print("Animating the panel height");
      _panelHeightController.forward();
    }

    _pageController.softwareKeyboardController.hide();

    // TODO: Do we need to mark layout? or paint?

    // Notify delegate listeners.
    print("Notifying controller listeners");
    notifyListeners();
  }

  @override
  void toggleKeyboardPanel(PanelType panel) {
    if (_activePanel == panel) {
      hideKeyboardPanel();
    } else {
      showKeyboardPanel(panel);
    }
  }

  /// Hides the keyboard panel, if it's open.
  @override
  void hideKeyboardPanel() {
    // Close panel.
    print("hideKeyboardPanel()");
    _wantsToShowKeyboardPanel = false;
    _activePanel = null;
    // Note: We don't animate the panel away because as the panel goes
    //       down, it drags the bottom sheet down with it, until the
    //       bottom sheet hits the keyboard as the keyboard comes up.
    //       Instead, we keep the bottom sheet around until the keyboard
    //       fully opens.

    // Open the keyboard.
    _pageController.softwareKeyboardController.open(viewId: _viewId);

    // TODO: do we need to mark layout? paint?

    // Notify delegate listeners.
    notifyListeners();
  }

  /// Closes the software keyboard if it's open, or closes the keyboard panel if
  /// it's open, and fully closes the keyboard (IME) connection.
  @override
  void closeKeyboardAndPanel() {
    _wantsToShowKeyboardPanel = false;
    _wantsToShowSoftwareKeyboard = false;
    _activePanel = null;
    _pageController.softwareKeyboardController.close();
    _panelHeightController.reverse();

    // TODO: do we need to mark layout? paint?

    // Notify delegate listeners.
    notifyListeners();
  }

  void _onKeyboardHeightChange() {
    print("_onKeyboardHeightChange() - ${SuperKeyboard.instance.mobileGeometry.value.keyboardHeight}");
    _updateMaxPanelHeight();

    if (_wantsToShowSoftwareKeyboard &&
        _wantsToShowKeyboardPanel &&
        SuperKeyboard.instance.mobileGeometry.value.keyboardState == KeyboardState.open) {
      // We kept a keyboard panel visible while the keyboard came back up. The
      // keyboard is now fully open. Get rid of the keyboard panel.
      _wantsToShowKeyboardPanel = false;
      notifyListeners();
    }

    // Re-run layout to make sure we account for new keyboard height.
    markNeedsLayout();
  }

  void _updateMaxPanelHeight() {
    final currentKeyboardHeight = SuperKeyboard.instance.mobileGeometry.value.keyboardHeight ?? 0;
    _bestGuessMaxKeyboardHeight = max(currentKeyboardHeight, _bestGuessMaxKeyboardHeight);

    _panelHeight = Tween(
      begin: 0.0,
      end: _bestGuessMaxKeyboardHeight > 100 ? _bestGuessMaxKeyboardHeight : _fallbackPanelHeight,
    ) //
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_panelHeightController);
  }

  void _maybeAnimatePanelClosed() {
    final keyboardHeight = SuperKeyboard.instance.mobileGeometry.value.keyboardHeight;

    if (_wantsToShowKeyboardPanel ||
        _wantsToShowSoftwareKeyboard ||
        (keyboardHeight != null && keyboardHeight != 0.0)) {
      return;
    }

    // The user wants to close both the software keyboard and the keyboard panel,
    // but the software keyboard is already closed. Animate the keyboard panel height
    // down to zero.
    _panelHeightController.reverse(from: 1.0);
  }

  final _listeners = <VoidCallback>{};

  @override
  bool get hasListeners => _listeners.isNotEmpty;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  void notifyListeners() {
    final listeners = Set.from(_listeners);
    print("Notifying listeners: $listeners");
    for (final listener in listeners) {
      print("Running listener: $listener");
      listener();
    }
  }
  //----- END KEYBOARD PANEL DELEGATE IMPLEMENTATION ------

  RenderBox? _content;

  RenderBox? _bottomSheet;

  RenderBox? _keyboardPanel;

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

      _pageController.isSliding = false;
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
    if (_keyboardPanel != null) {
      childDiagnostics.add(_keyboardPanel!.toDiagnosticsNode(name: 'keyboard_panel'));
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
    } else if (slot == _keyboardPanelSlot) {
      _keyboardPanel = child as RenderBox;
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
    } else if (slot == _keyboardPanelSlot) {
      _keyboardPanel = null;
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
    if (_keyboardPanel != null) {
      visitor(_keyboardPanel!);
    }
  }

  @override
  void performLayout() {
    messagePageLayoutLog.info('---------- LAYOUT -------------');
    messagePageLayoutLog.info('Laying out RenderChatScaffold');
    messagePageLayoutLog
        .info('Sheet mode: ${_pageController.desiredSheetMode}, collapsed mode: ${_pageController.collapsedMode}');
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

    final minimizedHeight = switch (_pageController.collapsedMode) {
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
        MessagePageSheetMode.collapsed => switch (_pageController.collapsedMode) {
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
          _pageController.collapsedMode == MessagePageSheetCollapsedMode.preview ? _previewHeight : _intrinsicHeight,
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
    } else if (_pageController.desiredSheetMode == MessagePageSheetMode.expanded) {
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
        // bottomSheetConstraints,
        bottomSheetConstraints.copyWith(
          minHeight: 0,
          maxHeight: _bottomSheetCollapsedMaximumHeight,
        ),
        parentUsesSize: true,
      );
    }

    final keyboardOrPanelHeight = max(max(_panelHeight.value, _keyboardHeight), _mediaQueryBottomPadding);
    (_bottomSheet!.parentData! as BoxParentData).offset =
        Offset(0, size.height - _bottomSheet!.size.height - keyboardOrPanelHeight);
    _bottomSheetNeedsLayout = false;
    messagePageLayoutLog.info('Bottom sheet height: ${_bottomSheet!.size.height}');

    // Now that we know the size of the message editor, build the content based
    // on the bottom spacing needed to push above the editor.
    messagePageLayoutLog.info('');
    messagePageLayoutLog.info('Building chat scaffold content');
    invokeLayoutCallback((constraints) {
      _element!.buildContent(FloatingEditorPageGeometry(
        keyboardHeight: _keyboardHeight,
        panelHeight: _panelHeight.value,
        bottomViewPadding: _mediaQueryBottomPadding,
        bottomSheetHeight: _bottomSheet!.size.height,
      ));
    });
    messagePageLayoutLog.info('Laying out chat scaffold content');
    _content!.layout(constraints, parentUsesSize: true);
    messagePageLayoutLog.info('Content layout size: ${_content!.size}');

    // (Maybe) Layout a keyboard panel, which appears where the keyboard would be.
    if (isKeyboardPanelOpen && _keyboardPanel != null) {
      print("Laying out keyboard panel render object");
      _keyboardPanel!.layout(
        constraints.copyWith(
          minHeight: _panelHeight.value,
          maxHeight: _panelHeight.value,
        ),
        parentUsesSize: true,
      );

      (_keyboardPanel!.parentData as BoxParentData).offset = Offset(0, size.height - _keyboardPanel!.size.height);
    }

    _runningLayout = false;
    messagePageLayoutLog.info('Done laying out RenderChatScaffold');
    messagePageLayoutLog.info('---------- END LAYOUT ---------');
  }

  double _calculateBoundedIntrinsicHeight(BoxConstraints constraints) {
    messagePageLayoutLog.info('Running dry layout on bottom sheet content to find the intrinsic height...');
    messagePageLayoutLog.info(' - Bottom sheet constraints: $constraints');
    messagePageLayoutLog.info(' - Controller desired sheet mode: ${_pageController.collapsedMode}');
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

    // Second, (maybe) hit-test the keyboard panel, which sits on top of the page content.
    if (_keyboardPanel != null) {
      final childParentData = _keyboardPanel!.parentData! as BoxParentData;

      final didHit = result.addWithPaintOffset(
        offset: childParentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          return _keyboardPanel!.hitTest(result, position: transformed);
        },
      );

      if (didHit) {
        return true;
      }
    }

    // Third, hit-test the content, which sits beneath the message
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
      final bottomSheetOffset = (_bottomSheet!.parentData! as BoxParentData).offset;
      messagePagePaintLog.info('Painting message editor - y-offset: $bottomSheetOffset');
      context.paintChild(
        _bottomSheet!,
        offset + bottomSheetOffset,
      );
    }

    if (_keyboardPanel != null) {
      print("Painting keyboard panel");
      final keyboardPanelOffset = (_keyboardPanel!.parentData! as BoxParentData).offset;
      messagePagePaintLog.info('Painting keyboard panel - y-offset: $keyboardPanelOffset');
      context.paintChild(_keyboardPanel!, offset + keyboardPanelOffset);
    }
    messagePagePaintLog.info('---------- END PAINT ------------');
  }

  @override
  void setupParentData(covariant RenderObject child) {
    child.parentData = BoxParentData();
  }
}

class FloatingEditorPageGeometry {
  static const zero = FloatingEditorPageGeometry(
    keyboardHeight: 0,
    panelHeight: 0,
    bottomViewPadding: 0,
    bottomSheetHeight: 0,
  );

  const FloatingEditorPageGeometry({
    required this.keyboardHeight,
    required this.panelHeight,
    required this.bottomViewPadding,
    required this.bottomSheetHeight,
  });

  final double keyboardHeight;
  final double panelHeight;
  final double bottomViewPadding;
  final double bottomSheetHeight;

  /// Space at the bottom of the page that's obscured by some combination of operating
  /// system controls, the keyboard, a keyboard panel, and the floating editor bottom sheet.
  double get bottomSafeArea => max(keyboardOrPanelHeight, bottomViewPadding) + bottomSheetHeight;

  /// The height of the software keyboard, or the keyboard panel, whichever is currently
  /// taller.
  ///
  /// Typically, either the software keyboard is open, or a panel is open, not both. However,
  /// when one switches to the other, one animates down while the other animates up, which
  /// results in both heights being greater than zero for a period of time.
  double get keyboardOrPanelHeight => max(keyboardHeight, panelHeight);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FloatingEditorPageGeometry &&
          runtimeType == other.runtimeType &&
          keyboardHeight == other.keyboardHeight &&
          panelHeight == other.panelHeight &&
          bottomViewPadding == other.bottomViewPadding &&
          bottomSheetHeight == other.bottomSheetHeight;

  @override
  int get hashCode =>
      keyboardHeight.hashCode ^ panelHeight.hashCode ^ bottomViewPadding.hashCode ^ bottomSheetHeight.hashCode;
}

bool _isChatScaffoldSlot(Object slot) => slot == _contentSlot || slot == _bottomSheetSlot || slot == _keyboardPanelSlot;

const _contentSlot = 'content';
const _bottomSheetSlot = 'bottom_sheet';
const _keyboardPanelSlot = 'keyboard_panel';

/// A marker widget that wraps the outermost boundary of the bottom sheet in a
/// [FloatingEditorPageScaffold].
///
/// This widget can be accessed by descendants for the purpose of querying the size
/// and global position of the floating sheet. This is useful, for example, when
/// implementing drag behaviors to expand/collapse the bottom sheet. The part of the
/// widget tree that contains the drag handle may not have access to the overall sheet.
class FloatingChatBottomSheet extends StatefulWidget {
  static BuildContext of(BuildContext context) =>
      context.findAncestorStateOfType<_FloatingChatBottomSheetState>()!._sheetKey.currentContext!;

  static BuildContext? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<_FloatingChatBottomSheetState>()?._sheetKey.currentContext;

  const FloatingChatBottomSheet({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<FloatingChatBottomSheet> createState() => _FloatingChatBottomSheetState();
}

class _FloatingChatBottomSheetState extends State<FloatingChatBottomSheet> {
  final _sheetKey = GlobalKey(debugLabel: "FloatingChatBottomSheet");

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _sheetKey, child: widget.child);
  }
}
