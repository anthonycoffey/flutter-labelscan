import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For formatting
import 'package:google_fonts/google_fonts.dart'; // Added for receipt font

import '../models/scanned_item.dart'; // Assuming ScannedItem model exists

// Convert to StatefulWidget
class ListDetailsScreen extends StatefulWidget {
  final String title; // Add title parameter
  final List<Map<String, dynamic>> items; // Use Map for flexibility initially
  final Timestamp? timestamp;
  final int totalCents;
  final int subtotalCents; // Add subtotal parameter

  const ListDetailsScreen({
    super.key,
    required this.title, // Require title
    required this.items,
    required this.timestamp,
    required this.totalCents,
    required this.subtotalCents, // Require subtotal
  });

  @override
  State<ListDetailsScreen> createState() => _ListDetailsScreenState();
}

class _ListDetailsScreenState extends State<ListDetailsScreen> {
  // Store the parsed items in the state
  List<ScannedItem> _scannedItems = [];

  @override
  void initState() {
    super.initState();
    // Perform conversion once in initState
    _parseItems();
  }

  void _parseItems() {
    List<ScannedItem> parsed = [];
    for (var itemMap in widget.items) { // Access items via widget.items
      try {
        // Use the correct factory constructor from ScannedItem model
        parsed.add(ScannedItem.fromJson(itemMap));
      } catch (e) {
        print("Error parsing item in ListDetailsScreen: $e");
        // Optionally add a placeholder or skip the item
      }
    }
    // Update the state variable
     _scannedItems = parsed; // Direct assignment is okay here before first build
  }

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
    // Now use the state variable _scannedItems which is parsed only once
    final receiptTextStyle = GoogleFonts.robotoMono();
    final receiptBoldTextStyle = GoogleFonts.robotoMono(fontWeight: FontWeight.bold);

    return Scaffold(
      appBar: AppBar(
        // Simplified AppBar
        title: Text(widget.title, style: receiptTextStyle), // Use widget.title
        elevation: 0, // Flat app bar
        backgroundColor: Colors.grey[100], // Match receipt background
        foregroundColor: Colors.black, // Ensure back button is visible
      ),
      backgroundColor: Colors.white, // Background outside the receipt
      body: Center( // Center the receipt container
        child: Container(
          width: 320, // Fixed width for receipt look
          padding: const EdgeInsets.all(16.0),
          margin: const EdgeInsets.symmetric(vertical: 20.0), // Add some vertical margin
          decoration: BoxDecoration(
            color: Colors.grey[100], // Off-white background
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2), // changes position of shadow
              ),
            ],
            border: Border.all(color: Colors.grey[300]!), // Subtle border
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Fit content height
            crossAxisAlignment: CrossAxisAlignment.center, // Center header text
            children: [
              // Header
              Text(
                widget.title.toUpperCase(), // Display the list title (uppercased)
                style: receiptBoldTextStyle.copyWith(fontSize: 16),
                textAlign: TextAlign.center, // Center title if it wraps
              ),
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(widget.timestamp),
                style: receiptTextStyle.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Divider(thickness: 1, color: Colors.black54),
              const SizedBox(height: 8),

              // Items List - Use Flexible instead of Expanded inside a Min sized Column
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true, // Important with Flexible in Column
                  itemCount: _scannedItems.length, // Use state variable
                  itemBuilder: (context, index) {
                    final item = _scannedItems[index]; // Use state variable
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.description,
                                  style: receiptTextStyle,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 16), // Space before price
                              Text(
                                item.priceFormatted,
                                style: receiptTextStyle,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Divider(height: 1, color: Colors.grey[400]),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Divider(thickness: 2, color: Colors.black54), // Separator before total
              const SizedBox(height: 8),

              // Subtotal Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.0), // Align with items
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal:',
                      style: receiptTextStyle, // Use regular style for subtotal label
                    ),
                    Text(
                      _formatCents(widget.subtotalCents), // Display subtotal
                      style: receiptTextStyle, // Use regular style for subtotal value
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4), // Space between subtotal and total

              // Total Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.0), // Align with items
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: receiptBoldTextStyle,
                    ),
                    Text(
                      _formatCents(widget.totalCents), // Access via widget.
                      style: receiptBoldTextStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Removed FloatingActionButton
    );
  }
}
