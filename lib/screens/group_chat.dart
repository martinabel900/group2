import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'services/image_upload_service.dart';
import 'widgets/event_detail_card_widget.dart';
import 'widgets/eventlistwidget.dart';
import 'widgets/chat_bubble.dart';
import 'albums.dart';
import 'team_management.dart';       // For navigating directly to TeamManagementScreen if needed
import 'assign_team_pickers.dart';    // AssignTeamPickersScreen for admin-only assignment
// We now route to biometric verification for team management:
import 'team_management_bio.dart';    

class GroupChatScreen extends StatefulWidget {
  final String eventId;
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    Key? key,
    required this.eventId,
    required this.groupId,
    required this.groupName,
  }) : super(key: key);

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  final ImageUploadService _imageUploadService = ImageUploadService();

  @override
  void initState() {
    super.initState();
    debugPrint("GroupChatScreen initState: groupId = ${widget.groupId}");
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<String> _getUserName(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        return data['name'] ?? 'Unknown';
      }
    } catch (error) {
      debugPrint("Error fetching user name: $error");
    }
    return 'Unknown';
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final user = _auth.currentUser;
    if (user == null) return;
    final String userName = await _getUserName(user.uid);
    await _firestore.collection('groups').doc(widget.groupId).collection('messages').add({
      'text': _messageController.text.trim(),
      'senderId': user.uid,
      'sender': userName,
      'timestamp': FieldValue.serverTimestamp(),
      'imageUrl': '',
    });
    _messageController.clear();
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  Future<void> _sendImageMessage(ImageSource source) async {
    final user = _auth.currentUser;
    if (user == null) return;
    String? imageUrl = await _imageUploadService.pickCompressAndUpload(
      source,
      storagePath: 'chat_images',
      onProgress: (snapshot) {},
    );
    if (imageUrl != null) {
      final String userName = await _getUserName(user.uid);
      await _firestore.collection('groups').doc(widget.groupId).collection('messages').add({
        'text': '',
        'senderId': user.uid,
        'sender': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': imageUrl,
      });
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  void _pickImageSource() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Choose Image Source"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _sendImageMessage(ImageSource.camera);
            },
            child: const Text("Camera"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _sendImageMessage(ImageSource.gallery);
            },
            child: const Text("Gallery"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  void _handleMenuSelection(String value) {
    if (!mounted) return;
    switch (value) {
      case 'create_event':
        Navigator.pushNamed(context, '/event', arguments: {
          'groupId': widget.groupId,
          'groupName': widget.groupName,
        });
        break;
      case 'group_members':
        Navigator.pushNamed(context, '/membersList', arguments: {
          'groupId': widget.groupId,
          'groupName': widget.groupName,
        });
        break;
      case 'add_member':
        Navigator.pushNamed(context, '/addMember', arguments: {
          'groupId': widget.groupId,
          'groupName': widget.groupName,
        });
        break;
      case 'albums':
        Navigator.pushNamed(context, '/albums', arguments: {
          'groupId': widget.groupId,
          'groupName': widget.groupName,
        });
        break;
      case 'open_team_management':
        _openTeamManagement();
        break;
      case 'assign_team_pickers':
        _openAssignTeamPickers();
        break;
      default:
        break;
    }
  }

  // Instead of directly accessing TeamManagementScreen,
  // route to the biometric verification screen (TeamManagementBio).
  Future<void> _openTeamManagement() async {
    // If widget.eventId is empty, assign a default event id so that the bio screen doesn't complain.
    final String validEventId = widget.eventId.isNotEmpty ? widget.eventId : "default_event";
    Navigator.pushNamed(
      context,
      '/teamManagementBio',
      arguments: {
        'eventId': validEventId,    // Use the default if needed so as to bypass the "event not selected" error.
        'groupId': widget.groupId,
        'groupName': widget.groupName,
        'access': 'teamPicker',     // Optional flag to let TeamManagementBio know the user is a team picker.
      },
    );
  }

  // Navigate to the AssignTeamPickersScreen.
  void _openAssignTeamPickers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignTeamPickersScreen(
          groupId: widget.groupId,
          groupName: widget.groupName,
        ),
      ),
    );
  }

  Future<void> _shareChatImage(String imageUrl) async {
    await Share.share(imageUrl);
  }

  Future<void> _shareChatImageUrl(String imageUrl) async {
    await Share.share(imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('groups').doc(widget.groupId).snapshots(),
      builder: (context, groupSnapshot) {
        if (groupSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!groupSnapshot.hasData || !groupSnapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text('Group not found')));
        }
        final Map<String, dynamic> groupData = groupSnapshot.data!.data() as Map<String, dynamic>;
        final List<dynamic> admins = groupData['admins'] is List ? List.from(groupData['admins']) : [];
        final bool isCurrentUserAdmin = admins.contains(_auth.currentUser?.uid);

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.groupName),
            actions: [
              PopupMenuButton<String>(
                onSelected: _handleMenuSelection,
                itemBuilder: (context) {
                  List<PopupMenuEntry<String>> items = [
                    const PopupMenuItem(value: 'create_event', child: Text('Create Event')),
                    const PopupMenuItem(value: 'group_members', child: Text('Group Members')),
                    const PopupMenuItem(value: 'add_member', child: Text('Add Member')),
                    const PopupMenuItem(value: 'albums', child: Text('Albums')),
                    const PopupMenuItem(value: 'open_team_management', child: Text('Team Management')),
                  ];
                  if (isCurrentUserAdmin) {
                    items.add(const PopupMenuItem(value: 'assign_team_pickers', child: Text('Assign Team Pickers')));
                  }
                  return items;
                },
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EventListWidget(groupId: widget.groupId, isAdmin: isCurrentUserAdmin),
              Expanded(
                child: ChatMessagesWidget(
                  groupId: widget.groupId,
                  scrollController: _scrollController,
                  shareImageCallback: _shareChatImageUrl,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.image), onPressed: _pickImageSource),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

class ChatMessagesWidget extends StatelessWidget {
  final String groupId;
  final ScrollController scrollController;
  final Future<void> Function(String) shareImageCallback;

  const ChatMessagesWidget({
    Key? key,
    required this.groupId,
    required this.scrollController,
    required this.shareImageCallback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No messages yet"));
        }
        final docs = snapshot.data!.docs;
        return ListView.builder(
          controller: scrollController,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final Map<String, dynamic> data = docs[index].data() as Map<String, dynamic>;
            final String sender = data['sender'] ?? 'Unknown';
            final String senderId = data['senderId'] ?? '';
            final String text = data['text'] ?? '';
            final String imageUrl = data['imageUrl'] ?? '';
            final Timestamp ts = data['timestamp'] ?? Timestamp.now();
            final DateTime date = ts.toDate();
            final String timeString = DateFormat('hh:mm a').format(date);
            final bool isMe = (currentUserId == senderId);

            Widget messageWidget = ChatBubble(
              message: text,
              sender: sender,
              senderId: senderId,
              time: timeString,
              isMe: isMe,
              imageUrl: imageUrl,
            );

            if (imageUrl.isNotEmpty) {
              messageWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  messageWidget,
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.share, color: Colors.blue),
                      onPressed: () => shareImageCallback(imageUrl),
                      tooltip: 'Share Image',
                    ),
                  ),
                ],
              );
            }
            return messageWidget;
          },
        );
      },
    );
  }
}