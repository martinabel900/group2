import 'package:flutter/material.dart';

/// A simple model representing a guest player.
class GuestPlayer {
  final String id;
  final String name;
  final String imageUrl;

  const GuestPlayer({
    required this.id,
    required this.name,
    this.imageUrl = '',
  });
}

/// A widget that displays a list of guest players and includes controls to add or remove guests.
class GuestPlayerControl extends StatelessWidget {
  final List<GuestPlayer> guestPlayers;
  final VoidCallback onAddGuest;
  final void Function(String guestId) onRemoveGuest;

  const GuestPlayerControl({
    Key? key,
    required this.guestPlayers,
    required this.onAddGuest,
    required this.onRemoveGuest,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Guest Players", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...guestPlayers.map((guest) => ListTile(
                  leading: CircleAvatar(
                    backgroundImage: guest.imageUrl.isNotEmpty
                        ? NetworkImage(guest.imageUrl)
                        : null,
                    child: guest.imageUrl.isEmpty
                        ? Text(guest.name[0].toUpperCase())
                        : null,
                  ),
                  title: Text(guest.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => onRemoveGuest(guest.id),
                  ),
                )),
            const SizedBox(height: 8),
            Center(
              child: ElevatedButton(
                onPressed: onAddGuest,
                child: const Text("Add Guest Player"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}