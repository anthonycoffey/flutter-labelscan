import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For formatting

import '../models/scanned_item.dart'; // Assuming ScannedItem model exists

class ListDetailsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> items; // Use Map for flexibility initially
  final Timestamp? timestamp;
  final int totalCents;

  const ListDetailsScreen({
    super.key,
    required this.items,
    required this.timestamp,
    required this.totalCents,
  });

  // Helper to format cents to currency string (copied from SavedListsScreen)
  String _formatCents(int cents) {
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    return currencyFormat.format(cents / 100.0);
  }

  // Helper to format Timestamp to a readable date/time string (copied from SavedListsScreen)
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown date';
    return DateFormat('MMM d, yyyy, h:mm a').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    // Attempt to parse items into ScannedItem objects
    List<ScannedItem> scannedItems = [];
    for (var itemMap in items) {
      try {
        // Use the correct factory constructor from ScannedItem model
        scannedItems.add(ScannedItem.fromJson(itemMap));
      } catch (e) {
        print("Error parsing item in ListDetailsScreen: $e");
        // Optionally add a placeholder or skip the item
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('List from ${_formatTimestamp(timestamp)}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Total: ${_formatCents(totalCents)}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: scannedItems.length,
              itemBuilder: (context, index) {
                final item = scannedItems[index];
                // Use the correct fields from ScannedItem model
                return ListTile(
                  title: Text(item.description), // Use description as the main text
                  // subtitle: Text(item.description ?? ''), // Remove subtitle if description is title
                  trailing: Text(item.priceFormatted), // Use the model's formatted price
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
