import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Returns stream of groups where the user is a member using linked account logic.
  Stream<QuerySnapshot> getUserGroupsStream() async* {
    final query = await getUserGroupsQuery();
    yield* query.snapshots();
  }
  
  /// Gets a query for the user's groups.
  Future<Query> getUserGroupsQuery() async {
    final mainAccountId = await _authService.getMainAccountId();
    if (mainAccountId == null) {
      throw Exception("User not authenticated");
    }
    debugPrint("Querying groups for user ID: $mainAccountId");
    // Assumes group documents store membership in a map: { "<userId>": true }
    return _firestore.collection('groups')
        .where('members.$mainAccountId', isEqualTo: true);
  }
  
  /// Gets all groups the user is a member of.
  Future<QuerySnapshot> getUserGroups() async {
    final query = await getUserGroupsQuery();
    return query.get();
  }
  
  /// Creates a new document in a collection.
  Future<DocumentReference> createDocument(
    String collection, 
    Map<String, dynamic> data
  ) async {
    final mainAccountId = await _authService.getMainAccountId();
    
    // If creating a group, ensure the owner and membership is properly set.
    if (collection == 'groups') {
      data['ownerId'] = mainAccountId;
      if (!data.containsKey('members')) {
        data['members'] = {};
      }
      data['members'][mainAccountId] = true;
    }
    
    return _firestore.collection(collection).add(data);
  }
  
  /// Updates an existing document.
  Future<void> updateDocument(
    String collection, 
    String documentId, 
    Map<String, dynamic> data
  ) async {
    return _firestore.collection(collection).doc(documentId).update(data);
  }
  
  /// Deletes a document.
  Future<void> deleteDocument(String collection, String documentId) async {
    return _firestore.collection(collection).doc(documentId).delete();
  }
  
  /// Checks if the user is a member of any group, and adds them to a default group if necessary.
  Future<void> joinDefaultGroupIfNeeded() async {
    final mainAccountId = await _authService.getMainAccountId();
    if (mainAccountId == null) throw Exception("User not authenticated");
    
    final currentGroupsSnapshot = await getUserGroups();
    
    if (currentGroupsSnapshot.docs.isEmpty) {
      const defaultGroupId = "general_group";
      final defaultGroupRef = _firestore.collection('groups').doc(defaultGroupId);
      
      // Check if a default group already exists
      final defaultGroupSnapshot = await defaultGroupRef.get();
      
      if (defaultGroupSnapshot.exists) {
        // Update the existing default group to include the new member.
        await defaultGroupRef.set({
          'members': { mainAccountId: true }
        }, SetOptions(merge: true));
        debugPrint("Added user $mainAccountId to existing default group.");
      } else {
        // Create a new default group document.
        await defaultGroupRef.set({
          'name': 'General',
          'ownerId': mainAccountId,
          'members': { mainAccountId: true },
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint("Created default group and added user $mainAccountId.");
      }
    } else {
      debugPrint("User $mainAccountId is already a member of one or more groups.");
    }
  }
}