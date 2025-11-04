import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_keyboard/super_keyboard.dart';

void main() {
  runApp(const SuperKeyboardDemoApp());
}

class SuperKeyboardDemoApp extends StatefulWidget {
  const SuperKeyboardDemoApp({super.key});

  @override
  State<SuperKeyboardDemoApp> createState() => _SuperKeyboardDemoAppState();
}

class _SuperKeyboardDemoAppState extends State<SuperKeyboardDemoApp> {
  bool _closeOnOutsideTap = true;
  bool _isFlutterLoggingEnabled = false;
  bool _isPlatformLoggingEnabled = false;

  @override
  void initState() {
    super.initState();

    initSuperKeyboard();
  }

  Future<void> initSuperKeyboard() async {
    if (_isFlutterLoggingEnabled) {
      SKLog.startLogging();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        resizeToAvoidBottomInset: defaultTargetPlatform != TargetPlatform.android,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildKeyboardStateIcon(),
                const SizedBox(height: 12),
                SuperKeyboardBuilder(
                  builder: (context, keyboardState) {
                    return Text("Keyboard state: $_keyboardState");
                  },
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder(
                  valueListenable: SuperKeyboard.instance.mobileGeometry,
                  builder: (context, value, child) {
                    return Text(
                        "Keyboard height: ${value.keyboardHeight != null ? "${value.keyboardHeight!.toInt()}" : "???"}");
                  },
                ),
                const SizedBox(height: 48),
                TextField(
                  decoration: const InputDecoration(
                    hintText: "Type some text",
                  ),
                  onTapOutside: (_) {
                    if (_closeOnOutsideTap) {
                      FocusManager.instance.primaryFocus?.unfocus();
                    }
                  },
                ),
                const SizedBox(height: 16),
                _buildCloseOnFocusOption(),
                _buildFlutterLoggingOption(),
                _buildPlatformLoggingOption(),
                ValueListenableBuilder(
                  valueListenable: SuperKeyboard.instance.mobileGeometry,
                  builder: (context, value, child) {
                    if (value.keyboardHeight == null) {
                      return const SizedBox();
                    }

                    return SizedBox(height: value.keyboardHeight! / MediaQuery.of(context).devicePixelRatio);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboardStateIcon() {
    return ValueListenableBuilder(
      valueListenable: SuperKeyboard.instance.mobileGeometry,
      builder: (context, value, child) {
        final icon = switch (value.keyboardState) {
          KeyboardState.closed => Icons.border_bottom,
          KeyboardState.opening => Icons.upload_sharp,
          KeyboardState.open => Icons.border_top,
          KeyboardState.closing => Icons.download_sharp,
          null => Icons.question_mark,
        };

        return Icon(
          icon,
          size: 24,
        );
      },
    );
  }

  String? get _keyboardState {
    return switch (SuperKeyboard.instance.mobileGeometry.value.keyboardState) {
      KeyboardState.closed => "Closed",
      KeyboardState.opening => "Opening",
      KeyboardState.open => "Open",
      KeyboardState.closing => "Closing",
      _ => null,
    };
  }

  Widget _buildCloseOnFocusOption() {
    return Row(
      spacing: 8,
      children: [
        const Expanded(
          child: Text('Close keyboard on outside tap'),
        ),
        Switch(
          value: _closeOnOutsideTap,
          onChanged: (newValue) {
            setState(() {
              _closeOnOutsideTap = newValue;
            });
          },
        ),
      ],
    );
  }

  Widget _buildFlutterLoggingOption() {
    return Row(
      spacing: 8,
      children: [
        const Expanded(
          child: Text('Enable flutter logs'),
        ),
        Switch(
          value: _isFlutterLoggingEnabled,
          onChanged: (newValue) {
            setState(() {
              _isFlutterLoggingEnabled = newValue;

              if (_isFlutterLoggingEnabled) {
                SKLog.startLogging();
              } else {
                SKLog.stopLogging();
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildPlatformLoggingOption() {
    return Row(
      spacing: 8,
      children: [
        const Expanded(
          child: Text('Enable platform logs'),
        ),
        Switch(
          value: _isPlatformLoggingEnabled,
          onChanged: (newValue) {
            setState(() {
              _isPlatformLoggingEnabled = newValue;
              SuperKeyboard.instance.enablePlatformLogging(_isPlatformLoggingEnabled);
            });
          },
        ),
      ],
    );
  }
}
