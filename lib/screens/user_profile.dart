import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'group_list.dart';  // Ensure this import points to your GroupListScreen

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final bool forcedUpdate; // if true, redirect after saving the profile

  const UserProfileScreen({
    Key? key, 
    required this.userId,
    this.forcedUpdate = false,
  }) : super(key: key);

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic> _userData = {};
  String? _profileImageUrl;
  
  final ImagePicker _picker = ImagePicker();

  // Getter that directly checks if the signed-in user's providerData includes "password"
  bool get showChangePassword {
    return _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ?? false;
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<String> _getMainAccountId(String userId) async {
    try {
      DocumentSnapshot linkDoc = await _firestore.collection('userLinks').doc(userId).get();
      if (linkDoc.exists) {
        final linkData = linkDoc.data() as Map<String, dynamic>;
        return linkData['mainAccountId'] as String;
      }
    } catch (e) {
      print("Error checking for linked account: $e");
    }
    return userId;
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the logged-in user's id instead of an external widget.userId if they differ.
      final String loggedInUserId = _auth.currentUser?.uid ?? widget.userId;
      if (widget.userId != loggedInUserId) {
        debugPrint("Warning: Provided widget.userId (${widget.userId}) does not match logged in user id ($loggedInUserId). Using logged in user id.");
      }
      final String mainAccountId = await _getMainAccountId(loggedInUserId);
      DocumentSnapshot doc = await _firestore.collection('users').doc(mainAccountId).get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        setState(() {
          _userData = data;
          _nameController.text = data['name'] ?? '';
          _emailController.text = data['email'] ?? '';
          _profileImageUrl = data['profileImage'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading user data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile == null) return;
    File file = File(pickedFile.path);

    setState(() {
      _isSaving = true;
    });
    
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child("user_images")
          .child("${_auth.currentUser?.uid}.jpg");
      UploadTask uploadTask = storageRef.putFile(file);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      final String mainAccountId = await _getMainAccountId(_auth.currentUser?.uid ?? widget.userId);
      await _firestore.collection('users').doc(mainAccountId).update({
        "profileImage": downloadUrl,
      });
      
      setState(() {
        _profileImageUrl = downloadUrl;
        _isSaving = false;
      });
    } catch (e) {
      print("Error uploading image: $e");
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final String currentUserId = _auth.currentUser?.uid ?? widget.userId;
      final String mainAccountId = await _getMainAccountId(currentUserId);
      
      await _firestore.collection('users').doc(mainAccountId).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await currentUser.updateDisplayName(_nameController.text.trim());
      }

      if (widget.forcedUpdate) {
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => GroupListScreen(
                userId: currentUserId,
                userName: _nameController.text.trim(),
              ),
            ),
          );
        });
      }
    } catch (e) {
      print("Error saving profile: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
  
  // New: Change Password functionality for email/password users.
  Future<void> _changePassword() async {
    TextEditingController newPasswordController = TextEditingController();
    TextEditingController confirmPasswordController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
              ),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm New Password'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // dismiss dialog
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                String newPassword = newPasswordController.text.trim();
                String confirmPassword = confirmPasswordController.text.trim();

                if (newPassword.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password cannot be empty')),
                  );
                  return;
                }

                if (newPassword != confirmPassword) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match')),
                  );
                  return;
                }
                try {
                  User? currentUser = _auth.currentUser;
                  if (currentUser != null) {
                    await currentUser.updatePassword(newPassword);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password updated successfully')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating password: $e')),
                  );
                }
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildStatisticsCard() {
    String lastPlayedStr = "N/A";
    String timesPlayedStr = "N/A";
    String rankingStr = "N/A";

    if (_userData.isNotEmpty) {
      if (_userData.containsKey('lastPlayed') && _userData['lastPlayed'] != null) {
        Timestamp ts = _userData['lastPlayed'];
        lastPlayedStr = DateFormat.yMMMd().format(ts.toDate());
      }
      if (_userData.containsKey('timesPlayed')) {
        timesPlayedStr = _userData['timesPlayed'].toString();
      }
      if (_userData.containsKey('ranking')) {
        rankingStr = _userData['ranking'].toString();
      }
    }
    
    String loginMethod = _auth.currentUser?.providerData.map((p) => p.providerId).join(', ') ?? "Unknown";
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Profile Statistics", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text("Last Played:", style: Theme.of(context).textTheme.bodyMedium),
                ),
                Expanded(
                  flex: 4,
                  child: Text(lastPlayedStr,
                      style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.right),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text("Times Played (This Year):", style: Theme.of(context).textTheme.bodyMedium),
                ),
                Expanded(
                  flex: 4,
                  child: Text(timesPlayedStr,
                      style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.right),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text("Ranking:", style: Theme.of(context).textTheme.bodyMedium),
                ),
                Expanded(
                  flex: 4,
                  child: Text(rankingStr,
                      style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.right),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text("Login Method:", style: Theme.of(context).textTheme.bodyMedium),
                ),
                Expanded(
                  flex: 4,
                  child: Text(loginMethod,
                      style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.right),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.forcedUpdate ? 'Update Profile' : 'User Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: _profileImageUrl != null
                                ? CachedNetworkImageProvider(_profileImageUrl!)
                                : null,
                            child: _profileImageUrl == null
                                ? Text(
                                    _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          if (_isSaving)
                            const Positioned(
                              child: CircularProgressIndicator(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  // Display the change password option if the user authenticates via email/password.
                  if (showChangePassword) ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _changePassword,
                      child: const Text('Change Password'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _buildStatisticsCard(),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    child: const Text('Save Profile'),
                  ),
                ],
              ),
            ),
    );
  }
}
