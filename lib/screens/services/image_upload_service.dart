
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class ImageUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Selects an image using the camera or gallery.
  Future<File?> pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        // Explicitly convert the XFile to a File.
        final File imageFile = File(pickedFile.path);
        return imageFile;
      }
    } catch (e) {
      print("Error picking image: $e");
    }
    return null;
  }

  // Compress the image to reduce file size.
  Future<File?> compressImage(File file, {int quality = 85}) async {
    try {
      final String targetPath = path.join(
          path.dirname(file.path), "temp_${path.basename(file.path)}");
      final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
      );
      return compressedXFile != null ? File(compressedXFile.path) : null;
    } catch (e) {
      print("Error compressing image: $e");
    }
    return null;
  }

  // Uploads the image file to Firebase Storage.
  // Returns the download URL upon successful upload.
  Future<String?> uploadImage(File file, String storagePath,
      {void Function(TaskSnapshot snapshot)? onProgress}) async {
    try {
      final fileName = path.basename(file.path);
      final Reference ref = _storage.ref().child("$storagePath/$fileName");
      final UploadTask uploadTask = ref.putFile(file);

      // Listen for progress updates if callback is provided.
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (onProgress != null) {
          onProgress(snapshot);
        }
      });

      await uploadTask;
      return await ref.getDownloadURL();
    } catch (e) {
      print("Error uploading image: $e");
    }
    return null;
  }

  // A convenience method that picks, compresses, and uploads an image.
  // Returns the final download URL if successful.
  Future<String?> pickCompressAndUpload(
    ImageSource source, {
    required String storagePath,
    void Function(TaskSnapshot snapshot)? onProgress,
    int quality = 85,
  }) async {
    File? pickedImage = await pickImage(source);
    if (pickedImage == null) return null;

    File? compressedImage = await compressImage(pickedImage, quality: quality);
    if (compressedImage == null) return null;

    return await uploadImage(compressedImage, storagePath, onProgress: onProgress);
  }
}
