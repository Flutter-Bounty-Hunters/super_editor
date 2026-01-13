import Flutter
import UIKit

public class SuperEditorClipboardPlugin: NSObject, FlutterPlugin {
  static var channel: FlutterMethodChannel?

  // `true` to run a custom paste implementation, or `false` to defer to the
  // standard Flutter paste behavior.
  static var doCustomPaste = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    print("Registering SuperEditorClipboardPlugin")
    let channel = FlutterMethodChannel(name: "super_editor_clipboard.ios", binaryMessenger: registrar.messenger())
    self.channel = channel

    let instance = SuperEditorClipboardPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    swizzleFlutterPaste()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("Received call on iOS side: \(call.method)")
    switch call.method {
    case "enableCustomPaste":
      print("iOS platform - enabling custom paste")
      SuperEditorClipboardPlugin.doCustomPaste = true
    case "disableCustomPaste":
      print("iOS platform - disabling custom paste")
      SuperEditorClipboardPlugin.doCustomPaste = false
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func swizzleFlutterPaste() {
    // 1. Locate the private Flutter engine class
    guard let flutterClass = NSClassFromString("FlutterTextInputView") else {
      print("RichPastePlugin: Could not find FlutterTextInputView")
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
      print("Running regular Flutter paste")
      // FALLBACK:
      // This calls the ORIGINAL paste logic.
      // Because we swapped the methods, calling 'customPaste' on 'self'
      // now triggers the engine's original 'insertText' flow.
      if self.responds(to: #selector(customPaste(_:))) {
        self.perform(#selector(customPaste(_:)), with: sender)
      }

      return;
    }

    print("Running custom paste")
    SuperEditorClipboardPlugin.channel?.invokeMethod("paste", arguments: nil)

//    let pasteboard = UIPasteboard.general
//
//    // INTERCEPTION LOGIC:
//    // Check for Image URL string or Image Data
//    if let content = pasteboard.string, content.hasSuffix(".png") || content.hasSuffix(".jpg") {
//      // Send back to Dart
////      RichPastePlugin.channel?.invokeMethod("onRichPaste", arguments: ["type": "image_url", "data": content])
//
//      // If we handle it, we return early to prevent the engine from pasting text
//      return
//    }
  }
}

