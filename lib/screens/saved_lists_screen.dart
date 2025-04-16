import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart'; // For swipe-to-delete
import 'package:intl/intl.dart'; // For date and currency formatting

import '../services/firestore_service.dart'; // Import the service
import 'list_details_screen.dart'; // Import the new details screen
// import 'home_screen.dart'; // No longer needed directly for navigation
import 'main_screen.dart'; // Import MainScreen for navigation

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

// Enum for menu actions
enum SavedListsMenuAction { scanLabel, deleteAll }

class SavedListsScreen extends ConsumerWidget {
  const SavedListsScreen({super.key});

  // Method to handle menu item selection
  void _handleMenuSelection(
    BuildContext context,
    WidgetRef ref,
    SavedListsMenuAction action,
  ) {
    switch (action) {
      case SavedListsMenuAction.scanLabel:
        // Navigate to MainScreen, which defaults to the HomeScreen (index 0)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const MainScreen(),
          ), // Navigate to MainScreen
          (Route<dynamic> route) => false, // Remove all previous routes
        );
        break;
      case SavedListsMenuAction.deleteAll:
        _deleteAllLists(context, ref);
        break;
    }
  }

  // Helper method to call deleteAllLists and show feedback
  void _deleteAllLists(BuildContext context, WidgetRef ref) async {
    // Optional: Show confirmation dialog before deleting
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text(
            'Are you sure you want to delete all saved lists? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false), // Return false
            ),
            TextButton(
              child: const Text(
                'Delete All',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () => Navigator.of(context).pop(true), // Return true
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // Proceed only if confirmed
      try {
        // Access the service directly for the action
        await ref
            .read(firestoreServiceProvider)
            .deleteAllLists(); // Assumes this method exists
        // Show confirmation SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All lists deleted successfully')),
        );
      } catch (e) {
        // Show error SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting lists: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedListsAsyncValue = ref.watch(savedListsStreamProvider);

    // Instantiate formatters once here
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final dateFormat = DateFormat('MMM d, yyyy, h:mm a');

    return Scaffold(
      appBar: AppBar(
        // Use logo image instead of text title
        title: Image.asset(
          'lib/assets/logo-text@4x.png',
          height: 35, // Match height used in HomeScreen
          semanticLabel: 'LabelScan Logo',
        ),
        // Keep AppBar background white (from theme), remove elevation if needed explicitly
        elevation: 0,
        centerTitle: false, // Ensure left alignment
        actions: [
          // Add Delete All Lists Button
          IconButton(
            icon: const Icon(Icons.delete_forever_outlined),
            tooltip: 'Delete All Lists',
            color: Colors.red, // Make the icon red
            onPressed: () => _deleteAllLists(context, ref), // Call the existing delete all method
          ),
        ],
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
              final title =
                  data?['title'] as String? ?? 'Untitled List'; // Get the title
              final totalCents = data?['total_cents'] as int? ?? 0;
              final subtotalCents =
                  data?['subtotal_cents'] as int? ?? 0; // Get subtotal_cents
              final timestamp = data?['timestamp'] as Timestamp?;
              final itemsList = data?['items'] as List<dynamic>? ?? [];
              final itemCount = itemsList.length;
              // Ensure itemsList is correctly typed for navigation
              final List<Map<String, dynamic>> typedItemsList =
                  List<Map<String, dynamic>>.from(itemsList);

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
                            builder:
                                (context) => ListDetailsScreen(
                                  title: title, // Pass the title
                                  items:
                                      typedItemsList, // Pass the correctly typed list
                                  timestamp: timestamp,
                                  totalCents: totalCents,
                                  subtotalCents:
                                      subtotalCents, // Pass subtotalCents
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
                  dismissible: DismissiblePane(
                    onDismissed: () {
                      // Call delete method when dismissed
                      _deleteList(context, ref, listId);
                    },
                  ),
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
                  subtitle: Text(
                    // Use dateFormat directly
                    '$itemCount items - ${(timestamp == null ? 'Unknown date' : dateFormat.format(timestamp.toDate()))}',
                  ), // Combine count and date
                  trailing: Text(
                    // Use currencyFormat directly
                    currencyFormat.format(totalCents / 100.0),
                    style: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 16, // Increase font size
                    ),
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
            return const Center(
              child: Text('Please log in to view saved lists.'),
            );
          }
          return Center(
            child: Text('Error loading lists: ${error.toString()}'),
          );
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
