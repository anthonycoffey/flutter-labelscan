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

  // Save the current list of items, total, subtotal, and title to Firestore
  Future<void> saveList({
      required String title, // Add title parameter
      required List<ScannedItem> items,
      required int totalCents,
      required int subtotalCents, // Add subtotal parameter
  }) async {
    if (userId.isEmpty) {
      throw Exception("User ID is required to save list.");
    }
    if (items.isEmpty) {
      throw Exception("Cannot save an empty list.");
    }

    // Use the correct field names consistent with ListProvider and SavedListsScreen
    final listData = {
      'title': title, // Add the title field
      'items': items.map((item) => item.toJson()).toList(), // Convert items to JSON
      'total_cents': totalCents, // Use 'total_cents'
      'subtotal_cents': subtotalCents, // Add subtotal_cents field
      'timestamp': FieldValue.serverTimestamp(), // Use 'timestamp' and server value
      'userId': userId, // Optional: store userId
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
        .orderBy('timestamp', descending: true) // Order by 'timestamp' field
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

  // Delete all list documents for the current user
  Future<void> deleteAllLists() async {
    if (userId.isEmpty) {
      throw Exception("User ID is required to delete all lists.");
    }

    try {
      // Get all documents in the user's lists collection
      final querySnapshot = await _listsCollection.get();

      if (querySnapshot.docs.isEmpty) {
        // No lists to delete
        return;
      }

      // Create a batch write operation
      final batch = _db.batch();

      // Add each document deletion to the batch
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Commit the batch write
      await batch.commit();
    } catch (e) {
      // Log error or handle it appropriately
      print("Error deleting all lists from Firestore: $e");
      throw Exception("Failed to delete all lists. Please try again.");
    }
  }
}
