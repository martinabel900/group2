import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AssignTeamPickersScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const AssignTeamPickersScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
  }) : super(key: key);

  @override
  _AssignTeamPickersScreenState createState() => _AssignTeamPickersScreenState();
}

class _AssignTeamPickersScreenState extends State<AssignTeamPickersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Map of userId to bool indicating if they are selected as a team picker.
  Map<String, bool> _teamPickerSelection = {};
  // List of group members fetched from Firestore.
  List<Map<String, dynamic>> _groupMembers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchGroupMembers();
  }

  Future<void> _fetchGroupMembers() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Get the group document.
      DocumentSnapshot groupDoc = await _firestore.collection('groups').doc(widget.groupId).get();
      if (groupDoc.exists && groupDoc.data() != null) {
        final groupData = groupDoc.data() as Map<String, dynamic>;
        final List<dynamic> memberIds = groupData['members'] ?? [];
        // Also, fetch current team pickers if any.
        final List<dynamic> currentTeamPickers = groupData['teamPickers'] ?? [];

        // For simplicity, we assume the members field holds a list of userIds.
        List<Map<String, dynamic>> members = [];
        for (var uid in memberIds) {
          DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
          if (userDoc.exists && userDoc.data() != null) {
            final userData = userDoc.data() as Map<String, dynamic>;
            members.add({
              'uid': uid,
              'name': userData['name'] ?? 'Unknown',
            });
            // Initialize selection based on current team pickers.
            _teamPickerSelection[uid] = currentTeamPickers.contains(uid);
          } else {
            // If user not found, still add an entry with a fallback name.
            members.add({
              'uid': uid,
              'name': 'Unknown',
            });
            _teamPickerSelection[uid] = currentTeamPickers.contains(uid);
          }
        }
        setState(() {
          _groupMembers = members;
        });
      }
    } catch (e) {
      debugPrint("Error fetching group members: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTeamPickers() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Get the list of UIDs that are selected as team pickers.
      List<String> selectedTeamPickers = _teamPickerSelection.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toList();

      await _firestore.collection('groups').doc(widget.groupId).update({
        'teamPickers': selectedTeamPickers,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Team Pickers updated successfully!")),
      );
    } catch (e) {
      debugPrint("Error saving team pickers: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving team pickers: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildMemberList() {
    if (_groupMembers.isEmpty) {
      return const Center(child: Text("No members found."));
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _groupMembers.length,
      itemBuilder: (context, index) {
        final member = _groupMembers[index];
        final String uid = member['uid'];
        final String name = member['name'];
        final bool isSelected = _teamPickerSelection[uid] ?? false;
        return ListTile(
          title: Text(name),
          trailing: Checkbox(
            value: isSelected,
            onChanged: (newValue) {
              setState(() {
                _teamPickerSelection[uid] = newValue ?? false;
              });
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Team Pickers - ${widget.groupName}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _buildMemberList()),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: _saveTeamPickers,
                    child: const Text("Save Team Pickers"),
                  ),
                )
              ],
            ),
    );
  }
}
