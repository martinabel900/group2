import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Members List Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MembersListScreen(),
    );
  }
}

class MembersListScreen extends StatelessWidget {
  const MembersListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Members List'),
      ),
      body: const MembersList(),
    );
  }
}

class MembersList extends StatelessWidget {
  const MembersList({Key? key}) : super(key: key);

  Future<String> _getProfileImageUrl(String imagePath) async {
    if (imagePath.startsWith('gs://')) {
      try {
        String downloadUrl =
            await FirebaseStorage.instance.refFromURL(imagePath).getDownloadURL();
        return downloadUrl;
      } catch (e) {
        debugPrint("Error fetching image URL: $e");
        return '';
      }
    }
    return imagePath;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No members found.'));
        }

        final users = snapshot.data!.docs;
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            final profileImagePath = userData['profileImage'] ?? '';
            final displayName = userData['name'] ?? 'Anonymous';

            return Card(
              child: ListTile(
                leading: profileImagePath.isNotEmpty
                    ? FutureBuilder<String>(
                        future: _getProfileImageUrl(profileImagePath),
                        builder: (context, imageSnapshot) {
                          if (imageSnapshot.connectionState == ConnectionState.waiting) {
                            return const CircleAvatar(
                              backgroundColor: Colors.grey,
                              child: Icon(Icons.person),
                            );
                          }
                          if (imageSnapshot.hasData && imageSnapshot.data!.isNotEmpty) {
                            return CircleAvatar(
                              backgroundImage: NetworkImage(imageSnapshot.data!),
                            );
                          }
                          return const CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person),
                          );
                        },
                      )
                    : const CircleAvatar(
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person),
                      ),
                title: Text(displayName),
              ),
            );
          },
        );
      },
    );
  }
}
