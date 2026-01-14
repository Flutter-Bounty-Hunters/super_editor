import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_clipboard/src/editor_paste.dart';
import 'package:super_editor_clipboard/src/plugin/ios/super_editor_clipboard_ios_plugin.dart';

/// Pastes rich text from the system clipboard when the user presses CMD+V on
/// Mac, or CTRL+V on Windows/Linux.
///
/// This method expects to find rich text on the system clipboard as HTML, which
/// is then converted to Markdown, and then converted to a [Document].
ExecutionInstruction pasteRichTextOnCmdCtrlV({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (!HardwareKeyboard.instance.isMetaPressed && !HardwareKeyboard.instance.isControlPressed) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.logicalKey != LogicalKeyboardKey.keyV) {
    return ExecutionInstruction.continueExecution;
  }

  // Cmd/Ctrl+V detected - handle clipboard paste
  _pasteFromClipboard(editContext.editor);

  return ExecutionInstruction.haltExecution;
}

Future<void> _pasteFromClipboard(Editor editor) async {
  final clipboard = SystemClipboard.instance;
  if (clipboard == null) {
    return;
  }

  final reader = await clipboard.read();

  // Try to paste a bitmap image.
  var didPaste = await _maybePasteImage(editor, reader);
  if (didPaste) {
    return;
  }

  // Try to paste rich text (via HTML).
  didPaste = await _maybePasteHtml(editor, reader);
  if (didPaste) {
    return;
  }

  // Fall back to plain text.
  _pastePlainText(editor, reader);
}

Future<bool> _maybePasteImage(Editor editor, ClipboardReader reader) async {
  if (reader.canProvide(Formats.jpeg)) {
    reader.getFile(Formats.jpeg, (file) async {
      // Do something with the PNG image
      final imageData = await file.readAll();

      editor.execute([
        InsertNodeAtCaretRequest(
          node: BitmapImageNode(id: Editor.createNodeId(), imageData: imageData),
        ),
      ]);
    });

    return true;
  }

  if (reader.canProvide(Formats.png)) {
    reader.getFile(Formats.png, (file) async {
      // Do something with the PNG image
      final pngImageData = await file.readAll();

      editor.execute([
        InsertNodeAtCaretRequest(
          node: BitmapImageNode(id: Editor.createNodeId(), imageData: pngImageData),
        ),
      ]);
    });

    return true;
  }

  return false;
}

Future<bool> _maybePasteHtml(Editor editor, ClipboardReader reader) async {
  final completer = Completer<bool>();

  reader.getValue(
    Formats.htmlText,
    (html) {
      if (html == null) {
        completer.complete(false);
        return;
      }

      // Do the paste.
      editor.pasteHtml(editor, html);

      completer.complete(true);
    },
    onError: (_) {
      completer.complete(false);
    },
  );

  final didPaste = await completer.future;
  return didPaste;
}

void _pastePlainText(Editor editor, ClipboardReader reader) {
  reader.getValue(Formats.plainText, (value) {
    if (value != null) {
      editor.execute([InsertPlainTextAtCaretRequest(value)]);
    }
  });
}

/// A [SuperEditorIosControlsController] which adds a custom implementation when the user
/// presses "paste" on the native iOS popover toolbar.
///
/// As of writing, Jan 2026, Flutter directly implements what happens when the user presses "paste" on
/// the native iOS popover toolbar. The Flutter implementation only pastes plain text, which prevents
/// pasting images or HTML or Markdown.
///
/// This controller uses the [SuperEditorClipboardIosPlugin] to intercept calls to "paste"
/// before they reach Flutter, and redirects those calls to this controller. This controller
/// then uses `super_clipboard` to inspect what's being pasted, and then take the appropriate
/// [Editor] action.
class SuperEditorIosControlsControllerWithNativePaste extends SuperEditorIosControlsController
    implements CustomPasteDelegate {
  SuperEditorIosControlsControllerWithNativePaste({
    required this.editor,
    required this.documentLayoutResolver,
    super.useIosSelectionHeuristics = true,
    super.handleColor,
    super.floatingCursorController,
    super.magnifierBuilder,
    super.createOverlayControlsClipper,
  }) {
    print("SuperEditorIosControlsControllerWithNativePaste is taking over paste");
    shouldShowToolbar.addListener(_onToolbarVisibilityChange);
  }

  @override
  void dispose() {
    // In case we enabled custom native paste, disable it on disposal.
    if (SuperEditorClipboardIosPlugin.isPasteOwner(this)) {
      print("SuperEditorIosControlsControllerWithNativePaste is releasing paste");
    }
    SuperEditorClipboardIosPlugin.disableCustomPaste(this);
    SuperEditorClipboardIosPlugin.releasePasteOwnership(this);

    shouldShowToolbar.removeListener(_onToolbarVisibilityChange);
    super.dispose();
  }

  @protected
  final Editor editor;

  @protected
  final DocumentLayoutResolver documentLayoutResolver;

  @override
  DocumentFloatingToolbarBuilder? get toolbarBuilder => (context, mobileToolbarKey, focalPoint) {
        if (editor.composer.selection == null) {
          return const SizedBox();
        }

        return iOSSystemPopoverEditorToolbarWithFallbackBuilder(
          context,
          mobileToolbarKey,
          focalPoint,
          CommonEditorOperations(
            document: editor.document,
            editor: editor,
            composer: editor.composer,
            documentLayoutResolver: documentLayoutResolver,
          ),
          SuperEditorIosControlsScope.rootOf(context),
        );
      };

  void _onToolbarVisibilityChange() {
    if (shouldShowToolbar.value) {
      // The native iOS toolbar is visible.
      print("SuperEditorIosControlsControllerWithNativePaste is taking over paste on toolbar show");
      SuperEditorClipboardIosPlugin.takePasteOwnership(this);
      SuperEditorClipboardIosPlugin.enableCustomPaste(this, this);
    } else {
      // The native iOS toolbar is no longer visible.
      print("SuperEditorIosControlsControllerWithNativePaste is releasing paste on toolbar hide");
      SuperEditorClipboardIosPlugin.disableCustomPaste(this);
      SuperEditorClipboardIosPlugin.releasePasteOwnership(this);
    }
  }

  @override
  Future<void> onUserRequestedPaste() async {
    print("User requested to paste - pasting from super_clipboard");
    _pasteFromClipboard(editor);
  }
}
