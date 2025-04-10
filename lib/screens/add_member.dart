import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddMemberScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const AddMemberScreen({required this.groupId, required this.groupName, Key? key}) : super(key: key);

  @override
  _AddMemberScreenState createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final TextEditingController _emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // To store the user data fetched from Firestore
  DocumentSnapshot? _userSnapshot;

  // Search for the user by email
  Future<void> _searchUserByEmail() async {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      _showDialog('Please enter a valid email address.');
      return;
    }

    try {
      // Search for user by email
      QuerySnapshot userSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (userSnapshot.docs.isEmpty) {
        _showDialog('No user found with this email address.');
        return;
      }

      // Get the user data
      _userSnapshot = userSnapshot.docs.first;
      setState(() {});
    } catch (e) {
      _showDialog('Error searching user: $e');
    }
  }

  // Add player to the group
  Future<void> _addPlayerToGroup() async {
    if (_userSnapshot == null) {
      _showDialog('Please search for a user first.');
      return;
    }

    String userId = _userSnapshot!.id;

    try {
      DocumentReference groupRef = _firestore.collection('groups').doc(widget.groupId);
      await groupRef.update({
        'members': FieldValue.arrayUnion([userId]),
      });

      _showDialog(
        'Player added to the group successfully!',
        onOk: () {
          // After the dialog is dismissed, pop the current screen and return to the Group Chat page
          Navigator.pop(context);
        },
      );
    } catch (e) {
      _showDialog('Error adding player: $e');
    }
  }

  // Show dialog for feedback with an optional callback on OK press
  void _showDialog(String message, {VoidCallback? onOk}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Player'),
          content: Text(message),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.pop(context); // Dismiss the dialog
                if (onOk != null) {
                  onOk();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Player to Group'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the player\'s email to add them to the group:',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Player\'s Email',
                hintText: 'Enter the player\'s email',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _searchUserByEmail,
              child: Text('Search User'),
            ),
            SizedBox(height: 20),
            if (_userSnapshot != null) 
              Column(
                children: [
                  // Display the user's info once found
                  ListTile(
                    title: Text(_userSnapshot!['name'] ?? 'Unknown'),
                    subtitle: Text(_userSnapshot!['email']),
                    leading: Icon(Icons.person),
                  ),
                  SizedBox(height: 10),
                  // Show the "Plus" icon to add user to the group
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, size: 40, color: Colors.blue),
                    onPressed: _addPlayerToGroup,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}