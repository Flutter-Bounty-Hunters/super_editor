package com.flutterbountyhunters.superkeyboard.super_keyboard

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import androidx.core.view.OnApplyWindowInsetsListener
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsAnimationCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt


/**
 * Plugin that reports software keyboard state changes, and (maybe) keyboard height changes.
 *
 * Tracking keyboard height is more difficult. There may be some platforms that don't
 * support height tracking.
 *
 * Android Docs: https://developer.android.com/develop/ui/views/layout/sw-keyboard
 */
class SuperKeyboardPlugin: FlutterPlugin, ActivityAware, DefaultLifecycleObserver, OnApplyWindowInsetsListener {
  private lateinit var channel : MethodChannel

  private var binding: ActivityPluginBinding? = null

  // The Activity's lifecycle, which reports things like when the Android
  // app comes into the foreground from the background.
  private var lifecycle: Lifecycle? = null

  // The root view within the Android Activity.
  private var mainView: View? = null

  // The manager for text input for the Android Activity.
  private lateinit var ime: InputMethodManager

  // The most recent known state of the software keyboard.
  private var keyboardState: KeyboardState = KeyboardState.Closed

  // The device's DPI, used to map to logical pixels before sending the
  // keyboard height to Flutter.
  private var dpi: Float = 1.0f

  // The most recent measurement of the keyboard height.
  private var imeHeightInDpi: Float = 0f
  // The most recent measurement of the gesture area at the bottom of the screen.
  private var bottomPaddingInDpi: Float = 0f

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    SuperKeyboardLog.d("super_keyboard", "Attached to Flutter engine")
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "super_keyboard_android")

    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "startLogging" -> {
          val forwardToDart = call.argument<Boolean?>("sendPlatformLogsToDart") ?: false
          SuperKeyboardLog.enable(if (forwardToDart) channel else null)
          result.success(null)
        }
        "stopLogging" -> {
          SuperKeyboardLog.disable()
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    SuperKeyboardLog.d("super_keyboard", "Attached to Flutter Activity")
    this.binding = binding
    this.dpi = binding.activity.resources.displayMetrics.density;
    startListeningToActivityLifecycle()
  }

  override fun onResume(owner: LifecycleOwner) {
    SuperKeyboardLog.d("super_keyboard", "Activity Resumed - keyboard state: $keyboardState")
    startListeningForKeyboardChanges(binding!!)

    // It's possible that, while paused, the keyboard went from closed to open, or open to closed.
    // In practice, it's far more common to go from open to closed. However, while debugging some
    // buggy lifecycle fluctuations on Android API 35 on a Pixel 9 Pro, it was found that it's also
    // possible to pause while closed, and resume with the keyboard open.
    measureInsets()

    SuperKeyboardLog.v("super_keyboard", "Insets at time of resume are - Keyboard: $imeHeightInDpi, Bottom Padding: $bottomPaddingInDpi")
    if (imeHeightInDpi.roundToInt() == 0 && keyboardState != KeyboardState.Closed) {
      SuperKeyboardLog.d("super_keyboard", "Keyboard closed while paused - sending keyboardClosed message to Flutter.");
      keyboardState = KeyboardState.Closed
      sendMessageKeyboardClosed()
    } else if (imeHeightInDpi > 0 && keyboardState != KeyboardState.Open) {
      SuperKeyboardLog.d("super_keyboard", "Keyboard opened while paused - sending keyboardOpened message to Flutter.");
      keyboardState = KeyboardState.Open
      sendMessageKeyboardOpened()
    } else {
      SuperKeyboardLog.d("super_keyboard", "Reporting latest metrics to Flutter, just in case they got out of sync.");
      sendMessageMetricsUpdate()
    }
  }

  override fun onPause(owner: LifecycleOwner) {
    SuperKeyboardLog.d("super_keyboard", "Activity Paused - keyboard state: $keyboardState")
    stopListeningForKeyboardChanges()
  }

  override fun onDetachedFromActivityForConfigChanges() {
    SuperKeyboardLog.v("super_keyboard", "Detaching from Activity for config changes")
    stopListeningToActivityLifecycle()
    this.binding = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    SuperKeyboardLog.v("super_keyboard", "Re-attaching to Activity for config changes")
    startListeningToActivityLifecycle()
    this.binding = binding
  }

  override fun onDetachedFromActivity() {
    SuperKeyboardLog.d("super_keyboard", "Detached from Flutter activity")
    stopListeningToActivityLifecycle()
    this.binding = null
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    SuperKeyboardLog.d("super_keyboard", "Detached from Flutter engine")
    SuperKeyboardLog.disable()
    this.binding = null
  }

  private fun startListeningToActivityLifecycle() {
    SuperKeyboardLog.v("super_keyboard", "Starting to listen to Activity lifecycle")
    lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding!!)
    lifecycle!!.addObserver(this)
  }

  private fun stopListeningToActivityLifecycle() {
    SuperKeyboardLog.v("super_keyboard", "Stopping listening to Activity lifecycle")
    lifecycle!!.removeObserver(this);
  }

  private fun startListeningForKeyboardChanges(binding: ActivityPluginBinding) {
    SuperKeyboardLog.v("super_keyboard", "Starting to listen for keyboard changes")
    val activity = binding.activity

    mainView = activity.findViewById<ViewGroup>(android.R.id.content)
    ime = activity.getSystemService(Activity.INPUT_METHOD_SERVICE) as InputMethodManager
    if (mainView == null) {
      // This should never happen. If it does, we just fizzle.
      return;
    }

    // Track keyboard opening and closing.
    ViewCompat.setOnApplyWindowInsetsListener(mainView!!, this)

    // Track keyboard fully open, fully closed, and height.
    ViewCompat.setWindowInsetsAnimationCallback(
      mainView!!,
      object : WindowInsetsAnimationCompat.Callback(DISPATCH_MODE_STOP) {
        override fun onPrepare(
          animation: WindowInsetsAnimationCompat
        ) {
          // no-op
          SuperKeyboardLog.v("super_keyboard", "Insets animation callback - onPrepare() - current keyboard state: $keyboardState")
        }

        override fun onStart(
          animation: WindowInsetsAnimationCompat,
          bounds: WindowInsetsAnimationCompat.BoundsCompat
        ): WindowInsetsAnimationCompat.BoundsCompat {
          // no-op
          SuperKeyboardLog.v("super_keyboard", "Insets animation callback - onStart() - current keyboard state: $keyboardState")
          return bounds
        }

        override fun onProgress(
          insets: WindowInsetsCompat,
          runningAnimations: MutableList<WindowInsetsAnimationCompat>
        ): WindowInsetsCompat {
          SuperKeyboardLog.v("super_keyboard", "Insets animation callback - onProgress() - current keyboard state: $keyboardState")

          // Update our cached measurements.
          imeHeightInDpi = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom / dpi
          bottomPaddingInDpi = insets.getInsets(WindowInsetsCompat.Type.mandatorySystemGestures()).bottom / dpi
          SuperKeyboardLog.v("super_keyboard", "On progress keyboard height: $imeHeightInDpi, is IME visible: ${insets.isVisible(WindowInsetsCompat.Type.ime())}")

          // Report our newly cached measurements to Flutter.
          sendMessageKeyboardProgress()

          return insets
        }

        override fun onEnd(
          animation: WindowInsetsAnimationCompat
        ) {
          // Report whether the keyboard has fully opened or fully closed.
          SuperKeyboardLog.i("super_keyboard", "Insets animation callback - onEnd - current keyboard state: $keyboardState")
          if (keyboardState == KeyboardState.Opening) {
            // It was discovered that on at least some Samsung devices, such as Galaxy S24 on API 14
            // and API 16, `onEnd()` runs a frame before the final keyboard inset height is applied.
            // Therefore, we always wait a frame to report the completion of the keyboard opening.
            Handler(Looper.getMainLooper()).post {
              SuperKeyboardLog.i("super_keyboard", "Sending new keyboard state: open")

              // Update our cached measurements.
              val insets = ViewCompat.getRootWindowInsets(binding.activity.window.decorView)
              if (insets != null) {
                // Note: I don't ever expect insets to be null here, but technically it's possible.
                imeHeightInDpi = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom / dpi
                bottomPaddingInDpi = insets.getInsets(WindowInsetsCompat.Type.mandatorySystemGestures()).bottom / dpi
              }

              keyboardState = KeyboardState.Open
              sendMessageKeyboardOpened()
            }
          } else if (keyboardState == KeyboardState.Closing) {
            SuperKeyboardLog.i("super_keyboard", "Sending new keyboard state: closing")
            keyboardState = KeyboardState.Closed
            sendMessageKeyboardClosed()
          }
        }
      }
    )
  }

  override fun onApplyWindowInsets(v: View, insets: WindowInsetsCompat): WindowInsetsCompat {
    SuperKeyboardLog.d("super_keyboard", "onApplyWindowInsets() - current keyboard state: $keyboardState")
    if (lifecycle!!.currentState == Lifecycle.State.CREATED) {
      // For at least Android API 34, we receive conflicting reports about IME visibility
      // when the app is being backgrounded. First we're told the IME isn't visible, then
      // we're told that it is. In theory, the IME should never be visible when in the CREATED
      // state, so we explicitly tell the app that the keyboard is closed here.
      if (keyboardState != KeyboardState.Closed) {
        SuperKeyboardLog.d("super_keyboard", "Activity is in CREATED state - telling app that keyboard is closed")
        keyboardState = KeyboardState.Closed
        sendMessageKeyboardClosed()
      }

      return insets
    }

    val imeVisible = insets.isVisible(WindowInsetsCompat.Type.ime())
    SuperKeyboardLog.d("super_keyboard", "Is IME visible? $imeVisible")
    SuperKeyboardLog.d("super_keyboard", "Lifecycle state: ${lifecycle!!.currentState}")

    SuperKeyboardLog.d("super_keyboard", "Insets: ${insets.getInsets(WindowInsetsCompat.Type.ime()).bottom}")

    // Note: We primarily only identify opening/closing here. The opened/closed completion
    //       is identified by the window insets animation callback.
    //
    //       The exception is that when the Activity resumes, the keyboard might jump immediately
    //       to "closed". We catch that situation by looking for a `0` bottom inset.
    if (imeVisible && keyboardState != KeyboardState.Opening && keyboardState != KeyboardState.Open) {
      SuperKeyboardLog.d("super_keyboard", "Setting keyboard state to Opening")
      sendMessageKeyboardOpening()
      keyboardState = KeyboardState.Opening
    } else if (!imeVisible && keyboardState != KeyboardState.Closing && keyboardState != KeyboardState.Closed) {
      if (insets.getInsets(WindowInsetsCompat.Type.ime()).bottom == 0) {
        SuperKeyboardLog.d("super_keyboard", "Setting keyboard state to Closed")

        // The keyboard height should be zero at this point. But just in case something got messed
        // up with Android timing, we set the height to zero explicitly.
        if (imeHeightInDpi.roundToInt() != 0) {
          SuperKeyboardLog.w("super_keyboard", "Setting keyboard state to Closed, but our most recent measured keyboard height is: $imeHeightInDpi")
        }
        imeHeightInDpi = 0f;

        sendMessageKeyboardClosed()
        keyboardState = KeyboardState.Closed
      } else {
        SuperKeyboardLog.d("super_keyboard", "Setting keyboard state to Closing")
        sendMessageKeyboardClosing()
        keyboardState = KeyboardState.Closing
      }
    }

    return insets
  }

  private fun stopListeningForKeyboardChanges() {
    SuperKeyboardLog.v("super_keyboard", "Stopping listening for keyboard changes")
    if (mainView == null) {
      SuperKeyboardLog.w("super_keyboard", "Our mainView is null in onPause. This isn't expected.")
      return;
    }

    ViewCompat.setOnApplyWindowInsetsListener(mainView!!, null)
    ViewCompat.setWindowInsetsAnimationCallback(mainView!!, null)

    mainView = null
  }

  // Queries the current IME and gesture insets and updates our local record of those
  // values.
  //
  // This method can be used to synchronize our understanding of these insets at times
  // when Android's lifecycle might screw up. However, it's recommended that we measure
  // these values in response to Android hooks as much as possible, rather than query
  // directly. For example, we should prefer to update these values within a
  // WindowsInsetsAnimationCallback.
  private fun measureInsets() {
    val insets = ViewCompat.getRootWindowInsets(mainView!!) ?: return
    imeHeightInDpi = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom / dpi
    bottomPaddingInDpi = insets.getInsets(WindowInsetsCompat.Type.mandatorySystemGestures()).bottom / dpi
  }

  private fun sendMessageKeyboardOpened() {
    channel.invokeMethod("keyboardOpened", createMetricsPayload())
  }

  private fun sendMessageKeyboardOpening() {
    channel.invokeMethod("keyboardOpening", createMetricsPayload())
  }

  private fun sendMessageKeyboardProgress() {
    channel.invokeMethod("onProgress", createMetricsPayload())
  }

  private fun sendMessageKeyboardClosed() {
    channel.invokeMethod("keyboardClosed", createMetricsPayload())
  }

  private fun sendMessageKeyboardClosing() {
    channel.invokeMethod("keyboardClosing", createMetricsPayload())
  }

  private fun sendMessageMetricsUpdate() {
    channel.invokeMethod("metricsUpdate", createMetricsPayload())
  }

  private fun createMetricsPayload(): Map<String, Any> {
    return mapOf<String, Any>(
      "keyboardHeight" to imeHeightInDpi,
      "bottomPadding" to bottomPaddingInDpi,
    )
  }
}

private enum class KeyboardState {
  Closed,
  Opening,
  Open,
  Closing;
}