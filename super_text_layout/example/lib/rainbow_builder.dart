import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Runs the given [builder], passing in a [Color] that's constantly changing through
/// the color spectrum.
class RainbowBuilder extends StatefulWidget {
  const RainbowBuilder({
    Key? key,
    required this.builder,
  }) : super(key: key);

  final Widget Function(BuildContext, Color) builder;

  @override
  State<RainbowBuilder> createState() => _RainbowBuilderState();
}

class _RainbowBuilderState extends State<RainbowBuilder> with SingleTickerProviderStateMixin {
  static const _colorDegreesPerSecond = 60.0;

  late final Ticker _ticker;
  Duration _lastFrameTime = Duration.zero;
  HSVColor _color = const HSVColor.fromAHSV(1.0, 0, 1.0, 1.0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsedTime) {
    setState(() {
      final dt = elapsedTime - _lastFrameTime;
      final hueDelta = (dt.inMilliseconds / 1000) * _colorDegreesPerSecond;
      _color = HSVColor.fromAHSV(1.0, (_color.hue + hueDelta) % 360, 1.0, 1.0);
      _lastFrameTime = elapsedTime;
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _color.toColor());
  }
}
