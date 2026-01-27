import Flutter
import UIKit

public class SuperEditorClipboardPlugin: NSObject, FlutterPlugin {
  static var channel: FlutterMethodChannel?

  // `true` to run a custom paste implementation, or `false` to defer to the
  // standard Flutter paste behavior.
  static var doCustomPaste = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    log("Registering SuperEditorClipboardPlugin")
    let channel = FlutterMethodChannel(name: "super_editor_clipboard.ios", binaryMessenger: registrar.messenger())
    self.channel = channel

    let instance = SuperEditorClipboardPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    // Swizzle both the action execution (paste) and the validation (canPerformAction)
    swizzleFlutterPaste()
    swizzleCanPerformAction()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    SuperEditorClipboardPlugin.log("Received call on iOS side: \(call.method)")
    switch call.method {
    case "enableCustomPaste":
      SuperEditorClipboardPlugin.log("iOS platform - enabling custom paste")
      SuperEditorClipboardPlugin.doCustomPaste = true
    case "disableCustomPaste":
      SuperEditorClipboardPlugin.log("iOS platform - disabling custom paste")
      SuperEditorClipboardPlugin.doCustomPaste = false
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Swizzling Logic

  private static func swizzleFlutterPaste() {
    swizzle(
        clsName: "FlutterTextInputView",
        originalSelector: #selector(UIResponder.paste(_:)),
        customSelector: #selector(customPaste(_:))
    )
  }

  private static func swizzleCanPerformAction() {
    swizzle(
        clsName: "FlutterTextInputView",
        originalSelector: #selector(UIResponder.canPerformAction(_:withSender:)),
        customSelector: #selector(customCanPerformAction(_:withSender:))
    )
  }

  private static func swizzle(clsName: String, originalSelector: Selector, customSelector: Selector) {
    guard let flutterClass = NSClassFromString(clsName) else {
      log("Could not find \(clsName)")
      return
    }

    guard let originalMethod = class_getInstanceMethod(flutterClass, originalSelector),
          let swizzledMethod = class_getInstanceMethod(SuperEditorClipboardPlugin.self, customSelector) else {
      log("Could not find methods to swizzle for \(clsName)")
      return
    }

    // Add the custom method to the Flutter class
    let didAddMethod = class_addMethod(
      flutterClass,
      customSelector,
      method_getImplementation(swizzledMethod),
      method_getTypeEncoding(swizzledMethod)
    )

    if didAddMethod {
      // Exchange implementations so 'originalSelector' calls our custom code,
      // and 'customSelector' calls the original code.
      let newMethod = class_getInstanceMethod(flutterClass, customSelector)!
      method_exchangeImplementations(originalMethod, newMethod)
      log("Successfully swizzled \(originalSelector) in \(clsName)")
    } else {
        log("Failed to add method \(customSelector) to \(clsName)")
    }
  }

  // MARK: - Custom Implementations

  /// This method replaces `paste(_:)` at runtime.
  @objc func customPaste(_ sender: Any?) {
    if (!SuperEditorClipboardPlugin.doCustomPaste) {
      SuperEditorClipboardPlugin.log("Running regular Flutter paste")
      // FALLBACK: Call original implementation (which is now mapped to customPaste)
      if self.responds(to: #selector(customPaste(_:))) {
        self.perform(#selector(customPaste(_:)), with: sender)
      }
      return
    }

    SuperEditorClipboardPlugin.log("Running custom paste")
    SuperEditorClipboardPlugin.channel?.invokeMethod("paste", arguments: nil)
  }

  /// This method replaces `canPerformAction(_:withSender:)` at runtime.
  @objc func customCanPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    let isPasteAction = action == #selector(UIResponderStandardEditActions.paste(_:))

    // 1. If it is the PASTE action AND we are in custom mode, check our broader conditions.
    if isPasteAction && SuperEditorClipboardPlugin.doCustomPaste {
        // Check for ANY pasteable content (Images, Colors, URLs, Strings)
        // Note: Flutter only checks `hasStrings`.
        if UIPasteboard.general.hasStrings ||
           UIPasteboard.general.hasImages ||
           UIPasteboard.general.hasURLs ||
           UIPasteboard.general.hasColors {
            return true
        }
    }

    // 2. Otherwise (or if the custom check failed), fall back to the ORIGINAL logic.
    // Because we exchanged implementations, calling 'customCanPerformAction' here
    // actually invokes the original Flutter engine logic.

    // We cannot use 'perform' for Bool return types, so we use IMP casting.
    return SuperEditorClipboardPlugin.callOriginalCanPerformAction(
        instance: self,
        selector: #selector(customCanPerformAction(_:withSender:)),
        action: action,
        sender: sender
    )
  }

  // MARK: - Helpers

  /// Safely invokes the original implementation of `canPerformAction` (which is now swapped).
  private static func callOriginalCanPerformAction(instance: Any, selector: Selector, action: Selector, sender: Any?) -> Bool {
    guard let method = class_getInstanceMethod(object_getClass(instance), selector) else {
        return false
    }

    let imp = method_getImplementation(method)

    // Define the C function signature for (BOOL)objc_msgSend(id, SEL, SEL, id)
    typealias CanPerformActionFunction = @convention(c) (AnyObject, Selector, Selector, Any?) -> Bool

    let originalFunction = unsafeBitCast(imp, to: CanPerformActionFunction.self)

    // 'instance' is 'self' (FlutterTextInputView)
    // 'selector' is the selector triggering this IMP (customCanPerformAction)
    // 'action' is the argument (e.g., paste:)
    return originalFunction(instance as AnyObject, selector, action, sender)
  }

  public static let isLoggingEnabled = false

  internal static func log(_ message: String) {
    if isLoggingEnabled {
      print("[SuperEditorClipboardPlugin] \(message)")
    }
  }
}