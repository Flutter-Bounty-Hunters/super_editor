import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

class GiphyKeyboardPanel extends StatefulWidget {
  const GiphyKeyboardPanel({
    super.key,
    required this.editor,
  });

  final Editor editor;

  @override
  State<GiphyKeyboardPanel> createState() => _GiphyKeyboardPanelState();
}

class _GiphyKeyboardPanelState extends State<GiphyKeyboardPanel> {
  void _onGifPressed(String url) {
    final selection = widget.editor.context.composer.selection;
    if (selection == null) {
      return;
    }
    if (selection.base.nodePosition is! TextNodePosition) {
      return;
    }

    widget.editor.execute([
      TypeTextRequest(
        AttributedText("", null, {
          0: InlineNetworkImagePlaceholder(url),
        }),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return GridView(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
      ),
      children: _giphyEmojis.map(_buildEmoji).toList(),
    );
  }

  Widget _buildEmoji(String url) {
    return GestureDetector(
      onTap: () => _onGifPressed(url),
      child: Image.network(url),
    );
  }
}

const _giphyEmojis = [
  // Thumbs up.
  "https://media1.giphy.com/media/v1.Y2lkPTc5MGI3NjExZHBwdGgwYXYydTJiYmV1aGZ6dWZraGZsZzIzNmNkZGdiMGJyYW40dSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9ZQ/ehz3LfVj7NvpY8jYUY/giphy.webp",
  // Fire.
  "https://media2.giphy.com/media/v1.Y2lkPTc5MGI3NjExcHpjemk5eGVza29iOHNlaHJkbWJjamxpZW82MzEwM2F4bDV1NTJkaiZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9ZQ/J2awouDsf23R2vo2p5/giphy.webp",
  // Flexing muscle.
  "https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExY3NxOWFuanlvOXk3Y2V5bmFjaGQ2Z3c4aHQ5aDI5dXlwdzRpd25uMyZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9ZQ/SvLQ270MWY0GpztVjo/giphy.webp",
  // Clapping hands.
  "https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExMjhncWRqbHBmNDVvZ3Q2ZHYzN2VkbXdoZGt0Z2d4eTI2ZTV5aTR2dyZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9ZQ/ZdNlmHHr7czumQPvNE/giphy.webp",
  // Prayer hands.
  "https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExeGszYXh0djNieXJhZW1zbjJ5NjExd3RqcHppYjB0dHgxemk0d2loMSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9ZQ/WqR7WfQVrpXNcmrm81/giphy.webp",
  // Heart.
  "https://media2.giphy.com/media/v1.Y2lkPTc5MGI3NjExZGI5bTEwcTg4dXd2a29sc3BxdTFlMHEwOHI2b3ozYWgxNHAycnBmaSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/xUA7aWi4gtOdAaX9q8/giphy.webp",
  // OMG face.
  "https://media3.giphy.com/media/v1.Y2lkPTc5MGI3NjExYXJyOGhudTBiNm4wZnR6bTdrNGwwOWtpYWtnbXlxYml0N3ZrMDl0NSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9ZQ/j2NFnjcXwni0E9KcdI/giphy.webp",
  // Popping hearts.
  "https://media2.giphy.com/media/v1.Y2lkPTc5MGI3NjExeXd4bHEwaWRxYm41dWhhc21neDFxZ2p6YXAxY2ZnM20wcDZwaG5wcCZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9cw/QUGf8x31iMVSdbNn00/giphy.webp",
  // Awkward face.
  "https://media2.giphy.com/media/v1.Y2lkPTc5MGI3NjExMWd5dDh1djVlbWhnMmV3dzR2emtqNDdxZHZqeGNrem9zZnE5MjI3aSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9ZQ/XHdW0gCDj6KiFmKFCZ/giphy.webp",
  // Fuming face.
  "https://media1.giphy.com/media/v1.Y2lkPTc5MGI3NjExa2ZsbmZib2hleno0dTV4dzMyMmtoZ3JocThlZHFkdnYxeHJ1b21idiZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9ZQ/kyQfR7MlQQ9Gb8URKG/giphy.webp",
  // Angry face.
  "https://media0.giphy.com/media/v1.Y2lkPTc5MGI3NjExcGFrd2ZqaGM2ZmVveHU1bWZ5b25ocDV5M2J1MG9nbGplampsOGdibSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9ZQ/QU3wZZG8x351iQAbfm/giphy.webp",
  // Deflate face.
  "https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExNnJxeHR3MmJiNmhiYmdtaWt3bDVmcHJlbXBibzNyazluZmE4dTBnZSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9ZQ/H4cBu6XqKJtGujEXll/giphy.webp",
  // Dumpster fire.
  "https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExOHJ1dWFtazNoeTVrcGthMHE2ZWI1aDlyOWpkZHY4MzZyMXJsZDFwbiZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9ZQ/jOsoGmmWGSloPU8fMH/giphy.webp",

  // Disappointed baby.
  "https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExcWo4cnV2dW1sem9hMzk5cWd5cW4zcW80ejU3YnJuZjF5amdpMGF5ZyZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9cw/tr4TTyG4BjxfDioymO/giphy.webp",
  // Chihuahua face.
  "https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExdXR2ZGoxZDBkemJpZzdtOXBpc292OXp0d2cyMzdqemlpZnJocjdiaSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9cw/3oKIPfZAisBaUuybcs/giphy.webp",
  // South Park - Randy crying.
  "https://media2.giphy.com/media/v1.Y2lkPTc5MGI3NjExa3EybmZxazIwaXgzY3lpcmpjdTMwcXh0c3Fsd28wbW5xZTBhNGZ3NCZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9cw/PaVz5Z1dot5FIPS50w/giphy.webp",
];
