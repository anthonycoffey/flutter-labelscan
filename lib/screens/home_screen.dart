import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camera/camera.dart';
import 'package:flutter_labelscan/screens/camera_screen.dart';
import 'dart:convert'; // For jsonDecode
import 'dart:io'; // For File
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // For MediaType
import 'package:mime/mime.dart'; // Import the mime package
import 'package:intl/intl.dart'; // For currency formatting
import 'package:flutter_labelscan/models/scanned_item.dart';
import 'package:flutter_slidable/flutter_slidable.dart'; // Import Slidable


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // We will add state variables for scanned items, etc. here
  
  // Removed _logout function, it's now in MyAccountScreen

  final List<ScannedItem> _scannedItems = []; // State variable for the table
  final double _taxRate = 0.0825; // Example: 8.25% tax rate (Austin, TX) - make this configurable later
  bool _isProcessing = false; // To show loading indicator

  void _scanLabel() async {
    try {
        // Obtain a list of the available cameras on the device.
        final cameras = await availableCameras();

        if (cameras.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No cameras found on this device.'))
          );
          return;
        }

        // Show the camera screen and wait for a result (XFile object)
        final imageFile = await Navigator.push<XFile?>( // Expect XFile?
          context,
          MaterialPageRoute(
              builder: (context) => CameraScreen(cameras: cameras),
          ),
        );

        if (imageFile != null) { // Check if XFile is not null
          debugPrint("Image captured: ${imageFile.path}");
          debugPrint("Image MIME type: ${imageFile.mimeType}"); // Log mime type
          await _uploadAndProcessImage(imageFile); // Pass the XFile
        } else {
          debugPrint("No image file received");
        }
    } catch (e) {
        debugPrint("Error opening camera: $e");
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error accessing camera.'))
        );
    }
  }

  // Updated to accept XFile
  Future<void> _uploadAndProcessImage(XFile imageXFile) async {
    setState(() { _isProcessing = true; });

    const String apiUrl = "https://flask-api-87033406861.us-central1.run.app/api/extract-data";
    File imageFile = File(imageXFile.path); // Get path from XFile

    // Determine content type more robustly
    MediaType? contentType;
    String? mimeTypeString = imageXFile.mimeType;

    if (mimeTypeString == null) {
      debugPrint("XFile mimeType is null. Attempting lookup from path: ${imageXFile.path}");
      mimeTypeString = lookupMimeType(imageXFile.path); // Use mime package
      if (mimeTypeString != null) {
        debugPrint("MIME type looked up from path: $mimeTypeString");
      } else {
        debugPrint("Could not determine MIME type from path either.");
      }
    }

    if (mimeTypeString != null) {
      try {
        contentType = MediaType.parse(mimeTypeString);
      } catch (e) {
        debugPrint("Error parsing determined mimeType: $mimeTypeString. Error: $e");
        // Fallback: Send without explicit content type if parsing fails
        contentType = null;
      }
    } else {
       debugPrint("Could not determine MIME type. Sending without explicit content type.");
       // contentType remains null
    }


    try {
        var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
        request.files.add(await http.MultipartFile.fromPath(
            'file', // This 'file' key must match what your Flask backend expects
            imageFile.path,
            contentType: contentType, // Pass the determined content type
        ));

        debugPrint("Sending request to API with content type: ${contentType?.toString() ?? 'Not specified'}");
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        debugPrint("API Response Status: ${response.statusCode}");
        debugPrint("API Response Body: ${response.body}");


        if (response.statusCode == 200) {
          try { // Add nested try for processing successful response
            final decodedBody = jsonDecode(response.body);
            // Check if 'data' exists, is a non-empty list, and the first element is a Map
            if (decodedBody != null &&
                decodedBody['data'] is List &&
                (decodedBody['data'] as List).isNotEmpty &&
                decodedBody['data'][0] is Map) { // Added check for Map type
              final data = decodedBody['data'][0] as Map; // Cast to Map for safety
              // Ensure data extraction is safe
              final description = data['description']?.toString() ?? 'No description'; // Access directly now
              final amount = data['amount']; // Access directly now
              await _showConfirmationDialog(description, amount);
            } else {
              // Handle cases where 'data' is missing, not a list, empty, or first element isn't a Map
              debugPrint("API Error: Unexpected response format. Expected 'data' as non-empty List<Map>. Body: ${response.body}");
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error: Received unexpected data format from server.'))
              );
            }
          } catch (e) { // Add nested catch for errors during processing
            debugPrint("Error processing successful API response (status 200): $e. Body: ${response.body}");
            // Show a more specific error message
            String errorSummary = e.toString().split('\n').first; // Get first line of error
             if (errorSummary.length > 100) { // Limit length
               errorSummary = '${errorSummary.substring(0, 97)}...';
             }
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Error processing server response: $errorSummary'))
            );
          }
        } else {
            // Handle API errors (non-200 status)
            debugPrint("API Error: ${response.statusCode} - ${response.body}");
            // Include response body in SnackBar for better debugging
            String errorDetail = response.body.isNotEmpty ? response.body : response.reasonPhrase ?? 'Unknown error';
            // Limit length to avoid overly long SnackBars
            if (errorDetail.length > 100) {
              errorDetail = '${errorDetail.substring(0, 97)}...';
            }
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error processing image: $errorDetail'))
            );
        }
    } catch (e) {
        // Outer catch: Handle network errors or errors during the request sending phase
        debugPrint("Error during image upload/API request: $e"); // Clarify scope
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Network error or server issue. Please try again.')) // Keep this generic for network issues
        );
    } finally {
        setState(() { _isProcessing = false; });
        // Optionally delete the temporary image file
        // try { await imageFile.delete(); } catch (e) { print("Error deleting temp file: $e"); }
    }
}


  Future<void> _showConfirmationDialog(String description, dynamic amount) async {
    int? priceInCents; // Make nullable to handle N/A case
    String displayPrice = "N/A";
    bool canConfirm = false; // Control confirm button state

    // Check for "N/A" first
    if (amount is String && amount.toUpperCase() == "N/A") {
        debugPrint("Price is N/A for item: $description");
        displayPrice = "N/A - Not Found";
        priceInCents = null; // Explicitly null for N/A
        canConfirm = false;
    } else if (amount is String) {
        priceInCents = int.tryParse(amount);
    } else if (amount is int) {
        priceInCents = amount;
    } else if (amount is double) {
        priceInCents = amount.round(); // Handle potential decimals
    }

    // If parsing failed or type was invalid (and not N/A)
    if (priceInCents == null && !(amount is String && amount.toUpperCase() == "N/A")) {
        debugPrint("Error: Invalid or unparsable amount received: ${amount.runtimeType}, value: $amount");
        displayPrice = "Invalid Price";
        priceInCents = null; // Ensure it's null
        canConfirm = false;
         ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Received invalid price data.'))
         );
         // Optionally return early if you don't want to show the dialog for invalid data
         // return;
    } else if (priceInCents != null) {
        // Format valid price for display
        displayPrice = NumberFormat.currency(locale: 'en_US', symbol: '\$')
                                    .format(priceInCents / 100.0);
        canConfirm = true; // Allow confirmation only if price is valid
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Item'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Description: $description'),
                Text('Price: $displayPrice'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
            ),
            TextButton(
              // Disable confirm button if price is N/A or invalid
              onPressed: canConfirm ? () {
                if (priceInCents != null) { // Double check price isn't null
                  _addItemToTable(description, priceInCents);
                }
                Navigator.of(context).pop(); // Close dialog
              } : null, // Set onPressed to null to disable
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _addItemToTable(String description, int priceInCents) {
    setState(() {
        _scannedItems.add(ScannedItem(
            description: description,
            priceInCents: priceInCents,
        ));
    });
  }

  // --- Delete Item ---
  void _deleteItem(int index) {
    setState(() {
      _scannedItems.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item deleted')),
    );
  }

  // --- Edit Item ---
  void _editItem(int index, String newDescription, int newPriceInCents) {
    setState(() {
      _scannedItems[index] = ScannedItem(
        description: newDescription,
        priceInCents: newPriceInCents,
      );
    });
  }

  Future<void> _showEditItemDialog(int index) async {
    final ScannedItem currentItem = _scannedItems[index];
    final descriptionController = TextEditingController(text: currentItem.description);
    // Convert cents to dollars string for the text field
    final priceController = TextEditingController(text: (currentItem.priceInCents / 100.0).toStringAsFixed(2));
    final formKey = GlobalKey<FormState>(); // For validation

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Item'),
          content: Form( // Use a Form for validation
            key: formKey,
            child: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a description';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'Price (\$)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a price';
                      }
                      final price = double.tryParse(value);
                      if (price == null || price < 0) {
                        return 'Please enter a valid positive price';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final newDescription = descriptionController.text.trim();
                  // Convert dollars string back to cents integer
                  final newPriceInCents = (double.parse(priceController.text) * 100).round();
                  _editItem(index, newDescription, newPriceInCents);
                  Navigator.of(context).pop(); // Close dialog
                }
              },
            ),
          ],
        );
      },
    );
  }


  // Calculation methods
  int get _subtotalCents => _scannedItems.fold(0, (sum, item) => sum + item.priceInCents);
  int get _taxCents => (_subtotalCents * _taxRate).round();
  int get _totalCents => _subtotalCents + _taxCents;

  // Formatting helper
  String _formatCents(int cents) {
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    return currencyFormat.format(cents / 100.0);
  }

  void _showClearConfirmationDialog() {
      if (_scannedItems.isEmpty) return; // Don't show if already empty

      showDialog<void>(
          context: context,
          builder: (BuildContext context) {
              return AlertDialog(
                  title: const Text('Start Over?'),
                  content: const Text('Are you sure you want to clear all scanned items?'),
                  actions: <Widget>[
                      TextButton(
                          child: const Text('Cancel'),
                          onPressed: () => Navigator.of(context).pop(),
                      ),
                      TextButton(
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Clear All'),
                          onPressed: () {
                              setState(() {
                                  _scannedItems.clear();
                              });
                              Navigator.of(context).pop();
                          },
                      ),
                  ],
              );
          },
      );
  }

@override
Widget build(BuildContext context) {
   // Calculate totals FIRST
   final subtotal = _subtotalCents;
   final taxes = _taxCents;
   final total = _totalCents;

  return Scaffold(
    appBar: AppBar(
      title: const Text('LabelScan'), // Changed title
      actions: [
         // Clear Button (Kept)
         IconButton(
             icon: const Icon(Icons.delete_sweep),
             tooltip: 'Clear All Items',
             onPressed: _showClearConfirmationDialog,
         ),
         // Logout Button (Removed)
      ],
    ),
    body: Stack( // Use Stack to overlay loading indicator
       children: [
          Column(
             children: <Widget>[
                Expanded( // Make ListView scrollable
                  child: _scannedItems.isEmpty
                      ? const Center(child: Text('Scan your first label!'))
                      : ListView.builder(
                          itemCount: _scannedItems.length,
                          itemBuilder: (context, index) {
                            final item = _scannedItems[index];
                            return Slidable(
                              key: ValueKey(item), // Unique key for each item
                              // Define the start action pane (e.g., for Edit)
                              startActionPane: ActionPane(
                                motion: const ScrollMotion(), // Or BehindMotion, StretchMotion, etc.
                                children: [
                                  SlidableAction(
                                    onPressed: (context) => _showEditItemDialog(index),
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    icon: Icons.edit,
                                    label: 'Edit',
                                  ),
                                ],
                              ),
                              // Define the end action pane (e.g., for Delete)
                              endActionPane: ActionPane(
                                motion: const ScrollMotion(),
                                dismissible: DismissiblePane(onDismissed: () {
                                  _deleteItem(index);
                                }),
                                children: [
                                  SlidableAction(
                                    onPressed: (context) => _deleteItem(index), // Add onPressed back
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    icon: Icons.delete,
                                    label: 'Delete',
                                  ),
                                ],
                              ),
                              // The child of the Slidable is the actual list item content
                              child: ListTile(
                                title: Text(item.description),
                                trailing: Text(item.priceFormatted),
                              ),
                            );
                          },
                        ),
                ), // End of Expanded

                // --- Totals Section (Moved INSIDE Column children) ---
                if (_scannedItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0), // Adjust padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(_formatCents(subtotal), style: const TextStyle(fontWeight: FontWeight.bold)), // Use calculated subtotal
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Tax (${NumberFormat.percentPattern().format(_taxRate)})'),
                            Text(_formatCents(taxes)), // Use calculated taxes
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(_formatCents(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), // Use calculated total
                          ],
                        ),
                      ],
                    ),
                  ), // End of Totals Padding

                // Leave space for the Floating Action Button (ensure it's the last item before Column closes)
                const SizedBox(height: 80),

              ], // End of Column children
            ), // End of Column
          // Loading Indicator Overlay
          if (_isProcessing)
             Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                   child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                           CircularProgressIndicator(),
                           SizedBox(height: 10),
                           Text("Processing...", style: TextStyle(color: Colors.white)),
                       ]
                   )
                ),
             ),
       ],
    ),

    floatingActionButton: FloatingActionButton.extended(
       onPressed: _isProcessing ? null : _scanLabel, // Disable button while processing
       label: const Text('Scan Label'),
       icon: const Icon(Icons.camera_alt),
       backgroundColor: _isProcessing ? Colors.grey : null, // Indicate disabled state
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
  );
}
}
