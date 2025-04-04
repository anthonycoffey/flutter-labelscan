import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ListProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Method to save a list to Firestore
  Future<void> saveList({
    required String title,
    required List<Map<String, dynamic>> items,
    required Timestamp timestamp,
    required int totalCents,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    // Reference to the user's 'saved_lists' subcollection
    final CollectionReference listsCollection = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('lists');

    try {
      // Add a new document with a generated ID
      await listsCollection.add({
        'title': title, // Add the title field
        'items': items, // Store the original list of maps
        'timestamp': timestamp,
        'total_cents': totalCents,
        'userId': user.uid, // Optional: store userId for potential queries
      });
      // Optionally notify listeners if the state needs to update elsewhere
      // notifyListeners();
    } catch (e) {
      print("Error saving list to Firestore: $e");
      // Re-throw the error to be caught in the UI layer
      throw Exception("Failed to save list: $e");
    }
  }

  // Add other methods for fetching, deleting lists etc. as needed
}
