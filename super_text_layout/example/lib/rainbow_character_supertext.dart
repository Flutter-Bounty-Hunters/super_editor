import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// Displays the given [text] with rainbow colors behind every character.
class CharacterRainbowSuperText extends StatefulWidget {
  const CharacterRainbowSuperText({
    Key? key,
    required this.text,
  }) : super(key: key);

  final TextSpan text;

  @override
  State<CharacterRainbowSuperText> createState() => _CharacterRainbowSuperTextState();
}

class _CharacterRainbowSuperTextState extends State<CharacterRainbowSuperText> with SingleTickerProviderStateMixin {
  final _startingColor = ValueNotifier<double>(0.0);
  final _colorVelocity = -1.0; // Degrees to spin the color wheel per frame.
  late Ticker _ticker;

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
    _startingColor.value = _startingColor.value + _colorVelocity;
  }

  @override
  Widget build(BuildContext context) {
    return SuperText(
      richText: widget.text,
      layerBeneathBuilder: (context, textLayout) {
        return ValueListenableBuilder(
            valueListenable: _startingColor,
            builder: (context, value, child) {
              final characterRects = <Rect>[];
              final characterColors = <Color>[];

              final textLength = widget.text.toPlainText().length;
              for (int i = 0; i < textLength; i += 1) {
                // Get the bounding rectangle for the character
                characterRects.add(textLayout.getCharacterBox(TextPosition(offset: i))?.toRect() ??
                    Rect.fromLTRB(0, 0, 0, textLayout.estimatedLineHeight));
                // Select a color for this character
                final colorWheelDegrees =
                    ((360.0 * (characterColors.length / textLength)) + _startingColor.value) % 360;
                characterColors.add(HSVColor.fromAHSV(1.0, colorWheelDegrees, 1.0, 1.0).toColor());
              }

              return Stack(
                children: [
                  for (int i = 0; i < characterRects.length; i += 1)
                    Positioned.fromRect(
                      rect: characterRects[i],
                      child: ColoredBox(color: characterColors[i]),
                    ),
                ],
              );
            });
      },
    );
  }
}
