
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final String sender;
  final String senderId;
  final String time;
  final bool isMe;
  final String imageUrl; // For image messages.
  final void Function()? onReply; // Callback for reply action.

  const ChatBubble({
    Key? key,
    required this.message,
    required this.sender,
    required this.senderId,
    required this.time,
    required this.isMe,
    this.imageUrl = '',
    this.onReply,
  }) : super(key: key);

  void _showMessageActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  if (onReply != null) {
                    // Debug print to verify onReply is called.
                    print("Reply action triggered in ChatBubble.");
                    onReply!();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe ? Colors.blueGrey[600] : Colors.grey[300];
    final textColor = isMe ? Colors.white : Colors.black87;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showMessageActions(context),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                sender,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              // Display image if imageUrl is provided.
              if (imageUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                  ),
                ),
              // Show message text if available.
              if (message.isNotEmpty)
                Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
