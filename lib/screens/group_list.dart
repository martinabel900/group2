import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'group_chat.dart';
import 'add_group.dart';
import 'login.dart';
import 'user_profile.dart';
import 'unified_login.dart';

class GroupListScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const GroupListScreen({Key? key, required this.userId, required this.userName}) : super(key: key);

  @override
  _GroupListScreenState createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  Future<void> _onLogout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const UnifiedLoginScreen()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error signing out: $e")));
    }
  }

  void _onAddGroup() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const AddGroupScreen()));
  }
  
  void _goToUserProfile() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: widget.userId)));
  }
  
  Future<void> _uploadGroupImage(BuildContext context, String groupId) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (pickedFile == null) return;

      File file = File(pickedFile.path);
      final Reference storageRef = FirebaseStorage.instance.ref().child('group_images').child('$groupId.jpg');
      UploadTask uploadTask = storageRef.putFile(file);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      await _firestore.collection('groups').doc(groupId).update({
        'group_images': downloadUrl,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Group image updated.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating image: $e")));
      }
    }
  }

  String getFirebaseImageUrl(String gsUrl) {
    if (gsUrl.startsWith('gs://')) {
      final withoutProtocol = gsUrl.replaceFirst('gs://', '');
      final firstSlashIndex = withoutProtocol.indexOf('/');
      if (firstSlashIndex != -1) {
        final bucket = withoutProtocol.substring(0, firstSlashIndex);
        final objectPath = withoutProtocol.substring(firstSlashIndex + 1);
        final encodedObjectPath = Uri.encodeComponent(objectPath);
        return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedObjectPath?alt=media';
      }
    }
    return gsUrl;
  }

  @override
  Widget build(BuildContext context) {
    final Color blueGrey150 = Color.lerp(Colors.blueGrey[100], Colors.blueGrey[200], 0.5)!;
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? widget.userId;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Groups List'),
        actions: [
          IconButton(icon: const Icon(Icons.account_circle), tooltip: 'Profile', onPressed: _goToUserProfile),
          IconButton(icon: const Icon(Icons.add), tooltip: 'Add Group', onPressed: _onAddGroup),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: () => _onLogout(context)),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('groups').where('members', arrayContains: currentUserId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snapshot.data!.docs;
          if (groups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "You are not part of any groups. Please create a group or wait for an invitation.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async { setState(() {}); },
            child: ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final doc = groups[index];
                final docData = doc.data() as Map<String, dynamic>?;
                final groupName = docData?['name'] ?? 'No Name';
                final groupFunction = docData?['function'] ?? 'No Function';
                final memberCount = (docData?['members'] as List<dynamic>?)?.length ?? 0;
                final rawGroupImageUrl = docData?['group_images'] as String?;
                final groupImageUrl = (rawGroupImageUrl != null && rawGroupImageUrl.isNotEmpty)
                    ? getFirebaseImageUrl(rawGroupImageUrl)
                    : '';
                return Card(
                  color: blueGrey150,
                  elevation: 3.0,
                  margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    leading: GestureDetector(
                      onTap: () => _uploadGroupImage(context, doc.id),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.blueGrey[200],
                        backgroundImage: groupImageUrl.isNotEmpty ? CachedNetworkImageProvider(groupImageUrl) : null,
                        child: groupImageUrl.isEmpty ? const Icon(Icons.group, size: 24, color: Colors.white) : null,
                      ),
                    ),
                    title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Row(
                        children: [
                          Text(groupFunction, style: const TextStyle(fontSize: 16)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey[600],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Members: $memberCount',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Navigation to GroupChatScreen
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => GroupChatScreen(
                            eventId: "", // Passing empty eventId here
                            groupId: doc.id,
                            groupName: groupName,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}