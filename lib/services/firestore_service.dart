import 'dart:async'; // For Completer if needed for compute error handling
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Import for compute
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
  // Pass the Firestore instance to avoid re-initializing in compute if possible,
  // though compute often requires top-level initialization.
  return FirestoreService(user.uid, FirebaseFirestore.instance);
});

// Provider for FirebaseAuth instance (if not already defined elsewhere)
// You might already have this in another file (e.g., auth_providers.dart)
// If so, remove this and import the existing one.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);


// Top-level function for background isolate execution
// Note: Firebase needs to be initialized for this isolate.
// This usually happens if Firebase.initializeApp() is called in main().
Future<void> _saveListBackground(Map<String, dynamic> data) async {
  final String userId = data['userId'];
  final String title = data['title'];
  final List<Map<String, dynamic>> itemsJson = data['itemsJson'];
  final int totalCents = data['totalCents'];
  final int subtotalCents = data['subtotalCents'];

  // Re-get Firestore instance within the isolate if needed, or ensure initialized
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final CollectionReference listsCollection =
      db.collection('users').doc(userId).collection('lists');

  final listData = {
    'title': title,
    'items': itemsJson, // Use pre-serialized items
    'total_cents': totalCents,
    'subtotal_cents': subtotalCents,
    'timestamp': FieldValue.serverTimestamp(),
    'userId': userId,
  };

  // The actual Firestore operation
  await listsCollection.add(listData);
}


class FirestoreService {
  final String userId;
  final FirebaseFirestore _db; // Use injected instance

  FirestoreService(this.userId, this._db); // Inject Firestore instance

  // Collection reference for the user's lists
  CollectionReference get _listsCollection =>
      _db.collection('users').doc(userId).collection('lists');

  // Save the current list of items, total, subtotal, and title to Firestore
  Future<void> saveList({
      required String title, // Add title parameter
      required List<ScannedItem> items,
      required int totalCents,
      required int subtotalCents,
  }) async {
    if (userId.isEmpty) {
      throw Exception("User ID is required to save list.");
    }
    if (items.isEmpty) {
      throw Exception("Cannot save an empty list.");
    }

    // --- Perform serialization on the main thread (usually fast) ---
    final List<Map<String, dynamic>> itemsJson =
        items.map((item) => item.toJson()).toList();

    // --- Prepare data for the background isolate ---
    final Map<String, dynamic> computeData = {
      'userId': userId,
      'title': title,
      'itemsJson': itemsJson, // Pass serialized data
      'totalCents': totalCents,
      'subtotalCents': subtotalCents,
    };

    try {
      // --- Execute Firestore operation in background isolate ---
      // compute() takes a top-level function and its argument.
      // It returns a Future that completes when the background task is done.
      await compute(_saveListBackground, computeData);

    } catch (e) {
      // Log error or handle it appropriately
      // Errors from the compute function might need specific handling
      print("Error saving list via compute: $e");
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
