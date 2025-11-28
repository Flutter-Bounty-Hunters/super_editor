import 'package:flutter/services.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

/// Base class for [TextInputConnection] decorators.
///
/// A decorator is an object that forwards calls to another, existing implementation
/// of a given interface, but adds or alters some of those behaviors.
abstract class TextInputConnectionDecorator implements TextInputConnection {
  TextInputConnectionDecorator([this.client]);

  TextInputConnection? client;

  @override
  bool get attached => client?.attached ?? false;

  @override
  bool get scribbleInProgress => client?.scribbleInProgress ?? false;

  @override
  void show() => client?.show();

  @override
  void setEditingState(TextEditingValue value) => client?.setEditingState(value);

  @override
  void updateConfig(TextInputConfiguration configuration) => client?.updateConfig(configuration);

  @override
  void setCaretRect(Rect rect) => client?.setCaretRect(rect);

  @override
  void setSelectionRects(List<SelectionRect> selectionRects) => client?.setSelectionRects(selectionRects);

  @override
  void setComposingRect(Rect rect) => client?.setComposingRect(rect);

  @override
  void setStyle(
          {required String? fontFamily,
          required double? fontSize,
          required FontWeight? fontWeight,
          required TextDirection textDirection,
          required TextAlign textAlign}) =>
      client?.setStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          fontWeight: fontWeight,
          textDirection: textDirection,
          textAlign: textAlign);

  @override
  void requestAutofill() => client?.requestAutofill();

  @override
  void setEditableSizeAndTransform(Size editableBoxSize, Matrix4 transform) =>
      client?.setEditableSizeAndTransform(editableBoxSize, transform);

  @override
  void connectionClosedReceived() => client?.connectionClosedReceived();

  @override
  void close() => client?.close();
}

/// A [DeltaTextInputClient] that forwards all calls to the given [_client].
///
/// Subclass [DeltaTextInputClientDecorator] to override specific
/// [DeltaTextInputClient] messages. To add behavior, instead of replacing it,
/// call the `super` method within an override.
class DeltaTextInputClientDecorator with TextInputClient, DeltaTextInputClient {
  DeltaTextInputClientDecorator([this._client]);

  /// Returns `true` if [client] is the current client for this decorator.
  ///
  /// This check is provided to users so that users can check if they're still
  /// the client before `null`'ing it out. E.g., Client1 registers itself as
  /// the client, then Client2 takes over and registers itself as the client,
  /// and then finally Client1 disposes and needs to know whether to remove
  /// itself as the client, or not.
  bool isCurrentClient(DeltaTextInputClient client) => _client == client;

  set client(DeltaTextInputClient? client) => _client = client;
  DeltaTextInputClient? _client;

  @override
  AutofillScope? get currentAutofillScope => _client?.currentAutofillScope;

  @override
  TextEditingValue? get currentTextEditingValue => _client?.currentTextEditingValue;

  @override
  void didChangeInputControl(TextInputControl? oldControl, TextInputControl? newControl) {
    _client?.didChangeInputControl(oldControl, newControl);
  }

  @override
  void insertTextPlaceholder(Size size) {
    _client?.insertTextPlaceholder(size);
  }

  @override
  void performAction(TextInputAction action) {
    _client?.performAction(action);
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    _client?.performPrivateCommand(action, data);
  }

  @override
  void performSelector(String selectorName) {
    _client?.performSelector(selectorName);
  }

  @override
  void removeTextPlaceholder() {
    _client?.removeTextPlaceholder();
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    _client?.showAutocorrectionPromptRect(start, end);
  }

  @override
  void showToolbar() {
    _client?.showToolbar();
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    _client?.updateEditingValue(value);
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    _client?.updateEditingValueWithDeltas(textEditingDeltas);
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    _client?.updateFloatingCursor(point);
  }

  @override
  void connectionClosed() {
    _client?.connectionClosed();
  }
}

/// A [DeltaTextInputClientDecorator] that notifies [_onConnectionClosed] when
/// the IME connection closes.
///
/// This decorator is needed because [TextInputConnection] has no way to listen
/// for when its connection is closed. By wrapping a [TextInputClient] with
/// this decorator, the code that owns the [TextInputConnection] can receive
/// a notification when the connection closes.
class ClosureAwareDeltaTextInputClientDecorator extends DeltaTextInputClientDecorator {
  ClosureAwareDeltaTextInputClientDecorator(
    this._onConnectionClosed, [
    DeltaTextInputClient? client,
  ]) : super(client);

  final VoidCallback _onConnectionClosed;

  @override
  void connectionClosed() {
    editorImeLog.fine("[ClosureAwareDeltaTextInputClientDecorator] - IME connection was closed");
    _onConnectionClosed();
    _client?.connectionClosed();
  }
}
