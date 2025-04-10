
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'team_list.dart';

class TeamManagementScreen extends StatefulWidget {
  final String eventId;
  final String groupId;
  final String groupName;

  const TeamManagementScreen({
    Key? key,
    required this.eventId,
    required this.groupId,
    required this.groupName,
  }) : super(key: key);

  @override
  _TeamManagementScreenState createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _errorMsg = '';

  // Processed players will include both regular and guest players.
  List<Map<String, dynamic>> players = <Map<String, dynamic>>[];
  // Team assignments for each regular player or guest.
  Map<String, String> teamAssignments = {};
  // Fixed team colors.
  static const List<String> fixedTeamColors = ['Blue', 'White', 'Red'];

  // Event details.
  String _eventTitle = '';
  String _eventVenue = '';
  String _eventDate = ''; // Formatted date.
  String _eventTime = ''; // Formatted time.

  @override
  void initState() {
    super.initState();
    debugPrint("TeamManagementScreen initState: eventId received: ${widget.eventId}");
    _getEventAndPlayers();
  }

  // Fetch event details and process players (including guests).
  Future<void> _getEventAndPlayers() async {
    if (widget.eventId.isEmpty) {
      debugPrint("No eventId provided. Cannot fetch event details.");
      setState(() {
        _errorMsg = "No eventId provided. Cannot fetch event details.";
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = "";
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint("No current user found!");
      }
      // Retrieve event document.
      DocumentSnapshot eventDoc =
          await _firestore.collection('events').doc(widget.eventId).get();
      if (!eventDoc.exists) {
        debugPrint("Event document does not exist for eventId: ${widget.eventId}");
        setState(() {
          _errorMsg = "Event document does not exist.";
          _isLoading = false;
        });
        return;
      }
      
      final Map<String, dynamic> eventData =
          eventDoc.data() as Map<String, dynamic>;
      debugPrint("Fetched eventData: $eventData");
      
      // Optional: Replace placeholder CURRENT_USER_ID if present.
      final List<dynamic> originalPlayerList = eventData['players'] ?? [];
      if (currentUser != null && originalPlayerList.contains("CURRENT_USER_ID")) {
        await _firestore.collection('events').doc(widget.eventId).update({
          'players': FieldValue.arrayRemove(["CURRENT_USER_ID"])
        });
        await _firestore.collection('events').doc(widget.eventId).update({
          'players': FieldValue.arrayUnion([currentUser.uid])
        });
        eventDoc = await _firestore.collection('events').doc(widget.eventId).get();
      }
      
      // Refresh event details.
      final Map<String, dynamic> updatedEventData =
          eventDoc.data() as Map<String, dynamic>;
      _eventTitle = updatedEventData['title'] ?? 'No Title';
      _eventVenue = updatedEventData['venue'] ?? 'No Venue';
      if (updatedEventData['datetime'] != null) {
        DateTime dt;
        if (updatedEventData['datetime'] is Timestamp) {
          dt = (updatedEventData['datetime'] as Timestamp).toDate();
        } else if (updatedEventData['datetime'] is DateTime) {
          dt = updatedEventData['datetime'];
        } else if (updatedEventData['datetime'] is String) {
          dt = DateTime.tryParse(updatedEventData['datetime']) ?? DateTime.now();
        } else {
          dt = DateTime.now();
        }
        _eventDate = DateFormat('MMM dd, yyyy').format(dt);
        _eventTime = DateFormat('HH:mm').format(dt);
      } else {
        _eventDate = 'No Date';
        _eventTime = 'No Time';
      }
      
      // Process players: include both regular user IDs and guest players.
      final List<dynamic> playerList = updatedEventData['players'] ?? [];
      List<Map<String, dynamic>> processedPlayers = [];
      teamAssignments.clear();
      for (var entry in playerList) {
        if (entry is String) {
          // Regular user stored as a string.
          String userId = entry;
          if (userId == "CURRENT_USER_ID" && currentUser != null) {
            userId = currentUser.uid;
          }
          processedPlayers.add({'id': userId});
          teamAssignments[userId] ??= '';
        } else if (entry is Map<String, dynamic>) {
          // Assume guest player.
          // The guest map should include fields like 'id', 'name', 'imageUrl', and 'isGuest': true.
          if (entry['isGuest'] == true) {
            processedPlayers.add(entry);
            // Use the guest's id for team assignment if available.
            String guestId = entry['id'] ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';
            teamAssignments[guestId] = teamAssignments[guestId] ?? '';
            // Ensure the guest map has an 'id' property.
            entry['id'] = guestId;
          }
        }
      }
      
      // Fetch details for regular players (ignore entries that already have guest info).
      final List<Future<Map<String, dynamic>>> futures = processedPlayers.map((entry) async {
        // If this entry already contains guest information, return it immediately.
        if (entry.containsKey('isGuest') && entry['isGuest'] == true) {
          return entry;
        } else if (entry.containsKey('id')) {
          String userId = entry['id'];
          try {
            DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
            if (userDoc.exists && userDoc.data() != null) {
              final Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
              return {
                'id': userId,
                'name': userData['name'] ?? 'Unknown',
                'imageUrl': userData['imageUrl'] ?? 'https://example.com/default_image.png'
              };
            } else {
              return {
                'id': userId,
                'name': 'Unknown',
                'imageUrl': 'https://example.com/default_image.png'
              };
            }
          } catch (e) {
            debugPrint("Error fetching user info for $userId: $e");
            return {
              'id': userId,
              'name': 'Error',
              'imageUrl': 'https://example.com/default_image.png'
            };
          }
        } else {
          return entry;
        }
      }).toList();
      final List<Map<String, dynamic>> results = await Future.wait(futures);
      players = results;
      debugPrint("Players list (processed): ${players.toString()}");
      
      // Apply default team assignments if not set.
      if (players.isNotEmpty &&
          players.every((p) => (teamAssignments[p['id']] ?? '').isEmpty)) {
        for (int i = 0; i < players.length; i++) {
          String pid = players[i]['id'];
          teamAssignments[pid] = fixedTeamColors[i % fixedTeamColors.length];
        }
        debugPrint("Default team assignments applied: $teamAssignments");
      } else {
        debugPrint("Existing team assignments found: $teamAssignments");
      }
    } catch (e) {
      debugPrint("Error fetching event/players: $e");
      setState(() {
        _errorMsg = "Error fetching event/players: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _assignPlayersToTeams() async {
    setState(() { _isLoading = true; });
    try {
      await _firestore.collection('events').doc(widget.eventId).update({
        'teamAssignments': teamAssignments,
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Teams saved successfully!')));
    } catch (e) {
      debugPrint("Error saving team assignments: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error saving team assignments: $e")));
    } finally {
      setState(() { _isLoading = false; });
    }
  }
  
  Future<void> _recallTeams() async {
    setState(() { _isLoading = true; });
    try {
      DocumentSnapshot eventDoc = await _firestore.collection('events').doc(widget.eventId).get();
      if (eventDoc.exists) {
        final Map<String, dynamic> eventData = eventDoc.data() as Map<String, dynamic>;
        if (eventData.containsKey('teamAssignments') && eventData['teamAssignments'] != null) {
          setState(() {
            teamAssignments = Map<String, String>.from(eventData['teamAssignments']);
          });
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Teams recalled successfully!')));
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('No teams to recall!')));
        }
      }
    } catch (e) {
      debugPrint("Error recalling teams: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error recalling teams: $e")));
    } finally {
      setState(() { _isLoading = false; });
    }
  }
  
  Future<void> _postTeamsToChat() async {
    Map<String, List<String>> teams = {};
    for (var player in players) {
      final String playerId = player['id'];
      final String assignedTeam = teamAssignments[playerId] ?? '';
      if (assignedTeam.isNotEmpty) {
        teams.putIfAbsent(assignedTeam, () => []).add(player['name']);
      }
    }
    final List<String> messageParts = [];
    teams.forEach((team, names) {
      final String emoji = _getEmojiForTeam(team);
      final String part = "$emoji ${team[0].toUpperCase()}${team.substring(1)} Team:\n${names.join(', ')}";
      messageParts.add(part);
    });
    final String messageBody = messageParts.isNotEmpty
        ? messageParts.join("\n\n")
        : "No teams assigned.";
    try {
      await _firestore.collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .add({
        'sender': "Team Pickers",
        'text': messageBody,
        'timestamp': Timestamp.now(),
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Teams posted to chat successfully!")));
    } catch (e) {
      debugPrint("Error posting teams to chat: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error posting teams to chat: $e")));
    }
  }
  
  String _getEmojiForTeam(String team) {
    switch (team.toLowerCase()) {
      case 'blue':
        return "🔵";
      case 'red':
        return "🔴";
      case 'white':
        return "⚪";
      default:
        return "";
    }
  }
  
  Color _getColorFromName(String teamName) {
    switch (teamName.toLowerCase()) {
      case 'blue':
        return Colors.blue;
      case 'red':
        return Colors.red;
      case 'white':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }
  
  List<Map<String, dynamic>> get _regularPlayers {
    return players;
  }
  
  Widget _buildTeamSummary() {
    final Map<String, List<String>> grouped = {};
    for (var player in _regularPlayers) {
      final String pid = player['id'];
      final String assignedTeam = teamAssignments[pid] ?? '';
      if (assignedTeam.isNotEmpty) {
        grouped.putIfAbsent(assignedTeam, () => []).add(player['name']);
      }
    }
    final List<String> unassigned = [];
    for (var player in _regularPlayers) {
      final String pid = player['id'];
      if ((teamAssignments[pid] ?? '').isEmpty) {
        unassigned.add(player['name']);
      }
    }
    if (unassigned.isNotEmpty) {
      grouped.putIfAbsent('Unassigned', () => []).addAll(unassigned);
    }
    if (grouped.isEmpty) {
      return Container(
        color: Colors.blueGrey[300],
        padding: const EdgeInsets.all(8),
        child: const Center(
          child: Text(
            "No team assignments found.",
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
      );
    }
    return Container(
      color: Colors.blueGrey[300],
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: grouped.entries.map((entry) {
            return Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.all(4),
              width: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: entry.key.toLowerCase() == 'unassigned'
                          ? Colors.black
                          : _getColorFromName(entry.key),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: entry.value
                        .map((name) => Text(
                              name,
                              style: const TextStyle(fontSize: 10),
                            ))
                        .toList(),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
  
  Widget _buildPlayerAssignment(Map<String, dynamic> player) {
    final String playerId = player['id'];
    final String playerName = player['name'];
    final String? assignedTeam = teamAssignments[playerId];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      elevation: 2.0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        title: Text(
          playerName,
          style: const TextStyle(fontSize: 14),
        ),
        trailing: DropdownButton<String>(
          hint: const Text("Assign", style: TextStyle(fontSize: 12)),
          value: (assignedTeam != null && assignedTeam.isNotEmpty) ? assignedTeam : null,
          onChanged: (newValue) {
            setState(() {
              teamAssignments[playerId] = newValue ?? '';
            });
          },
          items: fixedTeamColors.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: const TextStyle(fontSize: 12)),
            );
          }).toList(),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Pickers', style: TextStyle(fontSize: 14)),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, size: 20),
            tooltip: 'Save Teams',
            onPressed: _assignPlayersToTeams,
          ),
          IconButton(
            icon: const Icon(Icons.restore, size: 20),
            tooltip: 'Recall Teams',
            onPressed: _recallTeams,
          ),
          IconButton(
            icon: const Icon(Icons.send, size: 20),
            tooltip: 'Post Teams to Chat',
            onPressed: _postTeamsToChat,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg.isNotEmpty
              ? Center(child: Text(_errorMsg, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey[300],
                          borderRadius: BorderRadius.circular(8.0),
                          boxShadow: [BoxShadow(color: Colors.grey.shade400, blurRadius: 4)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Event Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('Title: $_eventTitle', style: const TextStyle(fontSize: 12)),
                            Text('Venue: $_eventVenue', style: const TextStyle(fontSize: 12)),
                            Text('Date: $_eventDate', style: const TextStyle(fontSize: 12)),
                            Text('Time: $_eventTime', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Player List', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                      const SizedBox(height: 4),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _regularPlayers.length,
                        itemBuilder: (context, index) {
                          return _buildPlayerAssignment(_regularPlayers[index]);
                        },
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
      bottomSheet: SafeArea(child: _buildTeamSummary()),
    );
  }
}
