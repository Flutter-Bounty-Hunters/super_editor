import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/debug_visualization.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_ios.dart';
import 'package:super_editor/src/default_editor/document_ime/shared_ime.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/actions.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/ime_input_owner.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/ios_document_controls.dart';
import 'package:super_editor/src/infrastructure/platforms/platform.dart';
import 'package:super_editor/src/infrastructure/render_sliver_ext.dart';

import '../document_hardware_keyboard/document_input_keyboard.dart';
import 'document_delta_editing.dart';
import 'document_ime_communication.dart';
import 'document_ime_interaction_policies.dart';
import 'ime_decoration.dart';
import 'ime_keyboard_control.dart';

/// [SuperEditor] interactor that edits a document based on IME input
/// from the operating system.
// TODO: instead of an IME interactor, try defining more granular interactors, e.g.,
//       TextDeltaInteractor, FloatingCursorInteractor, ScribbleInteractor.
//       The concept of the IME is so broad in functionality that if we mimic that
//       concept, we're going to get stuck piling unrelated behaviors into one place.
//       To make this division of responsibility possible, each of those interactors
//       could receive a proxy TextInputClient, which allows each interactor to say
//       proxyInputClient.addClient(myFocusedClient).
class SuperEditorImeInteractor extends StatefulWidget {
  const SuperEditorImeInteractor({
    Key? key,
    this.focusNode,
    this.autofocus = false,
    required this.editContext,
    this.clearSelectionWhenEditorLosesFocus = true,
    this.clearSelectionWhenImeConnectionCloses = true,
    this.softwareKeyboardController,
    this.inputRole,
    this.imePolicies = const SuperEditorImePolicies(),
    this.imeConfiguration = const SuperEditorImeConfiguration(),
    this.imeOverrides,
    this.isImeConnected,
    this.hardwareKeyboardActions = const [],
    required this.selectorHandlers,
    this.floatingCursorController,
    required this.child,
  }) : super(key: key);

  final FocusNode? focusNode;

  final bool autofocus;

  /// All resources that are needed to edit a document.
  final SuperEditorContext editContext;

  /// Whether the document's selection should be removed when the editor loses
  /// all focus (not just primary focus).
  ///
  /// If `true`, when focus moves to a different subtree, such as a popup text
  /// field, or a button somewhere else on the screen, the editor will remove
  /// its selection. When focus returns to the editor, the previous selection can
  /// be restored, but that's controlled by other policies.
  ///
  /// If `false`, the editor will retain its selection, including a visual caret
  /// and selected content, even when the editor doesn't have any focus, and can't
  /// process any input.
  final bool clearSelectionWhenEditorLosesFocus;

  /// Whether the editor's selection should be removed when the editor closes or loses
  /// its IME connection.
  ///
  /// Defaults to `true`.
  ///
  /// Apps that include a custom input mode, such as an editing panel that sometimes
  /// replaces the software keyboard, should set this to `false` and instead control the
  /// IME connection manually.
  final bool clearSelectionWhenImeConnectionCloses;

  /// Controller that opens and closes the software keyboard.
  ///
  /// When [SuperEditorImePolicies.openKeyboardOnSelectionChange] and
  /// [SuperEditorImePolicies.clearSelectionWhenEditorLosesFocus] are `false`,
  /// an app can use this controller to manually open and close the software
  /// keyboard, as needed.
  ///
  /// When [SuperEditorImePolicies.openKeyboardOnSelectionChange] and
  /// [clearSelectionWhenImeDisconnects] are `true`, this controller probably
  /// shouldn't be used, because the commands to open and close the keyboard
  /// might conflict with teh automated behavior.
  final SoftwareKeyboardController? softwareKeyboardController;

  final String? inputRole;

  /// Policies that dictate when and how `SuperEditor` should interact with the
  /// platform IME.
  final SuperEditorImePolicies imePolicies;

  /// Preferences for how the platform IME should look and behave during editing.
  final SuperEditorImeConfiguration imeConfiguration;

  /// Overrides for IME actions.
  ///
  /// When the user edits document content in IME mode, those edits and actions
  /// are reported to a [DeltaTextInputClient], which is then responsible for
  /// applying those changes to a document.
  ///
  /// Provide a [DeltaTextInputClientDecorator], to override the default behaviors
  /// for various IME messages.
  final DeltaTextInputClientDecorator? imeOverrides;

  /// A (optional) notifier that's notified when the IME connection opens or closes.
  ///
  /// A `true` value means this interactor is connected to the platform's IME, a `false`
  /// value means this interactor isn't connected to the platforms IME.
  final ValueNotifier<bool>? isImeConnected;

  /// All the actions that the user can execute with physical hardware
  /// keyboard keys.
  ///
  /// [keyboardActions] operates as a Chain of Responsibility. Starting
  /// from the beginning of the list, a [DocumentKeyboardAction] is
  /// given the opportunity to handle the currently pressed keys. If that
  /// [DocumentKeyboardAction] reports the keys as handled, then execution
  /// stops. Otherwise, execution continues to the next [DocumentKeyboardAction].
  final List<DocumentKeyboardAction> hardwareKeyboardActions;

  /// Controls "floating cursor" behavior for iOS devices.
  ///
  /// The floating cursor is an iOS-only feature. Flutter reports floating cursor
  /// messages through the IME API, which is why this controller is offered as
  /// a property on this IME interactor.
  ///
  /// If no [floatingCursorController] is provided, this widget attempts to obtain
  /// one from an ancestor [SuperEditorIosControlsScope]
  final FloatingCursorController? floatingCursorController;

  /// Handlers for all Mac OS "selectors" reported by the IME.
  ///
  /// The IME reports selectors as unique `String`s, therefore selector handlers are
  /// defined as a mapping from selector names to handler functions.
  final Map<String, SuperEditorSelectorHandler> selectorHandlers;

  final Widget child;

  @override
  State createState() => SuperEditorImeInteractorState();
}

@visibleForTesting
class SuperEditorImeInteractorState extends State<SuperEditorImeInteractor> implements ImeInputOwner {
  static bool _willCheckUniqueInputsNextFrame = false;

  static final _registeredInputsThisFrame = <(SuperImeInputId inputId, StackTrace stacktrace)>[];

  /// Ensures that there are no other inputs with the same [inputId] at the end of the current
  /// Flutter frame.
  ///
  /// At the end of the frame, if 2+ inputs registered with the same [SuperImeInputId.role],
  /// an exception is thrown, which includes the stack traces for each of those registrations,
  /// so that developers can debug why it happened.
  static _registerInput(SuperImeInputId inputId) {
    if (!kDebugMode) {
      return;
    }

    _registeredInputsThisFrame.add((inputId, StackTrace.current));

    if (!_willCheckUniqueInputsNextFrame) {
      _willCheckUniqueInputsNextFrame = true;
      WidgetsBinding.instance.addPostFrameCallback(_verifyUniqueInputs);
    }
  }

  static void _unregisterInput(SuperImeInputId inputId) {
    final startLength = _registeredInputsThisFrame.length;
    _registeredInputsThisFrame.removeWhere((entry) => entry.$1.instance == inputId.instance);

    assert(
      startLength != _registeredInputsThisFrame.length,
      "An IME interactor tried to unregister itself with the global tracker, but we "
      "didn't find it in the global tracker. Either it was never added, or it was "
      "already removed. Either way, this is a programming mistake that needs to be "
      "corrected by the caller.",
    );
  }

  static void _verifyUniqueInputs(Duration _) {
    // Clear flag so the next time the "ensure" method is called, we''
    // register another post frame callback.
    _willCheckUniqueInputsNextFrame = false;

    final inputsByRole = <String?, List<(SuperImeInputId, StackTrace)>>{};

    for (final input in _registeredInputsThisFrame) {
      inputsByRole[input.$1.role] ??= [];
      inputsByRole[input.$1.role]!.add(input);
    }

    final duplicates = <(SuperImeInputId, StackTrace)>[];
    for (final entry in inputsByRole.entries) {
      if (entry.value.length < 2) {
        // No duplicate inputs here.
        continue;
      }

      duplicates.addAll(entry.value);
    }

    if (duplicates.isEmpty) {
      // No duplicate inputs anywhere this frame. All good. We're done.
      return;
    }

    // We found some number of duplicates. Write them all out to an exception message.
    throw Exception([
      "Found ${duplicates.length} duplicate input IDs this frame:",
      for (final input in duplicates) ...[
        "Input: ${input.$1.role} (${input.$1.instance})",
        "This duplicate input was built at this moment:",
        input.$2,
        "------ END OF ${input.$1.role} (${input.$1.instance}) ----",
      ],
    ].join("\n"));
  }

  late FocusNode _focusNode;

  SuperEditorIosControlsController? _controlsController;

  late SuperImeInputId _myImeId;
  final _ownedImeConnection = ValueNotifier<TextInputConnection?>(null);
  late TextInputConfiguration _textInputConfiguration;
  late DocumentImeInputClient _documentImeClient;
  // The _imeClient is setup in one of two ways at any given time:
  //   _imeClient -> _documentImeClient, or
  //   _imeClient -> widget.imeOverrides -> _documentImeClient
  // See widget.imeOverrides for more info.
  late DeltaTextInputClientDecorator _imeClient;
  // _documentImeConnection functions as both a TextInputConnection and a
  // DeltaTextInputClient. This is required for a very specific reason that
  // occurs in specific situations. To understand why we need it, check the
  // implementation of DocumentImeInputClient. If we find a less confusing
  // way to handle that scenario, then get rid of this property.
  final _documentImeConnection = ValueNotifier<TextInputConnection?>(null);

  @override
  void initState() {
    super.initState();
    _focusNode = (widget.focusNode ?? FocusNode());

    _myImeId = SuperImeInputId(role: widget.inputRole, instance: this);
    _registerInput(_myImeId);
    SuperIme.instance.addListener(_onSharedImeChange);
    _setupDocumentImeInputClient();

    _imeClient = DeltaTextInputClientDecorator();
    _configureImeClientDecorators();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Synchronize the IME connection notifier with our IME connection state. We run
      // this in a post-frame callback because the very first pump of the Super Editor
      // widget tree won't have Super Editor connected as an IME delegate, yet.
      if (widget.softwareKeyboardController != null) {
        widget.isImeConnected?.value = widget.softwareKeyboardController!.isConnectedToIme;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controlsController = SuperEditorIosControlsScope.maybeRootOf(context);
    _documentImeClient.floatingCursorController =
        widget.floatingCursorController ?? _controlsController?.floatingCursorController;
    _textInputConfiguration = widget.imeConfiguration //
        .toTextInputConfiguration(viewId: View.of(context).viewId);
  }

  @override
  void didUpdateWidget(SuperEditorImeInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
    }

    if (widget.inputRole != oldWidget.inputRole) {
      final didOwnIme = SuperIme.instance.isOwner(_myImeId);

      // We changed roles. Release our previous claim to the shared IME.
      SuperIme.instance.releaseOwnership(_myImeId);

      // Create a new IME input ID with the new role.
      _unregisterInput(_myImeId);
      _myImeId = SuperImeInputId(role: widget.inputRole, instance: this);
      _registerInput(_myImeId);

      if (didOwnIme) {
        // Re-take IME ownership.
        SuperIme.instance.takeOwnership(_myImeId);
      }
    }

    if (widget.editContext != oldWidget.editContext) {
      _setupDocumentImeInputClient();
      _onSharedImeChange();
      _documentImeClient.floatingCursorController =
          widget.floatingCursorController ?? _controlsController?.floatingCursorController;
    }

    if (widget.imeConfiguration != oldWidget.imeConfiguration) {
      _textInputConfiguration = widget.imeConfiguration.toTextInputConfiguration(viewId: View.of(context).viewId);
      if (isAttachedToIme) {
        SuperIme.instance.getImeConnectionForOwner(_myImeId)!.updateConfig(_textInputConfiguration);
      }
    }

    if (widget.imeOverrides != oldWidget.imeOverrides) {
      oldWidget.imeOverrides?.client = null;
      _configureImeClientDecorators();
    }
  }

  @override
  void dispose() {
    SuperIme.instance.removeListener(_onSharedImeChange);
    if (SuperIme.instance.isOwner(_myImeId)) {
      // We are the current owner of the IME. Close the IME as we dispose ourselves.
      // Note: If this disposal were part of a subtree move somewhere else, the other
      // version of this widget would have already registered itself as the IME owner
      // in its `initState()` method.
      SuperIme.instance.releaseOwnership(_myImeId);
    }
    _unregisterInput(_myImeId);

    if (widget.focusNode == null) {
      _focusNode.dispose();
    }

    if (true == widget.imeOverrides?.isCurrentClient(_documentImeClient)) {
      // We're still the owner/client of the IME overrides. Null it out to
      // remove the reference to us.
      widget.imeOverrides?.client = null;
    }
    _imeClient.client = null;
    _documentImeClient.dispose();

    super.dispose();
  }

  @visibleForTesting
  @override
  DeltaTextInputClient get imeClient => _imeClient;

  @visibleForTesting
  bool get isAttachedToIme => SuperIme.instance.isInputAttachedToOS(_myImeId);

  TextInputConnection get imeConnection {
    assert(SuperIme.instance.isOwner(_myImeId),
        "The imeConnection getter should only be called when you know you're the owner. You're not.");
    assert(SuperIme.instance.getImeConnectionForOwner(_myImeId) != null,
        "The imeConnection getter should only be called when you know there's an IME connection. There isn't.");

    return SuperIme.instance.getImeConnectionForOwner(_myImeId)!;
  }

  void _setupDocumentImeInputClient() {
    _documentImeClient = DocumentImeInputClient(
      selection: widget.editContext.composer.selectionNotifier,
      composingRegion: widget.editContext.composer.composingRegion,
      textDeltasDocumentEditor: TextDeltasDocumentEditor(
        editor: widget.editContext.editor,
        document: widget.editContext.document,
        documentLayoutResolver: () => widget.editContext.documentLayout,
        selection: widget.editContext.composer.selectionNotifier,
        composerPreferences: widget.editContext.composer.preferences,
        composingRegion: widget.editContext.composer.composingRegion,
        commonOps: widget.editContext.commonOps,
        onPerformAction: (action) => _imeClient.performAction(action),
      ),
      imeConnection: _ownedImeConnection,
      onPerformSelector: _onPerformSelector,
    );
  }

  void _onSharedImeChange() {
    if (!SuperIme.instance.isOwner(_myImeId)) {
      // We don't own the IME. Update our accounting.
      _ownedImeConnection.value = null;

      _documentImeConnection.value = null;
      widget.imeOverrides?.client = null;
      widget.isImeConnected?.value = false;
      return;
    }

    if (!SuperIme.instance.isInputAttachedToOS(_myImeId)) {
      // We own the IME, but our connection to the OS was closed.
      _documentImeConnection.value = null;
      widget.imeOverrides?.client = null;
      widget.isImeConnected?.value = false;
      return;
    }

    _ownedImeConnection.value = SuperIme.instance.getImeConnectionForOwner(_myImeId);
    _configureImeClientDecorators();
    _documentImeConnection.value = _documentImeClient;

    _reportVisualInformationToIme();

    widget.isImeConnected?.value = true;
  }

  void _configureImeClientDecorators() {
    // If we were given IME overrides, use those overrides to decorate our _documentImeClient.
    widget.imeOverrides?.client = _documentImeClient;

    // If we were given IME overrides, point our primary IME client to that client. Otherwise,
    // point our primary IME client directly towards the _documentImeClient.
    _imeClient.client = widget.imeOverrides ?? _documentImeClient;
  }

  /// Report the global size and transform of the editor and the caret rect to the IME.
  ///
  /// This is needed to display the OS emoji & symbols panel at the editor selected position.
  ///
  /// This methods is re-scheduled to run at the end of every frame while we are attached to the IME.
  void _reportVisualInformationToIme() {
    if (!isAttachedToIme) {
      return;
    }

    final myRenderSliver = context.findRenderObject() as RenderSliver?;
    if (myRenderSliver != null && myRenderSliver.hasSize) {
      _reportSizeAndTransformToIme();
      _reportCaretRectToIme();
      _reportTextStyleToIme();
    }

    // There are some operations that might affect our transform, size and the caret rect,
    // but we can't react to them.
    // For example, the editor might be resized or moved around the screen.
    // Because of this, we update our size, transform and caret rect at every frame.
    // FIXME: This call seems to be scheduling frames. When the caret is in Timer mode, we see this method running continuously even though the only change should be the caret blinking every half a second
    onNextFrame((_) => _reportVisualInformationToIme());
  }

  /// Report the global size and transform of the editor to the IME.
  ///
  /// This is needed to display the OS emoji & symbols panel at the editor selected position.
  void _reportSizeAndTransformToIme() {
    late Size size;
    late Matrix4 transform;

    if (CurrentPlatform.isWeb) {
      // On web, we can't set the caret rect.
      // To display the IME panels at the correct position,
      // instead of reporting the whole editor size and transform,
      // we report only the information about the selected node.
      final sizeAndTransform = _computeSizeAndTransformOfSelectNode();
      if (sizeAndTransform == null) {
        return;
      }

      (size, transform) = sizeAndTransform;
    } else {
      final renderSliver = context.findRenderObject() as RenderSliver;

      size = renderSliver.size;
      transform = renderSliver.getTransformTo(null);
    }

    SuperIme.instance.getImeConnectionForOwner(_myImeId)!.setEditableSizeAndTransform(size, transform);
  }

  void _reportCaretRectToIme() {
    if (CurrentPlatform.isWeb) {
      // On web, setting the caret rect isn't supported.
      // To position the IME popovers, we report the size, transform and style
      // of the selected component and let the browser position the popovers.
      return;
    }

    final caretRect = _computeCaretRectInViewportSpace();
    if (caretRect != null) {
      SuperIme.instance.getImeConnectionForOwner(_myImeId)!.setCaretRect(caretRect);
    }
  }

  /// Report our text style to the IME.
  ///
  /// This is used on web to set the text style of the hidden native input,
  /// to try to match the text size on the browser with our text size.
  ///
  /// As our content can have multiple styles, the sizes won't be 100% in sync.
  ///
  /// TODO: update this after https://github.com/flutter/flutter/issues/134265 is resolved.
  void _reportTextStyleToIme() {
    if (!CurrentPlatform.isWeb) {
      // If we are not on the web, we can position the caret rect without the need
      // to send the text styles to the IME.
      return;
    }

    final selection = widget.editContext.composer.selection;
    if (selection == null) {
      return;
    }

    final nodePosition = selection.extent.nodePosition;
    if (nodePosition is! TextNodePosition) {
      // The selected component doesn't contain text.
      return;
    }

    final docLayout = widget.editContext.documentLayout;

    DocumentComponent? selectedComponent = docLayout.getComponentByNodeId(selection.extent.nodeId);
    if (selectedComponent is ProxyDocumentComponent) {
      // The selected component is a proxy.
      // If this component displays text, the text component is bounded to childDocumentComponentKey.
      selectedComponent = selectedComponent.childDocumentComponentKey.currentState as DocumentComponent?;
    }

    if (selectedComponent == null) {
      editorImeLog.warning('A selection exists but no component for node ${selection.extent.nodeId} was found');
      return;
    }

    if (selectedComponent is! TextComponentState) {
      // The selected component isn't a text component. We can't query its style.
      return;
    }

    final style = selectedComponent.getTextStyleAt(nodePosition.offset);
    SuperIme.instance.getImeConnectionForOwner(_myImeId)!.setStyle(
          fontFamily: style.fontFamily,
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          textDirection: selectedComponent.textDirection ?? TextDirection.ltr,
          textAlign: selectedComponent.textAlign ?? TextAlign.left,
        );
  }

  /// Compute the caret rect in the editor's content space.
  ///
  /// Returns `null` if we don't have a selection or if we can't get the caret rect
  /// from the document layout.
  Rect? _computeCaretRectInViewportSpace() {
    final selection = widget.editContext.composer.selection;
    if (selection == null) {
      return null;
    }

    final docLayout = widget.editContext.documentLayout;
    final rectInDocLayoutSpace = docLayout.getRectForPosition(selection.extent);

    if (rectInDocLayoutSpace == null) {
      return null;
    }

    final renderSliver = context.findRenderObject() as RenderSliver;

    // The value returned from getRectForPosition is in the document's layout coordinates.
    // As the document layout is scrollable, this rect might be outside of the viewport height.
    // Map the offset to the editor's viewport coordinates.
    final caretOffset = renderSliver.globalToLocal(
      docLayout.getGlobalOffsetFromDocumentOffset(rectInDocLayoutSpace.topLeft),
    );

    return caretOffset & rectInDocLayoutSpace.size;
  }

  /// Compute the size and transform of the selected node's visual component
  /// to the global coordinates.
  ///
  /// Returns `null` if the we don't have a selection, or if we can't find
  /// a component for the selected node.
  (Size size, Matrix4 transform)? _computeSizeAndTransformOfSelectNode() {
    final selection = widget.editContext.composer.selection;
    if (selection == null) {
      return null;
    }

    final documentLayout = widget.editContext.documentLayout;

    DocumentComponent? selectedComponent = documentLayout.getComponentByNodeId(selection.extent.nodeId);
    if (selectedComponent is ProxyDocumentComponent) {
      // The selected componente is a proxy.
      // If this component displays text, the text component is bounded to childDocumentComponentKey.
      selectedComponent = selectedComponent.childDocumentComponentKey.currentState as DocumentComponent;
    }

    if (selectedComponent == null) {
      editorImeLog.warning('A selection exists but no component for node ${selection.extent.nodeId} was found');
      return null;
    }

    final renderBox = selectedComponent.context.findRenderObject() as RenderBox;
    return (renderBox.size, renderBox.getTransformTo(null));
  }

  void _onPerformSelector(String selectorName) {
    final handler = widget.selectorHandlers[selectorName];
    if (handler == null) {
      editorImeLog.warning("No handler found for $selectorName");
      return;
    }

    handler(widget.editContext);
  }

  @override
  Widget build(BuildContext context) {
    return SuperEditorImeDebugVisuals(
      imeConnection: _ownedImeConnection,
      child: IntentBlocker(
        intents: CurrentPlatform.isApple ? appleBlockedIntents : nonAppleBlockedIntents,
        child: SuperEditorHardwareKeyHandler(
          focusNode: _focusNode,
          editContext: widget.editContext,
          keyboardActions: widget.hardwareKeyboardActions,
          autofocus: widget.autofocus,
          child: DocumentSelectionOpenAndCloseImePolicy(
            focusNode: _focusNode,
            editor: widget.editContext.editor,
            selection: widget.editContext.composer.selectionNotifier,
            inputId: _myImeId,
            imeClientFactory: () => _imeClient,
            imeConfiguration: _textInputConfiguration,
            openKeyboardOnSelectionChange: widget.imePolicies.openKeyboardOnSelectionChange,
            closeKeyboardOnSelectionLost: widget.imePolicies.closeKeyboardOnSelectionLost,
            clearSelectionWhenEditorLosesFocus: widget.clearSelectionWhenEditorLosesFocus,
            clearSelectionWhenImeConnectionCloses: widget.clearSelectionWhenImeConnectionCloses,
            child: ImeFocusPolicy(
              focusNode: _focusNode,
              inputId: _myImeId,
              imeClientFactory: () => _imeClient,
              imeConfiguration: _textInputConfiguration,
              openImeOnPrimaryFocusGain: widget.imePolicies.openKeyboardOnGainPrimaryFocus,
              closeImeOnPrimaryFocusLost: widget.imePolicies.closeKeyboardOnLosePrimaryFocus,
              openImeOnNonPrimaryFocusGain: widget.imePolicies.openImeOnNonPrimaryFocusGain,
              closeImeOnNonPrimaryFocusLost: widget.imePolicies.closeImeOnNonPrimaryFocusLost,
              child: SoftwareKeyboardOpener(
                controller: widget.softwareKeyboardController,
                inputId: _myImeId,
                createImeClient: () => _imeClient,
                createImeConfiguration: () => _textInputConfiguration,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A callback to handle a `performSelector` call.
typedef SuperEditorSelectorHandler = void Function(SuperEditorContext context);

void moveLeft(SuperEditorContext context) {
  context.commonOps.moveCaretUpstream();
}

void moveRight(SuperEditorContext context) {
  context.commonOps.moveCaretDownstream();
}

void moveUp(SuperEditorContext context) {
  context.commonOps.moveCaretUp();
}

void moveDown(SuperEditorContext context) {
  context.commonOps.moveCaretDown();
}

void moveWordLeft(SuperEditorContext context) {
  context.commonOps.moveCaretUpstream(movementModifier: MovementModifier.word);
}

void moveWordRight(SuperEditorContext context) {
  context.commonOps.moveCaretDownstream(movementModifier: MovementModifier.word);
}

void moveToLeftEndOfLine(SuperEditorContext context) {
  context.commonOps.moveCaretUpstream(movementModifier: MovementModifier.line);
}

void moveToRightEndOfLine(SuperEditorContext context) {
  context.commonOps.moveCaretDownstream(movementModifier: MovementModifier.line);
}

void moveToBeginningOfParagraph(SuperEditorContext context) {
  context.commonOps.moveCaretUpstream(movementModifier: MovementModifier.paragraph);
}

void moveToEndOfParagraph(SuperEditorContext context) {
  context.commonOps.moveCaretDownstream(movementModifier: MovementModifier.paragraph);
}

void moveToBeginningOfDocument(SuperEditorContext context) {
  context.commonOps.moveSelectionToBeginningOfDocument(expand: false);
}

void moveToEndOfDocument(SuperEditorContext context) {
  context.commonOps.moveSelectionToEndOfDocument(expand: false);
}

void moveLeftAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveCaretUpstream(expand: true);
}

void moveRightAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveCaretDownstream(expand: true);
}

void moveUpAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveCaretUp(expand: true);
}

void moveDownAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveCaretDown(expand: true);
}

void moveWordLeftAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveCaretUpstream(
    expand: true,
    movementModifier: MovementModifier.word,
  );
}

void moveWordRightAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveCaretDownstream(
    expand: true,
    movementModifier: MovementModifier.word,
  );
}

void moveToLeftEndOfLineAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveCaretUpstream(
    expand: true,
    movementModifier: MovementModifier.line,
  );
}

void moveParagraphBackwardAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveCaretUpstream(
    expand: true,
    movementModifier: MovementModifier.paragraph,
  );
}

void moveParagraphForwardAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveCaretDownstream(
    expand: true,
    movementModifier: MovementModifier.paragraph,
  );
}

void moveToBeginningOfDocumentAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveSelectionToBeginningOfDocument(expand: true);
}

void moveToEndOfDocumentAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveSelectionToEndOfDocument(expand: true);
}

void moveToRightEndOfLineAndModifySelection(SuperEditorContext context) {
  context.commonOps.moveCaretDownstream(
    expand: true,
    movementModifier: MovementModifier.line,
  );
}

void indentListItem(SuperEditorContext context) {
  context.commonOps.indentListItem();
}

void unIndentListItem(SuperEditorContext context) {
  context.commonOps.unindentListItem();
}

void insertNewLine(SuperEditorContext context) {
  if (CurrentPlatform.isWeb) {
    return;
  }
  context.editor.execute([
    InsertNewlineAtCaretRequest(),
  ]);
}

void deleteWordBackward(SuperEditorContext context) {
  bool didMove = false;

  didMove = context.commonOps.moveCaretUpstream(
    expand: true,
    movementModifier: MovementModifier.word,
  );

  if (didMove) {
    context.commonOps.deleteSelection(TextAffinity.upstream);
  }
}

void deleteWordForward(SuperEditorContext context) {
  bool didMove = false;

  didMove = context.commonOps.moveCaretDownstream(
    expand: true,
    movementModifier: MovementModifier.word,
  );

  if (didMove) {
    context.commonOps.deleteSelection(TextAffinity.downstream);
  }
}

void deleteToBeginningOfLine(SuperEditorContext context) {
  bool didMove = false;

  didMove = context.commonOps.moveCaretUpstream(
    expand: true,
    movementModifier: MovementModifier.line,
  );

  if (didMove) {
    context.commonOps.deleteSelection(TextAffinity.upstream);
  }
}

void deleteToEndOfLine(SuperEditorContext context) {
  bool didMove = false;

  didMove = context.commonOps.moveCaretDownstream(
    expand: true,
    movementModifier: MovementModifier.line,
  );

  if (didMove) {
    context.commonOps.deleteSelection(TextAffinity.downstream);
  }
}

void deleteBackward(SuperEditorContext context) {
  if (CurrentPlatform.isWeb) {
    return;
  }
  context.commonOps.deleteUpstream();
}

void deleteForward(SuperEditorContext context) {
  if (CurrentPlatform.isWeb) {
    return;
  }
  context.commonOps.deleteDownstream();
}

void scrollToBeginningOfDocument(SuperEditorContext context) {
  context.scroller.animateTo(
    context.scroller.minScrollExtent,
    duration: const Duration(milliseconds: 150),
    curve: Curves.decelerate,
  );
}

void scrollToEndOfDocument(SuperEditorContext context) {
  context.scroller.animateTo(
    context.scroller.maxScrollExtent,
    duration: const Duration(milliseconds: 150),
    curve: Curves.decelerate,
  );
}

void scrollPageUp(SuperEditorContext context) {
  context.scroller.animateTo(
    max(context.scroller.scrollOffset - context.scroller.viewportDimension, context.scroller.minScrollExtent),
    duration: const Duration(milliseconds: 150),
    curve: Curves.decelerate,
  );
}

void scrollPageDown(SuperEditorContext context) {
  context.scroller.animateTo(
    min(context.scroller.scrollOffset + context.scroller.viewportDimension, context.scroller.maxScrollExtent),
    duration: const Duration(milliseconds: 150),
    curve: Curves.decelerate,
  );
}

/// A collection of policies that dictate how a [SuperEditor]'s focus, selection, and
/// IME should interact, such as opening the software keyboard whenever [SuperEditor]'s
/// selection changes ([openKeyboardOnSelectionChange]).
class SuperEditorImePolicies {
  const SuperEditorImePolicies({
    this.openKeyboardOnGainPrimaryFocus = true,
    this.closeKeyboardOnLosePrimaryFocus = false,
    this.openImeOnNonPrimaryFocusGain = true,
    this.closeImeOnNonPrimaryFocusLost = true,
    this.openKeyboardOnSelectionChange = true,
    this.closeKeyboardOnSelectionLost = true,
  });

  /// Whether to automatically raise the software keyboard when [SuperEditor]
  /// gains primary focus (not just regular focus).
  ///
  /// Defaults to `true`.
  final bool openKeyboardOnGainPrimaryFocus;

  /// Whether to automatically close the software keyboard when [SuperEditor]
  /// loses primary focus (even if it retains regular focus).
  ///
  /// Defaults to `false`, so that affordances, like a popover, can take primary
  /// focus, while still sending IME content input to `SuperEditor` at the same
  /// time.
  final bool closeKeyboardOnLosePrimaryFocus;

  /// Whether to open an IME connection when `SuperEditor` gains NON-primary focus.
  ///
  /// Defaults to `true`.
  final bool openImeOnNonPrimaryFocusGain;

  /// Whether to close the IME connection when `SuperEditor` loses NON-primary focus.
  ///
  /// Defaults to `true`.
  final bool closeImeOnNonPrimaryFocusLost;

  /// {@template openKeyboardOnSelectionChange}
  /// Whether the software keyboard should be raised whenever the editor's selection
  /// changes, such as when a user taps to place the caret.
  ///
  /// In a typical app, this property should be `true`. In some apps, the keyboard
  /// needs to be closed and opened to reveal special editing controls. In those cases
  /// this property should probably be `false`, and the app should take responsibility
  /// for opening and closing the keyboard.
  /// {@endtemplate}
  final bool openKeyboardOnSelectionChange;

  /// Whether the software keyboard should be closed whenever the editor goes from
  /// having a selection to not having a selection.
  ///
  /// In a typical app, this property should be `true`, because there's no place to
  /// apply IME input when there's no editor selection.
  final bool closeKeyboardOnSelectionLost;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuperEditorImePolicies &&
          runtimeType == other.runtimeType &&
          openKeyboardOnGainPrimaryFocus == other.openKeyboardOnGainPrimaryFocus &&
          closeKeyboardOnLosePrimaryFocus == other.closeKeyboardOnLosePrimaryFocus &&
          openImeOnNonPrimaryFocusGain == other.openImeOnNonPrimaryFocusGain &&
          closeImeOnNonPrimaryFocusLost == other.closeImeOnNonPrimaryFocusLost &&
          openKeyboardOnSelectionChange == other.openKeyboardOnSelectionChange &&
          closeKeyboardOnSelectionLost == other.closeKeyboardOnSelectionLost;

  @override
  int get hashCode =>
      openKeyboardOnGainPrimaryFocus.hashCode ^
      closeKeyboardOnLosePrimaryFocus.hashCode ^
      openImeOnNonPrimaryFocusGain.hashCode ^
      closeImeOnNonPrimaryFocusLost.hashCode ^
      openKeyboardOnSelectionChange.hashCode ^
      closeKeyboardOnSelectionLost.hashCode;
}

/// Input Method Engine (IME) configuration for document text input.
class SuperEditorImeConfiguration {
  const SuperEditorImeConfiguration({
    this.enableAutocorrect = true,
    this.enableSuggestions = true,
    this.keyboardBrightness = Brightness.light,
    this.keyboardActionButton = TextInputAction.newline,
  });

  /// Whether the OS should offer auto-correction options to the user.
  final bool enableAutocorrect;

  /// Whether the OS should offer text completion suggestions to the user.
  final bool enableSuggestions;

  /// The brightness of the software keyboard (only applies to platforms
  /// with a software keyboard).
  final Brightness keyboardBrightness;

  /// The action button that's displayed on a software keyboard, e.g.,
  /// new-line, done, go, etc.
  final TextInputAction keyboardActionButton;

  /// Converts this configuration to a [TextInputConfiguration] that can be used to attach to the IME.
  ///
  /// The [viewId] is required do determine the view that the text input belongs to. You can call
  /// `View.of(context).viewId` to get the current view's ID.
  TextInputConfiguration toTextInputConfiguration({
    required int viewId,
  }) {
    return TextInputConfiguration(
      viewId: viewId,
      enableDeltaModel: true,
      inputType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      autocorrect: enableAutocorrect,
      enableSuggestions: enableSuggestions,
      inputAction: keyboardActionButton,
      keyboardAppearance: keyboardBrightness,
    );
  }

  SuperEditorImeConfiguration copyWith({
    bool? enableAutocorrect,
    bool? enableSuggestions,
    Brightness? keyboardBrightness,
    TextInputAction? keyboardActionButton,
    bool? clearSelectionWhenImeDisconnects,
  }) {
    return SuperEditorImeConfiguration(
      enableAutocorrect: enableAutocorrect ?? this.enableAutocorrect,
      enableSuggestions: enableSuggestions ?? this.enableSuggestions,
      keyboardBrightness: keyboardBrightness ?? this.keyboardBrightness,
      keyboardActionButton: keyboardActionButton ?? this.keyboardActionButton,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuperEditorImeConfiguration &&
          runtimeType == other.runtimeType &&
          enableAutocorrect == other.enableAutocorrect &&
          enableSuggestions == other.enableSuggestions &&
          keyboardBrightness == other.keyboardBrightness &&
          keyboardActionButton == other.keyboardActionButton;

  @override
  int get hashCode =>
      enableAutocorrect.hashCode ^
      enableSuggestions.hashCode ^
      keyboardBrightness.hashCode ^
      keyboardActionButton.hashCode;
}
