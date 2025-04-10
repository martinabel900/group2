
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'event_detail_card_widget.dart';

class EventListWidget extends StatelessWidget {
  final String groupId;
  final bool isAdmin;

  const EventListWidget({Key? key, required this.groupId, required this.isAdmin}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    debugPrint("EventListWidget: using groupId = $groupId");
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('groupId', isEqualTo: groupId)
          // Removed: .where('active', isEqualTo: true)
          .orderBy('datetime', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint("Error fetching events: ${snapshot.error}");
          return Center(child: Text("Error loading events: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return Center(child: Text("No events found for groupId: $groupId"));
        }

        // Filter events on the client side: if 'active' exists and is false, omit that event.
        final events = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // If there exists an 'active' field and it is false, filter it out.
          if (data.containsKey('active') && data['active'] == false) {
            return false;
          }
          return true; // Otherwise, treat event as active.
        }).toList();

        if (events.isEmpty) {
          debugPrint("❌ No events found for groupId: $groupId after filtering by active status");
          return Center(
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/event', arguments: {'groupId': groupId});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "No events created yet. Tap here to create one.",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          );
        }
        debugPrint("✅ Found ${events.length} active events");

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index].data() as Map<String, dynamic>;
            final eventId = events[index].id;
            final eventTitle = event['title'] ?? "No Title";
            debugPrint("Event $index: ID = $eventId, Title = $eventTitle, Data = ${events[index].data()}");

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: EventDetailCardWidget(
                eventId: eventId,
                groupId: groupId,
                isAdmin: isAdmin,
              ),
            );
          },
        );
      },
    );
  }
}
