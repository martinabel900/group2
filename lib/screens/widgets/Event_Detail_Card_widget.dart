import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A widget that displays event details using a custom expansion layout.
///
/// In the collapsed state:
///   • Row 1: Title (left) and on the far right, Players count and a 3‑dot popup menu.
///   • Row 2: For admins, an “Add Guest” button on the left; on the far right, an expansion toggle arrow.
/// In the expanded state, the card shows Date & Time and Venue.
///
/// Note: When filtering an event's active state, if the event document doesn’t have an "active" field,
/// it is treated as active.
class EventDetailCardWidget extends StatefulWidget {
  final String eventId;
  final String groupId;
  final bool isAdmin; // Only admins get extra actions

  const EventDetailCardWidget({
    Key? key,
    required this.eventId,
    required this.groupId,
    this.isAdmin = false,
  }) : super(key: key);

  @override
  _EventDetailCardWidgetState createState() => _EventDetailCardWidgetState();
}

class _EventDetailCardWidgetState extends State<EventDetailCardWidget> {
  bool _isExpanded = false;

  // Method to add a guest player.
  Future<void> _addGuest() async {
    final TextEditingController guestNameController = TextEditingController();
    final String? guestName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Guest Player"),
        content: TextField(
          controller: guestNameController,
          decoration: const InputDecoration(
            hintText: "Enter guest name",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(guestNameController.text.trim()),
            child: const Text("Add"),
          ),
        ],
      ),
    );

    if (guestName != null && guestName.isNotEmpty) {
      String guestId = "GUEST_${DateTime.now().millisecondsSinceEpoch}";
      Map<String, dynamic> newGuest = {
        "id": guestId,
        "name": guestName,
        "isGuest": true,
        "imageUrl": "https://example.com/default_guest_image.png"
      };

      await FirebaseFirestore.instance.collection('events').doc(widget.eventId).update({
        'players': FieldValue.arrayUnion([newGuest])
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guest added successfully')),
      );
    }
  }

  // Handler for popup actions.
  void _handlePopupMenuAction(String value) async {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    switch (value) {
      case 'add_me':
        if (currentUserId != null) {
          await FirebaseFirestore.instance.collection('events').doc(widget.eventId).update({
            'players': FieldValue.arrayUnion([currentUserId])
          });
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Added you as a player')));
        }
        break;
      case 'let_down':
        if (currentUserId != null) {
          await FirebaseFirestore.instance.collection('events').doc(widget.eventId).update({
            'players': FieldValue.arrayRemove([currentUserId])
          });
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Removed you from players')));
        }
        break;
      case 'team_list':
        Navigator.pushNamed(context, '/teamList', arguments: {
          'eventId': widget.eventId,
          'groupId': widget.groupId,
        });
        break;
      case 'remove_event':
        // Instead of deleting, mark the event as dormant.
        await FirebaseFirestore.instance.collection('events').doc(widget.eventId).update({'active': false});
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Event marked dormant')));
        break;
      default:
        break;
    }
  }

  // Toggle the expansion state.
  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  // Build the custom header.
  Widget _buildHeader(String title, int playersCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First row: Title (left) and on the far right, Players count and popup menu.
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
            ),
            Text(
              'Players: $playersCount',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: _handlePopupMenuAction,
              itemBuilder: (context) {
                return [
                  const PopupMenuItem<String>(value: 'add_me', child: Text('Add Me')),
                  const PopupMenuItem<String>(value: 'let_down', child: Text('Let Down')),
                  const PopupMenuItem<String>(value: 'team_list', child: Text('Team List')),
                  const PopupMenuItem<String>(value: 'remove_event', child: Text('Remove Event')),
                ];
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Second row: If admin, show Add Guest button on the left; on the far right, the expansion toggle arrow.
        Row(
          children: [
            if (widget.isAdmin)
              TextButton.icon(
                onPressed: _addGuest,
                icon: const Icon(Icons.person_add, color: Colors.white),
                label: const Text("Add Guest", style: TextStyle(color: Colors.white)),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            const Spacer(),
            IconButton(
              icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white),
              onPressed: _toggleExpansion,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('events').doc(widget.eventId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Event not found'));
        }
        final eventData = snapshot.data!.data() as Map<String, dynamic>;
        // Updated active filter: only hide the event if "active" exists and is explicitly false.
        if (eventData.containsKey('active') && eventData['active'] == false) return Container();
        final String title = eventData['title'] ?? 'No Title';
        final String venue = eventData['venue'] ?? 'No Venue';
        final List<dynamic> playersList = eventData['players'] is List ? (eventData['players'] as List) : [];
        final int playersCount = playersList.length;

        // Process date and time.
        DateTime dt;
        if (eventData['datetime'] is Timestamp) {
          dt = (eventData['datetime'] as Timestamp).toDate();
        } else if (eventData['datetime'] is DateTime) {
          dt = eventData['datetime'];
        } else if (eventData['datetime'] is String) {
          dt = DateTime.tryParse(eventData['datetime']) ?? DateTime.now();
        } else {
          dt = DateTime.now();
        }
        final String formattedDate = DateFormat('EEE, MMM d, yyyy hh:mm a').format(dt);

        return Card(
          color: Colors.blueGrey[400],
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: InkWell(
            onTap: _toggleExpansion,
            borderRadius: BorderRadius.circular(8),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _buildHeader(title, playersCount),
                ),
                if (_isExpanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Date & Time: $formattedDate", style: const TextStyle(fontSize: 14, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text("Venue: $venue", style: const TextStyle(fontSize: 14, color: Colors.white70)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
