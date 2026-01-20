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

    swizzleFlutterPaste()
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

  private static func swizzleFlutterPaste() {
    // 1. Locate the private Flutter engine class
    guard let flutterClass = NSClassFromString("FlutterTextInputView") else {
      log("RichPastePlugin: Could not find FlutterTextInputView")
      return
    }

    let originalSelector = #selector(UIResponder.paste(_:))
    let swizzledSelector = #selector(customPaste(_:))

    // 2. Get the methods
    guard let originalMethod = class_getInstanceMethod(flutterClass, originalSelector),
          let swizzledMethod = class_getInstanceMethod(SuperEditorClipboardPlugin.self, swizzledSelector) else {
      return
    }

    // 3. Inject our custom method into the Flutter engine class
    let didAddMethod = class_addMethod(
      flutterClass,
      swizzledSelector,
      method_getImplementation(swizzledMethod),
      method_getTypeEncoding(swizzledMethod)
    )

    if didAddMethod {
      // 4. Swap the pointers
      let newMethod = class_getInstanceMethod(flutterClass, swizzledSelector)!
      method_exchangeImplementations(originalMethod, newMethod)
    }
  }

  // This method is "moved" into FlutterTextInputView at runtime.
  // 'self' inside this method will actually be the FlutterTextInputView instance.
  @objc func customPaste(_ sender: Any?) {
    if (!SuperEditorClipboardPlugin.doCustomPaste) {
      SuperEditorClipboardPlugin.log("Running regular Flutter paste")
      // FALLBACK:
      // This calls the ORIGINAL paste logic.
      // Because we swapped the methods, calling 'customPaste' on 'self'
      // now triggers the engine's original 'insertText' flow.
      if self.responds(to: #selector(customPaste(_:))) {
        self.perform(#selector(customPaste(_:)), with: sender)
      }

      return;
    }

    SuperEditorClipboardPlugin.log("Running custom paste")
    SuperEditorClipboardPlugin.channel?.invokeMethod("paste", arguments: nil)
  }

  public static let isLoggingEnabled = false

  internal static func log(_ message: String) {
    if isLoggingEnabled {
      print("[SuperEditorClipboardPlugin] \(message)")
    }
  }
}

