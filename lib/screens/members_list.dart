import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
/// Displays a list of current group members for the given group.
/// The group creator (from 'createdBy') is displayed with a special label ("Creator")
/// and is untouchable. Other members are labeled "Member" by default and "Admin"
/// if they are in the group's admins list. If the viewer is an admin, they will
/// see a '+' icon next to a non-admin to promote them, or a '-' icon next to an admin
/// (but not for the creator) to demote them.
class MembersListScreen extends StatelessWidget {
  final String groupId;
  final String currentUserId; // currently logged in user's uid

  const MembersListScreen({
    Key? key,
    required this.groupId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Listen to changes in the group document.
    return Scaffold(
      appBar: AppBar(
        title: const Text("Members List"),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('groups').doc(groupId).snapshots(),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.hasError) {
            debugPrint('Error retrieving group document: ${groupSnapshot.error}');
            return const Center(child: Text('Error loading group.'));
          }
          // Show loader while waiting.
          if (groupSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!groupSnapshot.hasData || !groupSnapshot.data!.exists) {
            return const Center(child: Text('Group not found.'));
          }
          
          final groupData = groupSnapshot.data!.data() as Map<String, dynamic>;
          debugPrint('Loaded group data: $groupData');

          // Retrieve members, admins and the group creator.
          final List<dynamic> memberIds = groupData['members'] is List ? groupData['members'] : [];
          final List<dynamic> adminIds = groupData['admins'] is List ? groupData['admins'] : [];
          final String groupCreator = (groupData['createdBy'] ?? '') as String;

          // Determine if the current viewer is an admin.
          final bool viewerIsAdmin = adminIds.contains(currentUserId);

          if (memberIds.isEmpty) {
            return const Center(child: Text('No members found.'));
          }

          return ListView.builder(
            itemCount: memberIds.length,
            itemBuilder: (context, index) {
              final String memberId = memberIds[index].toString();
              // Determine member status.
              String status;
              if (memberId == groupCreator) {
                status = "Creator";
              } else {
                status = adminIds.contains(memberId) ? "Admin" : "Member";
              }
              debugPrint('Member $memberId status: $status');

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: UserListTile(
                  userId: memberId,
                  status: status,
                  groupId: groupId,
                  currentUserId: currentUserId,
                  viewerIsAdmin: viewerIsAdmin,
                  groupCreator: groupCreator,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Widget to display user details from the "users" collection.
/// It shows the user’s name, profile image (if available), and a status indicator ("Creator", "Admin", or "Member").
/// If the viewer is an admin and this member is not the group creator,
/// then a promotion/demotion button is shown.
class UserListTile extends StatelessWidget {
  final String userId;
  final String status; // "Creator", "Admin", or "Member"
  final String groupId;
  final String currentUserId;
  final bool viewerIsAdmin;
  final String groupCreator;

  const UserListTile({
    Key? key,
    required this.userId,
    required this.status,
    required this.groupId,
    required this.currentUserId,
    required this.viewerIsAdmin,
    required this.groupCreator,
  }) : super(key: key);

  // Fetch user document from "users" collection.
  Future<DocumentSnapshot> _fetchUser() {
    return FirebaseFirestore.instance.collection('users').doc(userId).get();
  }

  /// This method checks if [imagePath] already looks like a URL (starts with http).
  /// If so, it returns it directly; otherwise, it attempts to fetch the download URL from Firebase Storage.
  Future<String> _getProfileImageUrl(String imagePath) async {
    if (imagePath.isEmpty) return '';
    if (imagePath.startsWith('http')) return imagePath;
    try {
      return await FirebaseStorage.instance.ref(imagePath).getDownloadURL();
    } catch (e) {
      debugPrint('Error fetching profile image: $e');
      return '';
    }
  }

  // Promote a user to admin.
  Future<void> _promoteUser() async {
    try {
      await FirebaseFirestore.instance.collection('groups').doc(groupId).update({
        'admins': FieldValue.arrayUnion([userId])
      });
    } catch (e) {
      debugPrint('Error promoting user $userId: $e');
    }
  }

  // Demote a user from admin.
  Future<void> _demoteUser() async {
    try {
      await FirebaseFirestore.instance.collection('groups').doc(groupId).update({
        'admins': FieldValue.arrayRemove([userId])
      });
    } catch (e) {
      debugPrint('Error demoting user $userId: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _fetchUser(),
      builder: (context, snapshot) {
        String displayName = userId;
        String profileImagePath = '';

        if (snapshot.hasError) {
          debugPrint('Error fetching user data for $userId: ${snapshot.error}');
        }
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          displayName = data['name'] ?? userId;
          profileImagePath = data['profileImage'] ?? '';
        }

        Widget leadingWidget = const CircleAvatar(
  backgroundColor: Colors.grey,
  child: Icon(Icons.person),
);

if (profileImagePath.isNotEmpty) {
  leadingWidget = FutureBuilder<String>(
    future: _getProfileImageUrl(profileImagePath),
    builder: (context, imageSnapshot) {
      if (imageSnapshot.connectionState == ConnectionState.waiting ||
          imageSnapshot.data == null ||
          imageSnapshot.data!.isEmpty) {
        return const CircleAvatar(
          backgroundColor: Colors.grey,
          child: Icon(Icons.person),
        );
      }
      
      // Use CachedNetworkImageProvider instead of NetworkImage for caching
      return CircleAvatar(
        backgroundImage: imageSnapshot.data!.isNotEmpty
            ? CachedNetworkImageProvider(imageSnapshot.data!)  // Caching added here
            : null,
      );
    },
  );
}

        // If the current viewer is an admin and this member is not the group creator,
        // allow promotion/demotion controls.
        Widget? trailing;
        if (viewerIsAdmin && userId != groupCreator) {
          if (status == "Member") {
            trailing = IconButton(
              icon: const Icon(Icons.add, color: Colors.green),
              onPressed: () async {
                await _promoteUser();
              },
            );
          } else if (status == "Admin") {
            trailing = IconButton(
              icon: const Icon(Icons.remove, color: Colors.red),
              onPressed: () async {
                await _demoteUser();
              },
            );
          }
        }

        return ListTile(
          leading: leadingWidget,
          title: Text(
            displayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            status,
            style: TextStyle(
              color: status == "Creator"
                  ? Colors.deepPurple
                  : (status == "Admin" ? Colors.blue : Colors.black),
            ),
          ),
          trailing: trailing,
        );
      },
    );
  }
}
