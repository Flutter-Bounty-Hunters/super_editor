import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_clipboard/src/editor_paste.dart';
import 'package:super_editor_clipboard/src/logging.dart';
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

Future<void> _pasteFromClipboard(Editor editor, [CustomPasteDataInserter? customPasteDataInserter]) async {
  final clipboard = SystemClipboard.instance;
  if (clipboard == null) {
    return;
  }

  final reader = await clipboard.read();
  var didPaste = false;

  // Try to read and paste a custom data type, if the app provided an inserter.
  if (customPasteDataInserter != null) {
    didPaste = await customPasteDataInserter(editor, reader);
  }
  if (didPaste) {
    return;
  }

  // Try to paste a bitmap image.
  didPaste = await _maybePasteImage(editor, reader);
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
  for (final bitmapFormat in _supportedBitmapImageFormats) {
    if (reader.canProvide(bitmapFormat)) {
      // We can read this bitmap type. Read it, and insert it.
      reader.getFile(bitmapFormat, (file) async {
        // Read the bitmap image data.
        final imageData = await file.readAll();

        // Decode the image so that we can get the size. The size is important because it's what
        // facilitates auto-scrolling to the bottom of an image that exceeds the current viewport
        // height.
        final image = await decodeImageFromList(imageData);

        // Insert the bitmap image into the Document.
        editor.execute([
          InsertNodeAtCaretRequest(
            node: BitmapImageNode(
              id: Editor.createNodeId(),
              imageData: imageData,
              expectedBitmapSize: ExpectedSize(image.width, image.height),
            ),
          ),
        ]);
      });

      return true;
    }
  }

  return false;
}

const _supportedBitmapImageFormats = [
  Formats.png,
  Formats.jpeg,
  Formats.heic,
  Formats.gif,
  Formats.bmp,
  Formats.webp,
];

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
    CustomPasteDataInserter? customPasteDataInserter,
    super.useIosSelectionHeuristics = true,
    super.handleColor,
    super.floatingCursorController,
    super.magnifierBuilder,
    super.createOverlayControlsClipper,
  }) : _customPasteDataInserter = customPasteDataInserter {
    shouldShowToolbar.addListener(_onToolbarVisibilityChange);
  }

  @override
  void dispose() {
    // In case we enabled custom native paste, disable it on disposal.
    if (SuperEditorClipboardIosPlugin.isPasteOwner(this)) {
      SECLog.pasteIOS.fine("SuperEditorIosControlsControllerWithNativePaste is releasing paste");
    }
    SuperEditorClipboardIosPlugin.disableCustomPaste(this);
    SuperEditorClipboardIosPlugin.releasePasteOwnership(this);

    shouldShowToolbar.removeListener(_onToolbarVisibilityChange);
    super.dispose();
  }

  final CustomPasteDataInserter? _customPasteDataInserter;

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
      SECLog.pasteIOS.fine("SuperEditorIosControlsControllerWithNativePaste is taking over paste on toolbar show");
      SuperEditorClipboardIosPlugin.takePasteOwnership(this);
      SuperEditorClipboardIosPlugin.enableCustomPaste(this, this);
    } else {
      // The native iOS toolbar is no longer visible.
      SECLog.pasteIOS.fine("SuperEditorIosControlsControllerWithNativePaste is releasing paste on toolbar hide");
      SuperEditorClipboardIosPlugin.releasePasteOwnership(this);
    }
  }

  @override
  Future<void> onUserRequestedPaste() async {
    SECLog.pasteIOS.fine("User requested to paste - pasting from super_clipboard");
    _pasteFromClipboard(editor, _customPasteDataInserter);
  }
}

typedef CustomPasteDataInserter = Future<bool> Function(Editor editor, ClipboardReader clipboardReader);
