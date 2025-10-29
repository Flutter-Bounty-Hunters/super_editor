import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:slack/domain/message.dart';
import 'package:slack/domain/user.dart';
import 'package:slack/fake_data/fake_users.dart';
import 'package:slack/styles.dart';
import 'package:super_editor/super_editor.dart';

/// A vertical list of messages.
///
/// Each message contains a user avatar, the message content and the user name.
class ChatThread extends StatelessWidget {
  const ChatThread({
    super.key,
    required this.messages,
    required this.backgroundColor,
    this.scrollController,
  });

  /// The messages to display.
  final List<Message> messages;

  /// The background color of each message.
  final Color backgroundColor;

  /// The `ScrollController` that controls the list scrolling.
  final ScrollController? scrollController;

  String _formatDate(DateTime date) {
    final today = DateTime.now();
    if (date.day == today.day && date.month == today.month && date.year == today.year) {
      return 'Today';
    }

    // Get the full month name
    final month = DateFormat('MMMM').format(date);

    final day = date.day;
    final suffix = _getDaySuffix(day);

    return '$month $day$suffix';
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final reversedList = messages.reversed.toList();
    return ListView.separated(
      controller: scrollController,
      physics: const ClampingScrollPhysics(),
      reverse: true,
      itemBuilder: (context, index) => _buildMessage(reversedList, index),
      separatorBuilder: (context, index) {
        final message = reversedList[index];
        final previousMessage = index < reversedList.length - 1 //
            ? reversedList[index + 1]
            : null;
        return _buildSeparator(message, previousMessage);
      },
      itemCount: reversedList.length,
    );
  }

  Widget _buildMessage(List<Message> messages, int index) {
    if (index == messages.length - 1) {
      // This is the oldest message in the list.
      // Show the date above it.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDividerForDate(messages[index].sentAt),
          _MessageTile(
            messages: messages,
            index: index,
            backgroundColor: backgroundColor,
          ),
        ],
      );
    }

    if (index == 0) {
      // This is the newest message in the list.
      // Add some space below it.
      return Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: _MessageTile(
          messages: messages,
          index: index,
          backgroundColor: backgroundColor,
        ),
      );
    }

    return _MessageTile(
      messages: messages,
      index: index,
      backgroundColor: backgroundColor,
    );
  }

  Widget _buildSeparator(Message message, Message? nextMessage) {
    if (nextMessage == null) {
      // This is the last message in the list.
      // Don't show the separator.
      return const SizedBox(height: 0);
    }
    if (message.userId == nextMessage.userId && _isSameDate(message.sentAt, nextMessage.sentAt)) {
      // The message is from the same user and date as the previous message.
      // Don't show the separator and don't add more space between messages.
      return const SizedBox(height: 0);
    }
    if (message.userId != nextMessage.userId && _isSameDate(message.sentAt, nextMessage.sentAt)) {
      // The message is on the same day as the previous message.
      // Don't show the separator.
      return const SizedBox(height: 5);
    }
    return _buildDividerForDate(message.sentAt);
  }

  Widget _buildDividerForDate(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15.0),
      child: Row(
        children: [
          Expanded(
            child: const Divider(color: dividerColor),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: dividerColor,
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 4.0,
            ),
            child: Text(_formatDate(date)),
          ),
          Expanded(
            child: const Divider(color: dividerColor),
          ),
        ],
      ),
    );
  }
}

/// Displays a single message from a list.
///
/// Shows the user avatar, the message content and the user's name.
class _MessageTile extends StatefulWidget {
  const _MessageTile({
    required this.messages,
    required this.index,
    required this.backgroundColor,
  });

  /// List containing all messages.
  ///
  /// We take the whole list instead of a single message because
  /// render the message differently depending on the previous message.
  final List<Message> messages;

  /// The index of the message to be displayed.
  final int index;

  final Color backgroundColor;

  @override
  State<_MessageTile> createState() => _MessageTileState();
}

class _MessageTileState extends State<_MessageTile> {
  late Message _message;
  late final Editor _editor;
  final GlobalKey _documentLayoutKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _syncMessageWithLatestWidget();
  }

  @override
  void didUpdateWidget(_MessageTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.messages[widget.index] != _message) {
      _editor.dispose();
      _syncMessageWithLatestWidget();
    }
  }

  void _syncMessageWithLatestWidget() {
    _message = widget.messages[widget.index];
    _editor = createDefaultDocumentEditor(
      document: MutableDocument(nodes: _message.content.toList()),
      composer: MutableDocumentComposer(),
    );
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The list is reversed, so the previous message is at index + 1.
    final previousMessage = widget.index < widget.messages.length - 1 //
        ? widget.messages[widget.index + 1]
        : null;

    final user = fakeUsers.where((e) => e.id == _message.userId).first;
    final sameUserAsLastMessage = previousMessage != null && previousMessage.userId == _message.userId;
    final isSameDate = _isSameDate(_message.sentAt, previousMessage?.sentAt ?? DateTime.now());

    final shouldDisplayAvatar = !sameUserAsLastMessage || !isSameDate;

    return ColoredBox(
      color: widget.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 8.0, top: 2, bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            shouldDisplayAvatar
                ? _buildUserAvatar(user.avatarUrl)
                : const SizedBox(
                    width: 46,
                    height: 0,
                  ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (shouldDisplayAvatar) //
                    _buildMessageHeader(user),
                  _buildMessageContent(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(String avatarUrl) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, right: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          avatarUrl,
          height: 36,
          width: 36,
        ),
      ),
    );
  }

  Widget _buildMessageHeader(User user) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0, top: 5.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            user.displayName,
            selectionColor: Colors.blue,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 15),
          _buildMessageTime(_message.sentAt),
        ],
      ),
    );
  }

  Widget _buildMessageContent() {
    return IgnorePointer(
      child: SuperChatBubble(
        editor: _editor,
        documentLayoutKey: _documentLayoutKey,
        stylesheet: defaultStylesheet.copyWith(
          documentPadding: const EdgeInsets.symmetric(
            horizontal: 10.0,
            vertical: 0.0,
          ),
          selectedTextColorStrategy: makeSelectedTextBlack,
          addRulesAfter: messageListStyles,
          inlineTextStyler: _inlineStyler,
        ),
      ),
    );
  }

  Widget _buildMessageTime(DateTime dateTime) {
    return Text(
      DateFormat('h:mm a').format(dateTime),
      style: const TextStyle(
        fontSize: 14,
        color: Colors.white54,
      ),
    );
  }

  TextStyle _inlineStyler(Set<Attribution> attributions, TextStyle existingStyle) {
    TextStyle style = defaultInlineTextStyler(attributions, existingStyle);

    if (attributions.contains(stableTagComposingAttribution)) {
      style = style.copyWith(
        color: Colors.blue,
      );
    }

    if (attributions.whereType<CommittedStableTagAttribution>().isNotEmpty) {
      style = style.copyWith(
        color: Colors.orange,
      );
    }

    return style;
  }
}

bool _isSameDate(DateTime date1, DateTime date2) {
  return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
}
