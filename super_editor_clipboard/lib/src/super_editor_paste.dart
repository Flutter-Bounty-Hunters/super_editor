import 'dart:async';

import 'package:flutter/material.dart' show Colors;
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

/// [DocumentNode] that represents an image at a URL.
@immutable
class BitmapImageNode extends BlockNode {
  BitmapImageNode({
    required this.id,
    required this.imageData,
    this.expectedBitmapSize,
    this.altText = '',
    super.metadata,
  }) {
    initAddToMetadata({NodeMetadata.blockType: const NamedAttribution("image")});
  }

  @override
  final String id;

  final Uint8List imageData;

  /// The expected size of the image.
  ///
  /// Used to size the component while the image is still being loaded,
  /// so the content don't shift after the image is loaded.
  ///
  /// It's technically permissible to provide only a single expected dimension,
  /// however providing only a single dimension won't provide enough information
  /// to size an image component before the image is loaded. Providing only a
  /// width in a vertical layout won't have any visual effect. Providing only a height
  /// in a vertical layout will likely take up more space or less space than the final
  /// image because the final image will probably be scaled. Therefore, to take
  /// advantage of [ExpectedSize], you should try to provide both dimensions.
  final ExpectedSize? expectedBitmapSize;

  final String altText;

  @override
  String? copyContent(dynamic selection) {
    if (selection is! UpstreamDownstreamNodeSelection) {
      throw Exception('ImageNode can only copy content from a UpstreamDownstreamNodeSelection.');
    }

    // TODO: How do we serialize an image?
    return !selection.isCollapsed ? "" : null;
  }

  @override
  bool hasEquivalentContent(DocumentNode other) {
    return other is BitmapImageNode &&
        altText == other.altText &&
        imageData.length == other.imageData.length &&
        imageData == other.imageData;
  }

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    return BitmapImageNode(
      id: id,
      imageData: imageData,
      expectedBitmapSize: expectedBitmapSize,
      altText: altText,
      metadata: {...metadata, ...newProperties},
    );
  }

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    return BitmapImageNode(
      id: id,
      imageData: imageData,
      expectedBitmapSize: expectedBitmapSize,
      altText: altText,
      metadata: newMetadata,
    );
  }

  BitmapImageNode copy() {
    return BitmapImageNode(
      id: id,
      imageData: imageData,
      expectedBitmapSize: expectedBitmapSize,
      altText: altText,
      metadata: Map.from(metadata),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BitmapImageNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          altText == other.altText &&
          imageData.length == other.imageData.length &&
          imageData == other.imageData;

  @override
  int get hashCode => id.hashCode ^ imageData.hashCode ^ altText.hashCode;
}

class BitmapImageComponentBuilder implements ComponentBuilder {
  const BitmapImageComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! BitmapImageNode) {
      return null;
    }

    return BitmapImageComponentViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      imageData: node.imageData,
      expectedSize: node.expectedBitmapSize,
      selectionColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! BitmapImageComponentViewModel) {
      return null;
    }

    return BitmapImageComponent(
      componentKey: componentContext.componentKey,
      imageData: componentViewModel.imageData,
      expectedSize: componentViewModel.expectedSize,
      selection: componentViewModel.selection?.nodeSelection as UpstreamDownstreamNodeSelection?,
      selectionColor: componentViewModel.selectionColor,
      opacity: componentViewModel.opacity,
    );
  }
}

class BitmapImageComponentViewModel extends SingleColumnLayoutComponentViewModel with SelectionAwareViewModelMixin {
  BitmapImageComponentViewModel({
    required super.nodeId,
    super.createdAt,
    super.maxWidth,
    super.padding = EdgeInsets.zero,
    super.opacity = 1.0,
    required this.imageData,
    this.expectedSize,
    DocumentNodeSelection? selection,
    Color selectionColor = Colors.transparent,
  }) {
    this.selection = selection;
    this.selectionColor = selectionColor;
  }

  Uint8List imageData;
  ExpectedSize? expectedSize;

  @override
  BitmapImageComponentViewModel copy() {
    return BitmapImageComponentViewModel(
      nodeId: nodeId,
      createdAt: createdAt,
      maxWidth: maxWidth,
      padding: padding,
      opacity: opacity,
      imageData: imageData,
      expectedSize: expectedSize,
      selection: selection,
      selectionColor: selectionColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is ImageComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          createdAt == other.createdAt &&
          selection == other.selection &&
          selectionColor == other.selectionColor &&
          imageData.length == other.imageUrl.length &&
          imageData == imageData;

  @override
  int get hashCode =>
      super.hashCode ^
      nodeId.hashCode ^
      createdAt.hashCode ^
      imageData.hashCode ^
      selection.hashCode ^
      selectionColor.hashCode;
}

/// Displays an image in a document.
class BitmapImageComponent extends StatelessWidget {
  const BitmapImageComponent({
    super.key,
    required this.componentKey,
    required this.imageData,
    this.expectedSize,
    this.selectionColor = Colors.blue,
    this.selection,
    this.opacity = 1.0,
  });

  final GlobalKey componentKey;
  final Uint8List imageData;
  final ExpectedSize? expectedSize;
  final Color selectionColor;
  final UpstreamDownstreamNodeSelection? selection;

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      hitTestBehavior: HitTestBehavior.translucent,
      child: IgnorePointer(
        child: Center(
          child: SelectableBox(
            selection: selection,
            selectionColor: selectionColor,
            child: BoxComponent(
              key: componentKey,
              opacity: opacity,
              child: Image.memory(
                imageData,
                fit: BoxFit.contain,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (frame != null) {
                    // The image is already loaded. Use the image as is.
                    return child;
                  }

                  if (expectedSize != null && expectedSize!.width != null && expectedSize!.height != null) {
                    // Both width and height were provide.
                    // Preserve the aspect ratio of the original image.
                    return AspectRatio(
                      aspectRatio: expectedSize!.aspectRatio,
                      child: SizedBox(width: expectedSize!.width!.toDouble(), height: expectedSize!.height!.toDouble()),
                    );
                  }

                  // The image is still loading and only one dimension was provided.
                  // Use the given dimension.
                  return SizedBox(width: expectedSize?.width?.toDouble(), height: expectedSize?.height?.toDouble());
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
