import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gemini/infrastructure/bottom_sheet_chat_scaffold.dart';
import 'package:gemini/infrastructure/theme.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final apiKey = const String.fromEnvironment("GEMINI_API_KEY");

  late final GenerativeModel model;
  late final ChatSession chat;

  final _conversation = <String>[];
  String? _generatingResponse;

  @override
  void initState() {
    super.initState();

    model = GenerativeModel(model: "gemini-2.5-flash", apiKey: apiKey);
    chat = model.startChat();

    Future.delayed(const Duration(seconds: 1)).then((_) {
      _askQuestion("Very concisely describe Star Wars Unlimited");
    });

    Future.delayed(const Duration(seconds: 10)).then((_) {
      _askQuestion("Explain the aspects");
    });
  }

  Future<void> _askQuestion(String prompt) async {
    try {
      final responseStream = chat.sendMessageStream(Content.text(prompt));
      final responseBuffer = StringBuffer();
      await for (final chunk in responseStream) {
        if (!mounted) {
          return;
        }

        print("Chunk: ${chunk.text}");
        responseBuffer.write(chunk.text);
        setState(() {
          _generatingResponse = responseBuffer.toString();
        });
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _conversation.add(responseBuffer.toString());
        _generatingResponse = null;
      });
    } catch (e) {
      print("Error asking AI: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(), //
      extendBodyBehindAppBar: true,
      body: BottomSheetChatScaffold(
        contentBuilder: (context, keyboardAndBottomSheetHeight) {
          return HomePage(
            conversation: _conversation,
            generatingResponse: _generatingResponse,
            keyboardAndBottomSheetHeight: keyboardAndBottomSheetHeight,
          );
        },
      ),
      resizeToAvoidBottomInset: false,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        "Super Gemini",
        style: TextStyle(
          color: windowForegroundColor, //
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 1,
        ),
      ),
      leading: IconButton(
        onPressed: () {}, //
        icon: Icon(Icons.menu),
        color: windowForegroundColor,
      ),
      actions: [
        Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            shape: BoxShape.circle, //
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ],
      backgroundColor: windowBackgroundColor,
      scrolledUnderElevation: 0,
      centerTitle: true,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.conversation,
    this.generatingResponse,
    required this.keyboardAndBottomSheetHeight,
  });

  final List<String> conversation;
  final String? generatingResponse;

  final double keyboardAndBottomSheetHeight;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pageFocusNode = FocusNode(debugLabel: "home-page");

  @override
  void dispose() {
    _pageFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("Building Home Page with generated response: ${widget.generatingResponse}");
    return Focus(
      focusNode: _pageFocusNode,
      child: GestureDetector(
        onTap: () {
          // We don't really care about focusing ourselves, but by
          // doing so, we'll close the editor/bottom sheet.
          _pageFocusNode.requestFocus();
        },
        behavior: HitTestBehavior.translucent,
        child: _hasConversationStarted
            ? _buildConversation() //
            : _buildWelcome(),
      ),
    );
  }

  bool get _hasConversationStarted => widget.conversation.isNotEmpty || widget.generatingResponse != null;

  Widget _buildWelcome() {
    return OverflowBox(
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: widget.keyboardAndBottomSheetHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 32,
            children: [
              Text(
                "Hello, there!",
                style: TextStyle(
                  color: Colors.blueAccent, //
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                runSpacing: 8,
                children: [
                  _Chip("Create Image"), //
                  _Chip("Write"), _Chip("Build"), _Chip("Deep Research"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversation() {
    return Column(
      children: [
        Expanded(
          child: OverflowBox(
            child: ListView.builder(
              itemCount: widget.conversation.length + (widget.generatingResponse != null ? 1 : 0),
              itemBuilder: (context, index) {
                final text = index >= widget.conversation.length
                    ? widget.generatingResponse!
                    : widget.conversation[index];

                return Padding(padding: const EdgeInsets.all(24), child: Text(text));
              },
            ), //
          ),
        ),
        // Push up above the bottom sheet, minus some bleed over space becuase of
        // rounded corners on the bottom sheet.
        SizedBox(height: max(widget.keyboardAndBottomSheetHeight - 48, 0)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label), //
      shape: StadiumBorder(),
      backgroundColor: const Color(0xFF282a2c),
      side: BorderSide(width: 0),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
