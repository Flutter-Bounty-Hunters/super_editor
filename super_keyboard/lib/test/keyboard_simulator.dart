import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons, Colors;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_keyboard/src/keyboard.dart';
import 'package:super_keyboard/src/super_keyboard_unified.dart';

/// A widget that simulates the software keyboard appearance and disappearance.
///
/// This works by listening to messages sent from Flutter to the platform that show/hide
/// the software keyboard. In response to those messages, [SuperKeyboard] emits
/// notifications for the keyboard opening, opened, closing, closed. The timing of those
/// messages are based on an animation in this widget, simulating actual keyboard expansion
/// and collapse. Similarly, this widget installs a `MediaQuery`, which sets its bottom
/// offsets equal to the simulated keyboard height, which reflects how Flutter actually
/// reports keyboard height to Flutter apps.
///
/// Place this widget above the `Scaffold` in the widget tree.
class SoftwareKeyboardHeightSimulator extends StatefulWidget {
  const SoftwareKeyboardHeightSimulator({
    super.key,
    this.isEnabled = true,
    this.enableForAllPlatforms = false,
    this.initialKeyboardState = KeyboardState.closed,
    this.keyboardHeight = _defaultKeyboardHeight,
    this.animateKeyboard = false,
    this.renderSimulatedKeyboard = false,
    required this.child,
  });

  /// Whether or not to enable the simulated software keyboard insets.
  ///
  /// This property is provided so that clients don't need to conditionally add/remove
  /// this widget from the tree. Instead this flag can be flipped, as needed.
  final bool isEnabled;

  /// Whether to simulate software keyboard insets for all platforms (`true`), or whether to
  /// only simulate software keyboard insets for mobile platforms, e.g., Android, iOS (`false`).
  ///
  /// The value for this property should remain constant within a single test. Don't
  /// attempt to enable and then disable keyboard simulation. That behavior is undefined.
  final bool enableForAllPlatforms;

  /// The state of the keyboard, e.g., open, opening, closed, closing.
  final KeyboardState initialKeyboardState;

  /// The vertical space, in logical pixels, to occupy at the bottom of the screen to simulate the appearance
  /// of a keyboard.
  final double keyboardHeight;

  /// Whether to simulate keyboard open/closing animations.
  ///
  /// These animations change the keyboard insets over time, similar to how a real
  /// software keyboard slides up/down. However, this also means that clients need to
  /// `pumpAndSettle()` to ensure the animation is complete. If you want to avoid `pumpAndSettle()`
  /// and you don't care about the animation, then pass `false` to disable the animations.
  final bool animateKeyboard;

  /// Whether a fake software keyboard should be displayed in the widget tree,
  /// on top of the [child], simulating a real OS software keyboard.
  final bool renderSimulatedKeyboard;

  final Widget child;

  @override
  State<SoftwareKeyboardHeightSimulator> createState() => _SoftwareKeyboardHeightSimulatorState();
}

class _SoftwareKeyboardHeightSimulatorState extends State<SoftwareKeyboardHeightSimulator>
    with SingleTickerProviderStateMixin {
  static int _nextTestKeyboardId = 1;

  late final String _testKeyboardId;

  @override
  void initState() {
    super.initState();

    _testKeyboardId = "$_nextTestKeyboardId";
    _nextTestKeyboardId += 1;

    if (widget.isEnabled) {
      TestSuperKeyboard.install(
        id: _testKeyboardId,
        vsync: this,
        initialKeyboardState: widget.initialKeyboardState,
        fakeKeyboardHeight: widget.keyboardHeight,
        keyboardAnimationTime: widget.animateKeyboard ? const Duration(milliseconds: 600) : Duration.zero,
      );
    }
  }

  @override
  void didUpdateWidget(covariant SoftwareKeyboardHeightSimulator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.animateKeyboard != oldWidget.animateKeyboard || widget.keyboardHeight != oldWidget.keyboardHeight) {
      TestSuperKeyboard.install(
        id: _testKeyboardId,
        vsync: this,
        initialKeyboardState: widget.initialKeyboardState,
        fakeKeyboardHeight: widget.keyboardHeight,
        keyboardAnimationTime: widget.animateKeyboard ? const Duration(milliseconds: 600) : Duration.zero,
      );
    }

    if (widget.isEnabled && !oldWidget.isEnabled) {
      throw Exception(
          "You initially built a SoftwareKeyboardHeightSimulator disabled, then you enabled it. This mode needs to remain constant throughout a test.");
    } else if (!widget.isEnabled && oldWidget.isEnabled) {
      throw Exception(
          "You initially built a SoftwareKeyboardHeightSimulator enabled, then you disabled it. This mode needs to remain constant throughout a test.");
    }
  }

  @override
  void dispose() {
    TestSuperKeyboard.uninstall(_testKeyboardId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: SuperKeyboard.instance.mobileGeometry,
      builder: (context, geometry, child) {
        final realMediaQuery = MediaQuery.of(context);
        final isRelevantPlatform = widget.enableForAllPlatforms ||
            (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
        final shouldSimulate = widget.isEnabled && isRelevantPlatform;
        if (!shouldSimulate) {
          return widget.child;
        }

        return Directionality(
          // For some reason a Stack needs Directionality.
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned.fill(
                child: MediaQuery(
                  data: realMediaQuery.copyWith(
                    viewInsets: realMediaQuery.viewInsets.copyWith(
                      bottom: geometry.keyboardHeight ?? 0.0,
                    ),
                  ),
                  child: widget.child,
                ),
              ),
              // Display a placeholder where the keyboard would go so we
              // can verify the keyboard size in golden tests.
              if (widget.renderSimulatedKeyboard) //
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: geometry.keyboardHeight ?? 0,
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: widget.keyboardHeight,
                    child: SoftwareKeyboard(
                      height: widget.keyboardHeight,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class TestSuperKeyboard implements SuperKeyboard {
  static void install({
    required String id,
    required TickerProvider vsync,
    KeyboardState initialKeyboardState = KeyboardState.closed,
    double fakeKeyboardHeight = _defaultKeyboardHeight,
    Duration keyboardAnimationTime = const Duration(milliseconds: 600),
  }) {
    if (_instance != null) {
      forceUninstall();
    }

    _instance = TestSuperKeyboard(
      id: id,
      vsync: vsync,
      initialKeyboardState: initialKeyboardState,
      fakeKeyboardHeight: fakeKeyboardHeight,
      keyboardAnimationTime: keyboardAnimationTime,
    );

    SuperKeyboard.testInstance = _instance;
  }

  static void uninstall(String id) {
    if (_instance == null || _instance!.id != id) {
      return;
    }

    _instance!.dispose();
    _instance = null;

    SuperKeyboard.testInstance = null;
  }

  static void forceUninstall() {
    if (_instance == null) {
      return;
    }

    uninstall(_instance!.id);
  }

  static TestSuperKeyboard? _instance;

  TestSuperKeyboard({
    required this.id,
    required TickerProvider vsync,
    KeyboardState initialKeyboardState = KeyboardState.closed,
    this.fakeKeyboardHeight = 400.0,
    Duration keyboardAnimationTime = const Duration(milliseconds: 600),
  }) {
    _interceptPlatformChannel();

    _geometry.value = MobileWindowGeometry(
      keyboardState: initialKeyboardState,
      keyboardHeight: initialKeyboardState == KeyboardState.open ? fakeKeyboardHeight : null,
    );

    _keyboardHeightController = AnimationController(
      duration: keyboardAnimationTime,
      vsync: vsync,
    )
      ..addListener(() {
        _geometry.value = _geometry.value.updateWith(
          MobileWindowGeometry(
            keyboardHeight: _keyboardHeightController.value * fakeKeyboardHeight,
          ),
        );
      })
      ..addStatusListener(_onKeyboardAnimationStatusChange);
  }

  void _interceptPlatformChannel() {
    TestDefaultBinaryMessengerBinding.instance.interceptChannel(SystemChannels.textInput.name) //
      ..interceptMethod(
        'TextInput.setClient',
        (methodCall) {
          _simulatePlatformOpeningKeyboard();
          return null;
        },
      )
      ..interceptMethod(
        'TextInput.show',
        (methodCall) {
          _simulatePlatformOpeningKeyboard();
          return null;
        },
      )
      ..interceptMethod(
        'TextInput.hide',
        (methodCall) {
          _simulatePlatformClosingKeyboard();
          return null;
        },
      )
      ..interceptMethod(
        'TextInput.clearClient',
        (methodCall) {
          _simulatePlatformClosingKeyboard();
          return null;
        },
      );
  }

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(SystemChannels.textInput.name, null);
    _keyboardHeightController.dispose();
  }

  @override
  Future<void> enablePlatformLogging(bool isEnabled) async {
    // no-op
  }

  /// An ID for this specific test keyboard instance, which is used primarily to
  /// ensure that one test keyboard doesn't accidentally uninstall some other
  /// test keyboard.
  final String id;

  final double fakeKeyboardHeight;

  late final AnimationController _keyboardHeightController;

  @override
  ValueListenable<MobileWindowGeometry> get mobileGeometry => _geometry;
  final _geometry = ValueNotifier(const MobileWindowGeometry());

  void _simulatePlatformOpeningKeyboard() {
    _keyboardHeightController.forward();
  }

  void _simulatePlatformClosingKeyboard() {
    _keyboardHeightController.reverse();
  }

  void _onKeyboardAnimationStatusChange(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.forward:
        _geometry.value = MobileWindowGeometry(
          keyboardState: KeyboardState.opening,
          keyboardHeight: fakeKeyboardHeight / 2,
          bottomPadding: 48,
        );
      case AnimationStatus.completed:
        _geometry.value = MobileWindowGeometry(
          keyboardState: KeyboardState.open,
          keyboardHeight: fakeKeyboardHeight,
          bottomPadding: 48,
        );
      case AnimationStatus.reverse:
        _geometry.value = MobileWindowGeometry(
          keyboardState: KeyboardState.closing,
          keyboardHeight: fakeKeyboardHeight / 2,
          bottomPadding: 48,
        );
      case AnimationStatus.dismissed:
        _geometry.value = const MobileWindowGeometry(
          keyboardState: KeyboardState.closed,
          keyboardHeight: 0,
          bottomPadding: 48,
        );
    }
  }
}

class SoftwareKeyboard extends StatelessWidget {
  static const double keySpacing = 8;

  const SoftwareKeyboard({
    super.key,
    double? height,
  }) : height = height ?? _defaultKeyboardHeight;

  final double height;

  @override
  Widget build(BuildContext context) {
    const letterButtonBackgroundColor = Color(0xFF6D6D6E);
    const letterButtonForegroundColor = Colors.white;
    const controlButtonBackgroundColor = Color(0xFF4A4A4B);
    const controlButtonForegroundColor = Colors.white;

    return Container(
      height: height,
      color: const Color(0xDD2B2B2D),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: _buildCharacterKeys(
              ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
              buttonColor: letterButtonBackgroundColor,
              characterColor: letterButtonForegroundColor,
            ),
          ),
          Row(
            children: _buildCharacterKeys(
              ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
              buttonColor: letterButtonBackgroundColor,
              characterColor: letterButtonForegroundColor,
            ),
          ),
          Row(children: [
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: _SoftwareKeyboardButton(
                backgroundColor: controlButtonBackgroundColor,
                child: Icon(
                  Icons.keyboard_capslock,
                  color: controlButtonForegroundColor,
                  size: 16,
                ),
              ),
            ),
            ..._buildCharacterKeys(
              ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
              buttonColor: letterButtonBackgroundColor,
              characterColor: letterButtonForegroundColor,
            ),
            const Padding(
              padding: EdgeInsets.only(right: keySpacing),
              child: _SoftwareKeyboardButton(
                backgroundColor: controlButtonBackgroundColor,
                child: Icon(
                  Icons.backspace,
                  color: controlButtonForegroundColor,
                  size: 12,
                ),
              ),
            ),
          ]),
          const Row(
            children: [
              Padding(
                padding: EdgeInsets.only(right: keySpacing),
                child: _SoftwareKeyboardButton(
                  backgroundColor: controlButtonBackgroundColor,
                  child: Text(
                    '123',
                    style: TextStyle(
                      fontSize: 10,
                      color: controlButtonForegroundColor,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: keySpacing),
                child: _SoftwareKeyboardButton(
                  backgroundColor: controlButtonBackgroundColor,
                  child: Icon(
                    Icons.insert_emoticon,
                    color: controlButtonForegroundColor,
                    size: 16,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: keySpacing),
                  child: _SoftwareKeyboardButton(
                    backgroundColor: controlButtonBackgroundColor,
                    child: Text(
                      'Space',
                      style: TextStyle(
                        fontSize: 14,
                        color: controlButtonForegroundColor,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: keySpacing),
                child: _SoftwareKeyboardButton(
                  backgroundColor: controlButtonBackgroundColor,
                  child: Text(
                    'Return',
                    style: TextStyle(
                      fontSize: 10,
                      color: controlButtonForegroundColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCharacterKeys(
    List<String> characters, {
    required Color buttonColor,
    required Color characterColor,
  }) {
    return characters
        .map<Widget>(
          (x) => Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: keySpacing),
              child: _SoftwareKeyboardButton(
                backgroundColor: buttonColor,
                child: Text(
                  x,
                  style: TextStyle(
                    fontSize: 10,
                    color: characterColor,
                  ),
                ),
              ),
            ),
          ),
        )
        .toList();
  }
}

/// A [SoftwareKeyboardScaffold] button, e.g., a character, space bar, action button.
class _SoftwareKeyboardButton extends StatelessWidget {
  const _SoftwareKeyboardButton({
    // ignore: unused_element_parameter
    super.key,
    required this.backgroundColor,
    // ignore: unused_element_parameter
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    // ignore: unused_element_parameter
    this.padding = const EdgeInsets.symmetric(
      vertical: 14,
      horizontal: 6,
    ),
    required this.child,
  });

  final Color backgroundColor;
  final EdgeInsets padding;
  final BorderRadius borderRadius;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
      ),
      padding: padding,
      alignment: Alignment.center,
      child: child,
    );
  }
}

const _defaultKeyboardHeight = 300.0;

extension on TestDefaultBinaryMessengerBinding {
  PlatformMessageHandler interceptChannel(String channel) {
    final handler = PlatformMessageHandler();

    defaultBinaryMessenger.setMockMessageHandler(channel, (message) async {
      return await handler.handleMessage(message);
    });

    return handler;
  }
}
