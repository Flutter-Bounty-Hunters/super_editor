import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// A widget that displays a draft message in a chat experience.
///
/// Shows a truncated preview of the message being composed,
/// with visual indicators that this is a draft (not yet sent).
class ChatDraftPreview extends StatelessWidget {
  const ChatDraftPreview({
    Key? key,
    required this.draftText,
    this.maxLines = 2,
    this.draftStyle,
    this.showDraftIndicator = true,
    this.onTap,
  }) : super(key: key);

  /// The draft text content to display.
  final String draftText;

  /// Maximum number of lines to display before truncation.
  final int maxLines;

  /// Style for the draft preview text.
  final TextStyle? draftStyle;

  /// Whether to show the "Draft" indicator.
  final bool showDraftIndicator;

  /// Callback when the draft is tapped (to continue editing).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDraftIndicator) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_note,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Draft',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text(
              draftText.isEmpty ? 'Type a message...' : draftText,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: draftStyle ??
                  TextStyle(
                    color: draftText.isEmpty ? Colors.grey[500] : Colors.black87,
                    fontSize: 14,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Controller for managing chat draft state.
class ChatDraftController extends ChangeNotifier {
  ChatDraftController();

  String _draftText = '';
  bool _hasDraft = false;
  DateTime? _lastModified;

  /// The current draft text.
  String get draftText => _draftText;

  /// Whether there is content in the draft.
  bool get hasDraft => _hasDraft;

  /// When the draft was last modified.
  DateTime? get lastModified => _lastModified;

  /// Update the draft text.
  void updateDraft(String text) {
    _draftText = text;
    _hasDraft = text.isNotEmpty;
    _lastModified = DateTime.now();
    notifyListeners();
  }

  /// Clear the draft.
  void clearDraft() {
    _draftText = '';
    _hasDraft = false;
    _lastModified = null;
    notifyListeners();
  }
}

/// A chat input widget with draft support.
///
/// Provides a text field for composing messages with draft preview.
class ChatInputWithDraft extends StatefulWidget {
  const ChatInputWithDraft({
    Key? key,
    required this.onSend,
    this.onDraftChanged,
    this.draftController,
    this.maxLines = 3,
    this.sendButtonStyle,
    this.inputDecoration,
  }) : super(key: key);

  /// Callback when message is sent.
  final void Function(String message) onSend;

  /// Callback when draft changes.
  final void Function(String draft)? onDraftChanged;

  /// Controller for draft state (optional).
  final ChatDraftController? draftController;

  /// Max lines for input field.
  final int maxLines;

  /// Style for send button.
  final ButtonStyle? sendButtonStyle;

  /// Decoration for input field.
  final InputDecoration? inputDecoration;

  @override
  State<ChatInputWithDraft> createState() => _ChatInputWithDraftState();
}

class _ChatInputWithDraftState extends State<ChatInputWithDraft> {
  late final AttributedTextEditingController _textController;
  late final ChatDraftController _draftController;
  bool _showDraftPreview = false;

  @override
  void initState() {
    super.initState();
    _textController = AttributedTextEditingController();
    _draftController = widget.draftController ?? ChatDraftController();
    
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    if (widget.draftController == null) {
      _draftController.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    final text = _textController.text.text;
    _draftController.updateDraft(text);
    widget.onDraftChanged?.call(text);
    
    // Show draft preview when there's content and user isn't typing
    setState(() {
      _showDraftPreview = text.isNotEmpty;
    });
  }

  void _handleSend() {
    final text = _textController.text.text;
    if (text.isNotEmpty) {
      widget.onSend(text);
      _textController.text = AttributedText();
      _draftController.clearDraft();
      setState(() {
        _showDraftPreview = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showDraftPreview) ...[
          ChatDraftPreview(
            draftText: _textController.text.text,
            maxLines: 2,
            onTap: () {
              // Focus back on input
            },
          ),
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: SuperTextField(
                textController: _textController,
                maxLines: widget.maxLines,
                hintBuilder: StyledHintBuilder(
                  hintTextSpan: TextSpan(
                    text: 'Type a message...',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ),
                decoration: widget.inputDecoration ??
                    InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _handleSend,
              icon: Icon(Icons.send),
              style: widget.sendButtonStyle ??
                  IconButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Example usage widget showing how to integrate draft support.
class ChatExample extends StatefulWidget {
  const ChatExample({Key? key}) : super(key: key);

  @override
  State<ChatExample> createState() => _ChatExampleState();
}

class _ChatExampleState extends State<ChatExample> {
  final List<String> _messages = [];
  final ChatDraftController _draftController = ChatDraftController();

  void _handleSend(String message) {
    setState(() {
      _messages.add(message);
    });
    _draftController.clearDraft();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(_messages[index]),
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ChatInputWithDraft(
            onSend: _handleSend,
            draftController: _draftController,
          ),
        ),
      ],
    );
  }
}
