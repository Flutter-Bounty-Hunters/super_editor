import Flutter
import UIKit

public class SuperKeyboardPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = SuperKeyboardPlugin(binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(plugin, channel: plugin.channel!)
  }
  
  private var channel: FlutterMethodChannel?
  
//  private var displayLink: CADisplayLink?
  private weak var window: UIWindow?
  private var keyboardType: KeyboardType = .unknown
  private var keyboardFrame: CGRect = .zero
//  private var keyboardTimer: Timer?
//  private var isAnimating = false
  
  init(binaryMessenger: FlutterBinaryMessenger) {
    super.init()

    channel = FlutterMethodChannel(name: "super_keyboard_ios", binaryMessenger: binaryMessenger)

    // Register for keyboard notifications
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(_:)), name: UIResponder.keyboardDidShowNotification, object: nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidHide(_:)), name: UIResponder.keyboardDidHideNotification, object: nil)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startLogging":
      let sendPlatformLogsToDart = (call.arguments as? [String: Any])?["sendPlatformLogsToDart"] as? Bool ?? false

      SuperKeyboardLog.enable(reportTo: sendPlatformLogsToDart ? channel : nil)

      result(nil)
    case "stopLogging":
      SuperKeyboardLog.disable()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  @objc private func keyboardWillShow(_ notification: Notification) {
    SuperKeyboardLog.log(message: "Keyboard will show")
    channel!.invokeMethod("keyboardWillShow", arguments: nil)
  }
  
  @objc private func keyboardDidShow(_ notification: Notification) {
    guard let window = window else {
//      stopTrackingKeyboard()
      return
    }

    // Calculate the current keyboard height
    let screenHeight = window.bounds.height
    let keyboardHeight = max(0, screenHeight - keyboardFrame.origin.y)

    SuperKeyboardLog.log(message: "Keyboard Did Show")
    SuperKeyboardLog.log(message: "Keyboard height: \(keyboardFrame.height)")

    channel!.invokeMethod("keyboardDidShow", arguments: [
      "keyboardHeight": keyboardHeight
    ])
  }
  
  @objc private func keyboardWillChangeFrame(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
      return
    }
    SuperKeyboardLog.log(message: "Keyboard will change frame")

    // Set the final keyboard frame and track its position during animation
    keyboardFrame = endFrame
    window = UIApplication.shared.windows.first
    
    switch keyboardFrame {
    case let r where r.height <= 0:
      keyboardType = .unknown
    case let r where r.height < 100:
      keyboardType = .minimized
    default:
      keyboardType = .full
    }

    SuperKeyboardLog.log(message: "New target keyboard height: \(keyboardFrame.height)")
    channel!.invokeMethod("keyboardWillChangeFrame", arguments: [
      "keyboardType": keyboardType.description,
      "targetKeyboardHeight": keyboardFrame.height
    ])
    
//    if (!isAnimating) {
//      startTrackingKeyboard(userInfo: userInfo)
//    }
  }

//  private func startTrackingKeyboard(userInfo: [AnyHashable: Any]) {
//    print("startTrackingKeyboard()")
//    guard let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
//          let curveRawValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int else {
//      return
//    }
//
//    let curve = UIView.AnimationCurve(rawValue: curveRawValue) ?? .easeInOut
//
//    // Start a timer to poll the keyboard height at intervals
//    isAnimating = true
//    keyboardTimer = Timer.scheduledTimer(
//      timeInterval: 0.016, // Approximately 60 FPS
//      target: self,
//      selector: #selector(pollKeyboardHeight),
//      userInfo: nil,
//      repeats: true
//    )
//  }
//  
//  @objc private func pollKeyboardHeight() {
//    print("pollKeyboardHeight")
//    guard let window = window else {
//      stopTrackingKeyboard()
//      return
//    }
//
//    // Calculate the current keyboard height
//    let screenHeight = window.bounds.height
//    let keyboardHeight = max(0, screenHeight - keyboardFrame.origin.y)
//    print("keyboardHeight: ", keyboardHeight, ", frame height: ", keyboardFrame.height)
//
//    channel!.invokeMethod("keyboardGeometry", arguments: [
//      "y": keyboardFrame.origin.y,
//      "height": keyboardHeight
//    ])
//
//    // Stop polling if the keyboard is fully open or hidden
//    print("Is height = 0? ", (keyboardHeight == 0))
//    if !isAnimating || keyboardHeight == 0 || keyboardHeight == keyboardFrame.height {
//      stopTrackingKeyboard()
//    }
//  }
//  
//  @objc private func updateKeyboardFrame() {
//    print("updateKeyboardFrame")
//    channel!.invokeMethod("updatKeyboardFrame", arguments: nil)
//    guard let window = window else { return }
//
//    let screenHeight = window.bounds.height
//    let keyboardHeight = max(0, screenHeight - keyboardFrame.origin.y)
//
//    channel!.invokeMethod("keyboardGeometry", arguments: [
//      "y": keyboardFrame.origin.y,
//      "height": keyboardHeight
//    ])
//
//    // Stop tracking when the animation completes
//    if keyboardHeight == 0 || keyboardHeight == keyboardFrame.height {
//      stopTrackingKeyboard()
//    }
//  }
//
//  private func stopTrackingKeyboard() {
//    print("stopTrackingKeyboard(), timer: ", keyboardTimer)
//    isAnimating = false
//    keyboardTimer?.invalidate()
//    keyboardTimer = nil
//  }
  
  @objc private func keyboardWillHide(_ notification: Notification) {
    SuperKeyboardLog.log(message: "Keyboard will hide")
    channel!.invokeMethod("keyboardWillHide", arguments: nil)
  }
  
  @objc private func keyboardDidHide(_ notification: Notification) {
    SuperKeyboardLog.log(message: "Keyboard did hide - reporting height: 0")
    channel!.invokeMethod("keyboardDidHide", arguments: [
      "keyboardHeight": 0
    ])
//    stopTrackingKeyboard()
  }
}

enum KeyboardType {
  case unknown
  case full
  case minimized
  
  var description: String {
    switch self {
    case .unknown:
      "unknown"
    case .full:
      "full"
    case .minimized:
      "minimized"
    }
  }
}

public class SuperKeyboardLog {
  static private var isLoggingEnabled: Bool = false
  static private var reportTo: FlutterMethodChannel? = nil

  static func enable(reportTo: FlutterMethodChannel?) {
    isLoggingEnabled = true
    self.reportTo = reportTo
  }

  static func disable() {
    isLoggingEnabled = false
    reportTo = nil
  }

  // TODO: Add log levels - not sure what's typical for iOS. Android is V, D, I, W, E.
  static func log(message: String) {
    if (isLoggingEnabled) {
      if (reportTo != nil) {
        reportToDart(message)
      } else {
        print(message)
      }
    }
  }

  static private func reportToDart(_ message: String) {
    reportTo!.invokeMethod(
      "log",
      arguments: [
        "message": message,
      ]
    )
  }
}
