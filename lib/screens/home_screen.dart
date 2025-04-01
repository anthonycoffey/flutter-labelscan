import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camera/camera.dart';
import 'package:flutter_labelscan/screens/camera_screen.dart';
import 'dart:convert'; // For jsonDecode
import 'dart:io'; // For File
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // For MediaType
import 'package:intl/intl.dart'; // For currency formatting
import 'package:flutter_labelscan/models/scanned_item.dart'; // Create this model later


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // We will add state variables for scanned items, etc. here
  

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    // Navigation happens automatically via AuthWrapper stream
  }

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
          print("Image captured: ${imageFile.path}");
          print("Image MIME type: ${imageFile.mimeType}"); // Log mime type
          await _uploadAndProcessImage(imageFile); // Pass the XFile
        } else {
          print("No image file received");
        }
    } catch (e) {
        print("Error opening camera: $e");
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

    // Determine content type
    MediaType? contentType;
    if (imageXFile.mimeType != null) {
      try {
        contentType = MediaType.parse(imageXFile.mimeType!);
      } catch (e) {
        print("Error parsing mimeType: ${imageXFile.mimeType}. Sending without explicit content type. Error: $e");
        // Optionally fall back to guessing based on extension or send without
      }
    } else {
       print("XFile mimeType is null. Sending without explicit content type.");
       // Could add logic here to guess based on file extension if needed
    }


    try {
        var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
        request.files.add(await http.MultipartFile.fromPath(
            'file', // This 'file' key must match what your Flask backend expects
            imageFile.path,
            contentType: contentType, // Set the content type explicitly
        ));

        print("Sending request to API with content type: ${contentType?.toString() ?? 'Not specified'}");
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        print("API Response Status: ${response.statusCode}");
        print("API Response Body: ${response.body}");


        if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            await _showConfirmationDialog(data['description'], data['amount']);
        } else {
            // Handle API errors (non-200 status)
            print("API Error: ${response.statusCode} - ${response.body}");
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
        // Handle network or other errors during API call
        print("Error uploading/processing image: $e");
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Network error or server issue. Please try again.'))
        );
    } finally {
        setState(() { _isProcessing = false; });
        // Optionally delete the temporary image file
        // try { await imageFile.delete(); } catch (e) { print("Error deleting temp file: $e"); }
    }
}


  Future<void> _showConfirmationDialog(String description, dynamic amount) async {
    int priceInCents;
    // Ensure amount is treated as int (it might be String or int from JSON)
    if (amount is String) {
        priceInCents = int.tryParse(amount) ?? 0;
    } else if (amount is int) {
        priceInCents = amount;
    } else if (amount is double) {
        priceInCents = amount.round(); // Handle potential decimals if API changes
    }
    else {
        print("Error: Invalid amount type received: ${amount.runtimeType}");
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Received invalid price data.'))
        );
        return;
    }


    // Format price for display in dialog
    final displayPrice = NumberFormat.currency(locale: 'en_US', symbol: '\$')
                                .format(priceInCents / 100.0);

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
              child: const Text('Confirm'),
              onPressed: () {
                _addItemToTable(description, priceInCents);
                Navigator.of(context).pop(); // Close dialog
              },
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
   // Calculate totals
   final subtotal = _subtotalCents;
   final taxes = _taxCents;
   final total = _totalCents;

  return Scaffold(
    appBar: AppBar(
      title: const Text('Label Scanner'),
      actions: [
         // Clear Button
         IconButton(
             icon: const Icon(Icons.delete_sweep),
             tooltip: 'Clear All Items',
             onPressed: _showClearConfirmationDialog,
         ),
         // Logout Button
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Logout',
          onPressed: _logout,
        ),
      ],
    ),
    body: Stack( // Use Stack to overlay loading indicator
       children: [
          Column(
             children: <Widget>[
                Expanded( // Make DataTable scrollable
                   child: _scannedItems.isEmpty
                      ? const Center(child: Text('Scan your first label!'))
                      : SingleChildScrollView( // Essential for DataTable
                           child: Padding(
                             padding: const EdgeInsets.all(8.0),
                             child: DataTable(
                                columns: const <DataColumn>[
                                   DataColumn(label: Text('Description')),
                                   DataColumn(label: Text('Price'), numeric: true),
                                ],
                                rows: [
                                   // Item Rows
                                   ..._scannedItems.map((item) => DataRow(
                                      cells: <DataCell>[
                                         DataCell(Text(item.description)),
                                         DataCell(Text(item.priceFormatted)),
                                      ],
                                   )),

                                   // --- Totals Rows ---
                                   // Subtotal Row (using DataRow for alignment)
                                    DataRow(
                                        cells: <DataCell>[
                                            DataCell(const Text('Subtotal', style: TextStyle(fontWeight: FontWeight.bold))),
                                            DataCell(Text(_formatCents(subtotal), style: const TextStyle(fontWeight: FontWeight.bold))),
                                        ]
                                    ),
                                   // Tax Row
                                    DataRow(
                                        cells: <DataCell>[
                                            DataCell(Text('Tax (${NumberFormat.percentPattern().format(_taxRate)})')),
                                            DataCell(Text(_formatCents(taxes))),
                                        ]
                                    ),
                                   // Total Row
                                    DataRow(
                                        cells: <DataCell>[
                                            DataCell(const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                            DataCell(Text(_formatCents(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                        ]
                                    ),
                                ],
                             ),
                           ),
                        ),
                ),
                // Leave space for the Floating Action Button
                const SizedBox(height: 80),
             ],
          ),
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
