import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scanned_item.dart'; // Import the ScannedItem model

// Provider for the FirestoreService
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  // Get the current user's UID safely
  final firebaseAuth = ref.watch(firebaseAuthProvider); // Assuming you have a provider for FirebaseAuth
  final user = firebaseAuth.currentUser;

  if (user == null) {
    // Handle the case where the user is not logged in.
    // You might throw an error or return a service that handles this state.
    // For now, let's throw an error, assuming the UI prevents access when logged out.
    throw Exception('User not logged in. Cannot access FirestoreService.');
  }
  return FirestoreService(user.uid);
});

// Provider for FirebaseAuth instance (if not already defined elsewhere)
// You might already have this in another file (e.g., auth_providers.dart)
// If so, remove this and import the existing one.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);


class FirestoreService {
  final String userId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  FirestoreService(this.userId);

  // Collection reference for the user's lists
  CollectionReference get _listsCollection =>
      _db.collection('users').doc(userId).collection('lists');

  // Save the current list of items and total to Firestore
  Future<void> saveList(List<ScannedItem> items, int totalCents) async {
    if (userId.isEmpty) {
      throw Exception("User ID is required to save list.");
    }
    if (items.isEmpty) {
      throw Exception("Cannot save an empty list.");
    }

    final timestamp = FieldValue.serverTimestamp(); // Use server timestamp
    final listData = {
      'items': items.map((item) => item.toJson()).toList(), // Convert items to JSON
      'totalCents': totalCents,
      'createdAt': timestamp,
    };

    try {
      await _listsCollection.add(listData); // Add as a new document with auto-generated ID
    } catch (e) {
      // Log error or handle it appropriately
      print("Error saving list to Firestore: $e");
      throw Exception("Failed to save list. Please try again.");
    }
  }

  // Get a stream of saved lists for the current user, ordered by creation time
  Stream<QuerySnapshot> getSavedLists() {
    if (userId.isEmpty) {
      // Return an empty stream or throw if user ID is missing
      return const Stream.empty();
    }
    return _listsCollection
        .orderBy('createdAt', descending: true) // Order by newest first
        .snapshots();
  }

  // Delete a specific list document by its ID
  Future<void> deleteList(String listId) async {
    if (userId.isEmpty) {
      throw Exception("User ID is required to delete list.");
    }
    if (listId.isEmpty) {
      throw Exception("List ID is required to delete list.");
    }

    try {
      await _listsCollection.doc(listId).delete();
    } catch (e) {
      // Log error or handle it appropriately
      print("Error deleting list from Firestore: $e");
      throw Exception("Failed to delete list. Please try again.");
    }
  }
}
