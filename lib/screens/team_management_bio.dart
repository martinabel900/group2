
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeamManagementBio extends StatefulWidget {
  final String eventId;
  final String groupId;
  final String groupName;
  final String access; // e.g., 'teamPicker' or other access level

  const TeamManagementBio({
    Key? key,
    required this.eventId,
    required this.groupId,
    required this.groupName,
    required this.access,
  }) : super(key: key);

  @override
  _TeamManagementBioState createState() => _TeamManagementBioState();
}

class _TeamManagementBioState extends State<TeamManagementBio> {
  bool _isLoading = true;
  String _error = '';
  Map<String, dynamic>? _eventData;

  @override
  void initState() {
    super.initState();
    // Listen to auth state changes.
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        // In team picker mode with a default event id, try to fetch an active event id.
        if (widget.eventId == "default_event" && widget.access == "teamPicker") {
          await _fetchActiveEventAndNavigate();
        } else {
          // Otherwise fetch event data as usual.
          await _fetchEventData();
          _navigateToTeamManagement(widget.eventId);
        }
      } else {
        // If not authenticated, remain on this screen and display an error.
        setState(() {
          _isLoading = false;
          _error = "User not authenticated. Please sign in.";
        });
      }
    });
  }

  // Fetch the specified event data.
  Future<void> _fetchEventData() async {
    try {
      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();
      if (eventDoc.exists) {
        _eventData = eventDoc.data() as Map<String, dynamic>;
      } else {
        _error = 'Event document does not exist.';
      }
    } catch (e) {
      _error = e.toString();
    }
  }

  // For team picker mode: look for an active event for the given group.
  Future<void> _fetchActiveEventAndNavigate() async {
    try {
      // Query events by groupId.
      final querySnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('groupId', isEqualTo: widget.groupId)
          .limit(10)
          .get();

      // Filter events client side:
      // If the "active" field is either not present or true, consider it active.
      final activeDocs = querySnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return !data.containsKey('active') || (data['active'] == true);
      }).toList();

      if (activeDocs.isNotEmpty) {
        final activeEventDoc = activeDocs.first;
        _eventData = activeEventDoc.data();
        String validEventId = activeEventDoc.id;
        _navigateToTeamManagement(validEventId);
      } else {
        setState(() {
          _error = 'No active event found for your group.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching active event: $e';
        _isLoading = false;
      });
    }
  }

  void _navigateToTeamManagement(String eventIdToUse) {
    // Delay navigation to ensure the build context is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(
        context,
        '/teamManagement',
        arguments: {
          'eventId': eventIdToUse,   // Pass a valid eventId.
          'eventData': _eventData,   // Optionally pass the event data.
          'groupId': widget.groupId,
          'groupName': widget.groupName,
          'access': widget.access,
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Team Management"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : const Center(
                  child: Text("Preparing your team management experience..."),
                ),
    );
  }
}
