import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart'; // For swipe-to-delete
import 'package:intl/intl.dart'; // For date and currency formatting

import '../services/firestore_service.dart'; // Import the service
import 'list_details_screen.dart'; // Import the new details screen

// Provider to stream the saved lists
final savedListsStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  // Watch the Firestore service provider
  // This will automatically re-run if the user logs in/out,
  // causing the FirestoreService instance to change (due to user ID change).
  try {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.getSavedLists();
  } catch (e) {
    // Handle cases where FirestoreService provider throws (e.g., user not logged in)
    print("Error accessing FirestoreService in StreamProvider: $e");
    return Stream.error(e); // Propagate the error to the stream
  }
});

class SavedListsScreen extends ConsumerWidget {
  const SavedListsScreen({super.key});

  // Helper to format cents to currency string
  String _formatCents(int cents) {
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    return currencyFormat.format(cents / 100.0);
  }

  // Helper to format Timestamp to a readable date/time string
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown date';
    // Example format: "Apr 2, 2025, 9:15 PM"
    return DateFormat('MMM d, yyyy, h:mm a').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedListsAsyncValue = ref.watch(savedListsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Lists'),
      ),
      body: savedListsAsyncValue.when(
        data: (querySnapshot) {
          if (querySnapshot.docs.isEmpty) {
            return const Center(child: Text('No saved lists yet.'));
          }

          // Build the list view
          return ListView.builder(
            itemCount: querySnapshot.docs.length,
            itemBuilder: (context, index) {
              final doc = querySnapshot.docs[index];
              final data = doc.data() as Map<String, dynamic>?; // Cast data
              final listId = doc.id; // Get the document ID for deletion

              // Safely access data with null checks and defaults
              final title = data?['title'] as String? ?? 'Untitled List'; // Get the title
              final totalCents = data?['total_cents'] as int? ?? 0; // Corrected field name
              final timestamp = data?['timestamp'] as Timestamp?; // Corrected field name
              final itemsList = data?['items'] as List<dynamic>? ?? [];
              final itemCount = itemsList.length;
              // Ensure itemsList is correctly typed for navigation
              final List<Map<String, dynamic>> typedItemsList = List<Map<String, dynamic>>.from(itemsList);


              return Slidable(
                key: ValueKey(listId), // Unique key for Slidable
                // Add Start Action Pane for "View"
                startActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (context) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ListDetailsScreen(
                              title: title, // Pass the title
                              items: typedItemsList, // Pass the correctly typed list
                              timestamp: timestamp,
                              totalCents: totalCents,
                            ),
                          ),
                        );
                      },
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      icon: Icons.visibility,
                      label: 'View',
                    ),
                  ],
                ),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  dismissible: DismissiblePane(onDismissed: () {
                    // Call delete method when dismissed
                    _deleteList(context, ref, listId);
                  }),
                  children: [
                    SlidableAction(
                      onPressed: (context) => _deleteList(context, ref, listId),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: 'Delete',
                    ),
                  ],
                ),
                child: ListTile(
                  title: Text(title), // Display the title
                  subtitle: Text('$itemCount items - ${_formatTimestamp(timestamp)}'), // Combine count and date
                  trailing: Text(
                    _formatCents(totalCents),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // Optional: Add onTap to view list details later
                  // onTap: () { /* Navigate to a detail view? */ },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          print("Error in SavedListsScreen stream: $error"); // Log the error
          // Check if the error is due to user not being logged in
          if (error.toString().contains('User not logged in')) {
             return const Center(child: Text('Please log in to view saved lists.'));
          }
          return Center(child: Text('Error loading lists: ${error.toString()}'));
        },
      ),
    );
  }

  // Helper method to call delete and show feedback
  void _deleteList(BuildContext context, WidgetRef ref, String listId) async {
    try {
      // Access the service directly for the action
      await ref.read(firestoreServiceProvider).deleteList(listId);
      // Show confirmation SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('List deleted successfully')),
      );
    } catch (e) {
      // Show error SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting list: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
