/// A widget for displaying a user's profile picture.
/// When tapped, it allows the user to pick an image from the gallery.
/// This widget can be used on the profile page and group chat screen.
class ProfileWidget extends StatefulWidget {
  final double size;
  final String? imageUrl;

  const ProfileWidget({Key? key, this.size = 80.0, this.imageUrl}) : super(key: key);

  @override
  _ProfileWidgetState createState() => _ProfileWidgetState();
}

class _ProfileWidgetState extends State<ProfileWidget> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  /// Allows the user to pick an image from the gallery.
  /// In a complete implementation, the image should be uploaded to Firebase Storage
  /// and the profile URL updated accordingly.
  Future<void> _pickImage() async {
    try {
      final XFile? imageFile = await _picker.pickImage(source: ImageSource.gallery);
      if (imageFile != null) {
        setState(() {
          _profileImage = File(imageFile.path);
        });
        // Here you can call your upload function to update the image on Firestore/Firebase Storage.
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick image'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pickImage,
      child: CircleAvatar(
        radius: widget.size / 2,
        backgroundColor: Colors.grey[700],
        backgroundImage: _profileImage != null
            ? FileImage(_profileImage!)
            : widget.imageUrl != null
                ? NetworkImage(widget.imageUrl!) as ImageProvider
                : null,
        child: _profileImage == null && widget.imageUrl == null
            ? Icon(
                Icons.camera_alt,
                size: widget.size / 2,
                color: Colors.white,
              )
            : null,
      ),
    );
  }
}