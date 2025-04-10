import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'album_details.dart';

enum AlbumMenuOption { view, create }

class AlbumsPage extends StatefulWidget {
  final String groupId; // The group to which these albums belong

  const AlbumsPage({Key? key, required this.groupId}) : super(key: key);

  @override
  _AlbumsPageState createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  AlbumMenuOption _selectedOption = AlbumMenuOption.view;

  // Albums list loaded from Firestore.
  List<Map<String, dynamic>> albums = [];

  // Firestore collection reference for albums.
  final CollectionReference _albumsCollection = FirebaseFirestore.instance.collection('albums');

  final TextEditingController _albumNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAlbums();
  }

  @override
  void dispose() {
    _albumNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchAlbums() async {
    try {
      QuerySnapshot snapshot = await _albumsCollection
          .where('group_id', isEqualTo: widget.groupId)
          .orderBy('created_at', descending: true)
          .get();
      List<Map<String, dynamic>> fetchedAlbums = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['name'] as String,
        };
      }).toList();
      setState(() {
        albums = fetchedAlbums;
      });
    } catch (e) {
      debugPrint("Error fetching albums: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching albums')),
      );
    }
  }

  void _handleMenuSelection(AlbumMenuOption option) {
    if (option == AlbumMenuOption.create) {
      _showCreateAlbumDialog();
    }
    // For AlbumMenuOption.view nothing special is needed as that is the default view.
    setState(() {
      _selectedOption = option;
    });
  }

  void _showCreateAlbumDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Album'),
          content: TextField(
            controller: _albumNameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Album Name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _albumNameController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final albumName = _albumNameController.text.trim();
                if (albumName.isNotEmpty) {
                  await _createAlbum(albumName);
                  _albumNameController.clear();
                  Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  // Create album by adding a document to Firestore, linked to the current group.
  Future<void> _createAlbum(String albumName) async {
    try {
      await _albumsCollection.add({
        'name': albumName,
        'group_id': widget.groupId, // Link album to this group.
        'created_at': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Album "$albumName" created.')));
      // Refresh album list.
      _fetchAlbums();
    } catch (e) {
      debugPrint("Error creating album: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create album.')),
      );
    }
  }

  Widget _buildAlbumsList() {
    if (albums.isEmpty) {
      return const Center(child: Text("No albums available"));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: albums.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final album = albums[index];
        return ListTile(
          leading: Icon(Icons.photo_album, color: Theme.of(context).primaryColor),
          title: Text(album['name']),
          onTap: () {
            // Navigate to AlbumDetailsPage passing album id and name.
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AlbumDetailsPage(
                  albumId: album['id'],
                  albumName: album['name'],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // A Scaffold with an AppBar that includes a 3-dot popup menu.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Albums'),
        actions: [
          PopupMenuButton<AlbumMenuOption>(
            onSelected: _handleMenuSelection,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<AlbumMenuOption>>[
              const PopupMenuItem<AlbumMenuOption>(
                value: AlbumMenuOption.view,
                child: Text('View Albums'),
              ),
              const PopupMenuItem<AlbumMenuOption>(
                value: AlbumMenuOption.create,
                child: Text('Create New Album'),
              ),
            ],
          ),
        ],
      ),
      body: _buildAlbumsList(),
    );
  }
}
