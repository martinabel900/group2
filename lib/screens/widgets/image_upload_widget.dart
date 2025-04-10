import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'services/image_upload_service.dart';

class ImageUploadWidget extends StatefulWidget {
  const ImageUploadWidget({Key? key}) : super(key: key);

  @override
  _ImageUploadWidgetState createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  final ImageUploadService _uploadService = ImageUploadService();
  File? _selectedImage;
  String? _downloadUrl;
  double _uploadProgress = 0.0;
  bool _isUploading = false;

  // Updated: First, we pick an image to get a reference locally,
  // then pass it to the upload service.
  Future<void> _pickAndUploadImage(ImageSource source) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _downloadUrl = null;
    });

    // Pick the image using ImagePicker.
    final XFile? pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) {
      setState(() {
        _isUploading = false;
      });
      return;
    }

    // Store the picked image locally for preview and sharing.
    _selectedImage = File(pickedFile.path);

    // Now, use your service to compress and upload.
    // Your service could use the picked file path, for example.
    String? url = await _uploadService.pickCompressAndUpload(
      source,
      storagePath: 'uploads', // Change storage path as needed.
      onProgress: (snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      },
    );

    if (url != null) {
      setState(() {
        _downloadUrl = url;
      });
    }

    setState(() {
      _isUploading = false;
    });
  }

  // Build a preview widget: either the selected file or the uploaded image from its URL.
  Widget _buildImagePreview() {
    if (_downloadUrl != null) {
      return Image.network(_downloadUrl!,
          height: 200, width: double.infinity, fit: BoxFit.cover);
    } else if (_selectedImage != null) {
      return Image.file(_selectedImage!,
          height: 200, width: double.infinity, fit: BoxFit.cover);
    } else {
      return Container(
        height: 200,
        width: double.infinity,
        color: Colors.grey[300],
        child: const Center(child: Text("No image selected")),
      );
    }
  }

  // Share the image using share_plus:
  Future<void> _shareImage() async {
    if (_selectedImage != null) {
      // Share the actual image file.
      await Share.shareXFiles([XFile(_selectedImage!.path)], text: 'Check out my image!');
    } else if (_downloadUrl != null) {
      // Fallback: share the download URL.
      await Share.share('Check out my image: $_downloadUrl');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No image to share.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildImagePreview(),
        const SizedBox(height: 10),
        if (_isUploading)
          LinearProgressIndicator(value: _uploadProgress),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text("Camera"),
              onPressed: () async {
                await _pickAndUploadImage(ImageSource.camera);
              },
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text("Gallery"),
              onPressed: () async {
                await _pickAndUploadImage(ImageSource.gallery);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_downloadUrl != null || _selectedImage != null)
          ElevatedButton.icon(
            icon: const Icon(Icons.share),
            label: const Text("Share"),
            onPressed: _shareImage,
          ),
        const SizedBox(height: 10),
        if (_downloadUrl != null)
          Text("Image uploaded successfully!\nURL: $_downloadUrl",
              textAlign: TextAlign.center),
      ],
    );
  }
}
