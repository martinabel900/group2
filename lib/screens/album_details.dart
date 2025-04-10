import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'full_screen_image.dart';

class AlbumDetailsPage extends StatefulWidget {
  final String albumId;
  final String albumName;
  const AlbumDetailsPage({Key? key, required this.albumId, required this.albumName}) : super(key: key);

  @override
  _AlbumDetailsPageState createState() => _AlbumDetailsPageState();
}

class _AlbumDetailsPageState extends State<AlbumDetailsPage> {
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;

  // Upload an image to Firebase Storage and record metadata in Firestore.
  Future<void> _pickAndUploadImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;
    
    setState(() {
      _uploading = true;
    });
    
    File imageFile = File(pickedFile.path);
    String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    Reference storageRef = FirebaseStorage.instance.ref().child('albums/${widget.albumId}/$fileName');

    try {
      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Add the URL to the album's "images" subcollection.
      await FirebaseFirestore.instance
          .collection('albums')
          .doc(widget.albumId)
          .collection('images')
          .add({
        'imageUrl': downloadUrl,
        'uploaded_at': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully')),
      );
    } catch (e) {
      debugPrint('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload image')),
      );
    } finally {
      setState(() {
        _uploading = false;
      });
    }
  }

  // Show a dialog to choose the image source.
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Image Source"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pickAndUploadImage(ImageSource.camera);
            },
            child: const Text("Camera"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pickAndUploadImage(ImageSource.gallery);
            },
            child: const Text("Gallery"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('albums')
          .doc(widget.albumId)
          .collection('images')
          .orderBy('uploaded_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading images"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data?.docs.isEmpty ?? true) {
          return const Center(child: Text("No images uploaded yet"));
        }
        final imagesDocs = snapshot.data!.docs;
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: imagesDocs.length,
          itemBuilder: (context, index) {
            final data = imagesDocs[index].data() as Map<String, dynamic>;
            final imageUrl = data['imageUrl'] as String? ?? '';

            return Hero(
              tag: imageUrl,
              child: Material(
                color: Colors.transparent, // Provide a transparent material wrapper.
                child: InkWell(
                  onTap: () {
                    // Navigate to full screen view.
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FullScreenImagePage(imageUrl: imageUrl),
                      ),
                    );
                  },
                  onLongPress: () {
                    // Share the image URL using share_plus.
                    Share.share(imageUrl);
                  },
                  child: Image.network(imageUrl, fit: BoxFit.cover),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.albumName),
      ),
      body: Stack(
        children: [
          _buildImagesGrid(),
          if (_uploading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showImageSourceDialog,
        tooltip: 'Upload Image',
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}
