import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'group_list.dart';

/// A screen that allows the user to create a new group.
class AddGroupScreen extends StatefulWidget {
  const AddGroupScreen({Key? key}) : super(key: key);

  @override
  _AddGroupScreenState createState() => _AddGroupScreenState();
}

class _AddGroupScreenState extends State<AddGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupFunctionController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;

  /// Creates a new group document in Firestore with the provided name and function,
  /// and then navigates back to the Group List screen.
  Future<void> _createGroup() async {
    final String groupName = _groupNameController.text.trim();
    final String groupFunction = _groupFunctionController.text.trim();

    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Group name cannot be empty")),
      );
      return;
    }
    
    // Get the current logged in user.
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in")),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      // When creating a group, add the user's UID automatically as a member and admin.
      DocumentReference groupRef = await _firestore.collection('groups').add({
        'name': groupName,
        'function': groupFunction,
        'members': [user.uid],
        'admins': [user.uid],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Navigate back to the Group List screen.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GroupListScreen(
            userId: user.uid,
            userName: user.email ?? 'User',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error creating group: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupFunctionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create New Group"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _groupNameController,
              decoration: const InputDecoration(
                labelText: "Group Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _groupFunctionController,
              decoration: const InputDecoration(
                labelText: "Group Function (e.g., Football, Tennis, Cricket)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _createGroup,
                    child: const Text("Create Group"),
                  ),
          ],
        ),
      ),
    );
  }
}