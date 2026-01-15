import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SuperEditorClipboardIosPlugin {
  @visibleForTesting
  static final methodChannel = const MethodChannel('super_editor_clipboard.ios');

  @visibleForTesting
  static const messageToPlatformEnableCustomPaste = "enableCustomPaste";
  @visibleForTesting
  static const messageToPlatformDisableCustomPaste = "disableCustomPaste";

  @visibleForTesting
  static const messageFromPlatformPaste = "paste";

  /// Returns `true` if paste functionality currently has an owner, or `false` if nothing
  /// currently owns the native paste functionality.
  static bool get isPasteOwned => _pasteOwner != null;

  /// Returns `true` if the given [owner] is currently the owner of the native paste functionality,
  /// or `false` if it's not.
  static bool isPasteOwner(Object owner) => _pasteOwner == owner;

  /// The object that owns control over this plugin.
  ///
  /// Only the owner can enable or disable this plugin. The concept of an owner exists to help
  /// multiple text fields and editors co-exist, without interfering with each other's claim over
  /// pasting behavior.
  ///
  /// A text field or editor should only make itself the owner when it believes that it has
  /// focus. Following this policy should minimize the possibility that paste happens in one field
  /// but ends up being handled by another.
  static Object? _pasteOwner;

  /// Makes the [newOwner] the owner of native paste functionality, which can then
  /// call [enableCustomPaste] and [disableCustomPaste].
  static void takePasteOwnership(Object newOwner) {
    _pasteOwner = newOwner;
  }

  /// Releases ownership of native paste, if [owner] is currently the native paste owner.
  static void releasePasteOwnership(Object owner) {
    if (owner != _pasteOwner) {
      return;
    }

    // Paste ownership was released, so there's currently no paste owner.
    // Therefore, disable custom native paste.
    disableCustomPaste(_pasteOwner!);

    _pasteOwner = null;
  }

  static CustomPasteDelegate? _customPasteDelegate;

  /// Overrides Flutter's built-in iOS paste behavior by instead calling a method
  /// on the [delegate] when the user presses "paste".
  ///
  /// Does nothing if the given [pasteOwner] is currently the owner of this plugin.
  static void enableCustomPaste(Object pasteOwner, CustomPasteDelegate delegate) {
    if (pasteOwner != _pasteOwner) {
      return;
    }

    if (_customPasteDelegate != null) {
      // Custom paste is already enabled. Just replace the existing delegate
      // with the new one.
      _customPasteDelegate = delegate;
      return;
    }

    _customPasteDelegate = delegate;

    methodChannel.invokeMethod(messageToPlatformEnableCustomPaste);
    methodChannel.setMethodCallHandler(_onMessageFromPlatform);
  }

  static Future<void> _onMessageFromPlatform(MethodCall call) async {
    if (call.method == messageFromPlatformPaste) {
      if (_customPasteDelegate == null) {
        // TODO: Log a warning that we're missing a delegate
        return;
      }

      _customPasteDelegate!.onUserRequestedPaste();
    }
  }

  /// Disables our override of Flutter's iOS paste behavior, returning to Flutter's original
  /// paste behavior.
  static void disableCustomPaste(Object owner) {
    if (owner != _pasteOwner) {
      return;
    }

    _customPasteDelegate = null;
    methodChannel.invokeMethod(messageToPlatformDisableCustomPaste);
  }
}

/// Delegate that implements the iOS paste behavior when the user taps on "paste"
/// on the native iOS popover toolbar.
///
/// It's the delegate's responsibility to query the clipboard and decide what to do
/// with the content.
abstract class CustomPasteDelegate {
  void onUserRequestedPaste();
}
