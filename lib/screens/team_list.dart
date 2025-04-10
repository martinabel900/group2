
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TeamListScreen extends StatelessWidget {
  final String eventId;
  final String groupId;

  const TeamListScreen({
    Key? key,
    required this.eventId,
    required this.groupId,
  }) : super(key: key);

  // Method to fetch a user's info from Firestore.
  // Returns a map containing 'name' and 'profileImage' (if available).
  Future<Map<String, dynamic>> _getUserInfo(String uid) async {
    try {
      final DocumentSnapshot userSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userSnapshot.exists) {
        return userSnapshot.data() as Map<String, dynamic>;
      } else {
        return {'name': 'User not found', 'profileImage': ''};
      }
    } catch (e) {
      debugPrint("Error in _getUserInfo for uid $uid: $e");
      return {'name': 'Error fetching name', 'profileImage': ''};
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("TeamListScreen constructed with eventId: $eventId and groupId: $groupId");
    return Scaffold(
      appBar: AppBar(title: const Text("Team List")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection("events").doc(eventId).snapshots(),
        builder: (context, snapshot) {
          debugPrint("Snapshot connectionState: ${snapshot.connectionState}");
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            debugPrint("No data in snapshot for eventId: $eventId. Error: ${snapshot.error}");
            return Center(child: Text("No event found with ID: $eventId (no data)"));
          }
          // Dump the raw snapshot data for debugging.
          final DocumentSnapshot doc = snapshot.data!;
          debugPrint("Raw snapshot for eventId $eventId: ${doc.data()}");
          if (!doc.exists) {
            debugPrint("Document does not exist for eventId: $eventId");
            return Center(child: Text("No event found with ID: $eventId"));
          }
          final data = doc.data() as Map<String, dynamic>;
          // Log the active field value (if any).
          if (data.containsKey('active')) {
            debugPrint("Event active status: ${data['active']}");
          } else {
            debugPrint("Event active status not set; treating event as active.");
          }
          // Filter: if active is explicitly false, hide the event.
          if (data.containsKey('active') && data['active'] == false) {
            debugPrint("Event $eventId marked inactive. Not showing.");
            return Container();
          }

          final List<dynamic> players = data['players'] is List ? (data['players'] as List) : [];
          if (players.isEmpty) {
            debugPrint("Event $eventId has no players");
            return const Center(child: Text("No players found"));
          }
          debugPrint("Team pickers list: $players");
          return ListView.builder(
            itemCount: players.length,
            itemBuilder: (context, index) {
              dynamic playerData = players[index];
              String? playerId;
              String displayName = "Loading...";
              String profileImage = "";

              // If the playerData is a Map (guest/user details):
              if (playerData is Map<String, dynamic>) {
                if (playerData['isGuest'] == true) {
                  displayName = playerData['name'] ?? "Guest";
                  profileImage = playerData['imageUrl'] ?? "";
                  return ListTile(
                    leading: profileImage.isNotEmpty
                        ? CircleAvatar(
                            backgroundColor: Colors.grey[300],
                            child: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: profileImage,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const CircularProgressIndicator(),
                                errorWidget: (context, url, error) => const Icon(Icons.error),
                              ),
                            ),
                          )
                        : const CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person),
                          ),
                    title: Text(displayName),
                  );
                } else {
                  playerId = playerData['id']?.toString() ?? "";
                }
              } else if (playerData is String) {
                playerId = playerData;
                if (playerId.startsWith("Guest_")) {
                  List<String> parts = playerId.split('_');
                  displayName = parts.length >= 3 ? parts.sublist(2).join('_') : "Guest";
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person),
                    ),
                    title: Text(displayName),
                  );
                }
              }

              if (playerId == "CURRENT_USER_ID") {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null) {
                  playerId = currentUser.uid;
                }
              }
              debugPrint("Fetching info for playerId: $playerId");
              return FutureBuilder<Map<String, dynamic>>(
                future: _getUserInfo(playerId ?? ''),
                builder: (context, infoSnapshot) {
                  if (infoSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person),
                      ),
                      title: Text("Loading..."),
                    );
                  }
                  if (infoSnapshot.hasError || !infoSnapshot.hasData) {
                    displayName = "Unknown";
                  } else {
                    final info = infoSnapshot.data!;
                    displayName = info['name'] ?? "No name available";
                    profileImage = info['profileImage'] ?? info['imageUrl'] ?? "";
                  }
                  return ListTile(
                    leading: profileImage.isNotEmpty
                        ? CircleAvatar(
                            backgroundColor: Colors.grey[300],
                            child: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: profileImage,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const CircularProgressIndicator(),
                                errorWidget: (context, url, error) => const Icon(Icons.error),
                              ),
                            ),
                          )
                        : const CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person),
                          ),
                    title: Text(displayName),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
