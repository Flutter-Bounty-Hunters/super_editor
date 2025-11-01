import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gemini/infrastructure/bottom_sheet_chat_scaffold.dart';
import 'package:gemini/infrastructure/theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(), //
      extendBodyBehindAppBar: true,
      body: BottomSheetChatScaffold(
        contentBuilder: (context, keyboardAndBottomSheetHeight) {
          return Column(
            children: [
              Expanded(
                child: OverflowBox(
                  child: HomePage(), //
                ),
              ),
              // Push up above the bottom sheet, minus some bleed over space.
              SizedBox(height: max(keyboardAndBottomSheetHeight - 48, 0)),
            ],
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
      backgroundColor: Colors.transparent,
      centerTitle: true,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

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
    return Focus(
      focusNode: _pageFocusNode,
      child: GestureDetector(
        onTap: () {
          // We don't really care about focusing ourselves, but by
          // doing so, we'll close the editor/bottom sheet.
          _pageFocusNode.requestFocus();
        },
        behavior: HitTestBehavior.translucent,
        child: Center(
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
