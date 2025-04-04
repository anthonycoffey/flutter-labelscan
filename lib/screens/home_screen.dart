import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart'; // For NumberFormat
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for Timestamp

import '../models/scanned_item.dart';
import '../providers/home_providers.dart';
import '../services/api_service.dart'; // For ApiException
// Removed ListProvider import as saving is handled by HomeController now

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the state and listen for errors/state changes
    final homeState = ref.watch(homeControllerProvider);
    final homeController = ref.read(homeControllerProvider.notifier);

    // Listen for general processing errors and show SnackBars
    ref.listen<HomeState>(homeControllerProvider, (previous, next) {
      // Show general processing error
      if (next.error != null && next.error != previous?.error) {
        String errorMessage = "An unknown error occurred.";
        if (next.error is ApiException) {
          errorMessage = (next.error as ApiException).message;
        } else if (next.error is String) {
          errorMessage = next.error as String;
        }
        // Ensure context is still valid before showing SnackBar
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text(errorMessage),
               backgroundColor: Colors.redAccent,
             ),
           );
           // Optionally clear the error after showing it
           // Future.microtask(() => homeController.clearError());
        }
      }

      // Show save error
      if (next.saveError != null && next.saveError != previous?.saveError) {
         if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text("Error saving list: ${next.saveError.toString()}"),
               backgroundColor: Colors.redAccent,
             ),
           );
           // Optionally clear the save error after showing it
           // Future.microtask(() => homeController.clearSaveError()); // Need to add clearSaveError to controller if desired
         }
      }
    });

    // Listen for pending items to show confirmation dialog
    ref.listen<HomeState>(homeControllerProvider, (previous, next) {
      final hasNewPendingItem = next.pendingItemDescription != null &&
                                next.pendingItemPriceCents != null;
      final wasDifferent = previous == null ||
                           next.pendingItemDescription != previous.pendingItemDescription ||
                           next.pendingItemPriceCents != previous.pendingItemPriceCents;

      if (hasNewPendingItem && wasDifferent) {
        // Using Future.microtask to avoid calling dialog during build/state update
        Future.microtask(() {
          if (context.mounted) { // Check if widget is still in the tree
            _showScanConfirmationDialog(
              context,
              homeController,
              next.pendingItemDescription!,
              next.pendingItemPriceCents!,
              homeState.formatCents, // Pass formatter from current state
            );
          }
        });
      }
    });

     // Listen for successful save to show confirmation and potentially clear list
    ref.listen<HomeState>(homeControllerProvider, (previous, next) {
      final justSavedSuccessfully = previous?.isSaving == true &&
                                    next.isSaving == false &&
                                    next.saveError == null;

      if (justSavedSuccessfully && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('List saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Optionally clear the list after successful save
        // homeController.clearAllItems();
      }
    });


    return Scaffold(
      appBar: AppBar(
        title: const Text('LabelScan'),
        actions: [
          // Save Button
          IconButton(
            icon: homeState.isSaving
                ? const SizedBox( // Show progress indicator when saving
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                  )
                : const Icon(Icons.save_alt), // Show save icon otherwise
            tooltip: 'Save List',
            // Disable if list is empty or currently saving
            onPressed: homeState.scannedItems.isEmpty || homeState.isSaving
                ? null
                : () {
                    // Call the dialog function instead of saving directly
                    _showSaveListDialog(context, ref);
                  },
          ),
          // Clear Button
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear All Items',
            // Disable button if list is empty or processing/saving
            onPressed: homeState.scannedItems.isEmpty || homeState.isProcessing || homeState.isSaving
                ? null
                : () => _showClearConfirmationDialog(context, homeController),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: <Widget>[
              Expanded(
                child: homeState.scannedItems.isEmpty
                    ? const Center(child: Text('Scan or upload your first label!'))
                    : _ScannedItemsListView( // Pass isSaving state here
                        items: homeState.scannedItems,
                        isSaving: homeState.isSaving,
                        onEdit: (index) => _showEditItemDialog(context, ref, index),
                        onDelete: (index) {
                          // Disable delete if saving (already handled in SlidableAction onPressed)
                          // if (homeState.isSaving) return; // Redundant check
                          homeController.deleteItem(index);
                          // Show confirmation SnackBar after delete
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Item deleted')),
                          );
                        },
                      ),
              ),
              // Collapsible Totals Section
              if (homeState.scannedItems.isNotEmpty) ...[
                const Divider(height: 1, indent: 16, endIndent: 16), // Divider before totals
                ExpansionTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Totals', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        homeState.formatCents(homeState.totalCents),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                  childrenPadding: EdgeInsets.zero, // _TotalsDisplay handles its padding
                  initiallyExpanded: false,
                  children: <Widget>[
                    _TotalsDisplay(
                      subtotalCents: homeState.subtotalCents,
                      taxCents: homeState.taxCents,
                      taxRate: homeState.taxRate,
                      formatCents: homeState.formatCents,
                    ),
                  ],
                ),
              ],
              // Leave space for the Floating Action Button
              const SizedBox(height: 80),
            ],
          ),
          // Loading Indicator Overlay for image processing
          if (homeState.isProcessing)
            _LoadingOverlay(message: homeState.processingMessage),
          // Could add a saving overlay too if desired, but button indicator might be enough
          // if (homeState.isSaving)
          //   _LoadingOverlay(message: "Saving..."),
        ],
      ),
      floatingActionButton: _ActionButtons(
        // Disable scan/upload if saving
        isProcessing: homeState.isProcessing || homeState.isSaving,
        onScan: () => homeController.scanLabel(context), // Pass context
        onUpload: () => homeController.pickImageFromGallery(context), // Pass context
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // --- Dialogs (kept in UI layer, but trigger controller actions) ---

  // --- New Dialog for Saving List with Title ---
  Future<void> _showSaveListDialog(BuildContext context, WidgetRef ref) async {
    final homeController = ref.read(homeControllerProvider.notifier);
    final homeState = ref.read(homeControllerProvider); // Read current state
    final titleController = TextEditingController();
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();

    // Pre-check if there are items to save before showing dialog
    if (homeState.scannedItems.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Nothing to save.')),
       );
       return;
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Save List'),
          content: SingleChildScrollView(
            child: Form(
              key: dialogFormKey,
              child: ListBody(
                children: <Widget>[
                  const Text('Please enter a title for this list:'),
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(hintText: 'List Title'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Title cannot be empty';
                      }
                      return null;
                    },
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () async { // Make async for save operation
                if (dialogFormKey.currentState!.validate()) {
                  final title = titleController.text.trim();
                  Navigator.of(dialogContext).pop(); // Close dialog first

                  // Call the controller method to save with title
                  // This method needs to be added/updated in HomeController
                  await homeController.saveCurrentListWithTitle(title);

                  // Success/Error Snackbars are handled by the listener in build method
                }
              },
            ),
          ],
        );
      },
    );
  }


  void _showClearConfirmationDialog(BuildContext context, HomeController controller) {
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
                controller.clearAllItems(); // Call controller method
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditItemDialog(BuildContext context, WidgetRef ref, int index) async {
    // Access the current state via ref.read since this is triggered by an action
    final homeState = ref.read(homeControllerProvider); // Read state for isSaving check
    if (homeState.isSaving) return; // Prevent editing while saving

    final currentItem = homeState.scannedItems[index];
    final controller = ref.read(homeControllerProvider.notifier);

    final descriptionController = TextEditingController(text: currentItem.description);
    final priceController = TextEditingController(
      text: (currentItem.priceInCents / 100.0).toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Item'),
          content: Form(
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
                      if (value == null || value.isEmpty) return 'Please enter a price';
                      final price = double.tryParse(value);
                      if (price == null || price < 0) return 'Please enter a valid positive price';
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
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final newDescription = descriptionController.text.trim();
                  final newPriceInCents = (double.parse(priceController.text) * 100).round();
                  controller.editItem(index, newDescription, newPriceInCents); // Call controller
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- New Dialog for Scan Confirmation ---
  Future<void> _showScanConfirmationDialog(
    BuildContext context,
    HomeController controller,
    String description,
    int priceInCents,
    String Function(int) formatCents, // Receive formatter
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Item'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const SizedBox(height: 10),
                Text('Description: $description'),
                Text('Price: ${formatCents(priceInCents)}'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                controller.cancelPendingItem(); // Call controller action
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                controller.confirmPendingItem(); // Call controller action
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

// --- Sub-Widgets ---

class _ScannedItemsListView extends StatelessWidget {
  final List<ScannedItem> items;
  final Function(int) onEdit;
  final Function(int) onDelete;
  final bool isSaving; // Add isSaving parameter

  const _ScannedItemsListView({
    required this.items,
    required this.onEdit,
    required this.onDelete,
    required this.isSaving, // Require isSaving
  });

  @override
  Widget build(BuildContext context) {
    // Use the passed 'isSaving' parameter directly
    // final isSaving = context.read(homeControllerProvider).isSaving; // Incorrect usage removed

    return Scrollbar(
      thumbVisibility: true,
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Slidable(
            key: ValueKey(item.hashCode), // Use a unique key
            startActionPane: ActionPane(
              motion: const ScrollMotion(),
              // Disable edit action while saving
              children: [
                SlidableAction(
                  onPressed: isSaving ? null : (context) => onEdit(index),
                  backgroundColor: isSaving ? Colors.grey : Colors.blue,
                  foregroundColor: Colors.white,
                  icon: Icons.edit,
                  label: 'Edit',
                ),
              ],
            ),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              // Disable delete action while saving
              dismissible: isSaving ? null : DismissiblePane(onDismissed: () => onDelete(index)),
              children: [
                SlidableAction(
                  onPressed: isSaving ? null : (context) => onDelete(index),
                  backgroundColor: isSaving ? Colors.grey : Colors.red,
                  foregroundColor: Colors.white,
                  icon: Icons.delete,
                  label: 'Delete',
                ),
              ],
            ),
            child: ListTile(
              title: Text(item.description),
              trailing: Text(item.priceFormatted),
            ),
          );
        },
      ),
    );
  }
}

class _TotalsDisplay extends StatelessWidget {
  final int subtotalCents;
  final int taxCents;
  final double taxRate;
  final String Function(int) formatCents; // Receive formatter function

  const _TotalsDisplay({
    required this.subtotalCents,
    required this.taxCents,
    required this.taxRate,
    required this.formatCents,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(formatCents(subtotalCents), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tax (${NumberFormat.percentPattern().format(taxRate)})'),
              Text(formatCents(taxCents)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool isProcessing; // Includes both processing and saving now
  final VoidCallback onScan;
  final VoidCallback onUpload;

  const _ActionButtons({
    required this.isProcessing,
    required this.onScan,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final Color activeColor = Theme.of(context).colorScheme.primary;
    final Color inactiveColor = Colors.grey[600]!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        FloatingActionButton(
          heroTag: 'upload_button',
          onPressed: isProcessing ? null : onUpload,
          tooltip: 'Upload Image',
          foregroundColor: isProcessing ? inactiveColor : activeColor,
          backgroundColor: Colors.transparent,
          elevation: 0.0, focusElevation: 0.0, hoverElevation: 0.0, highlightElevation: 0.0,
          shape: CircleBorder(side: BorderSide(color: isProcessing ? inactiveColor : activeColor, width: 1.5)),
          child: const Icon(Icons.photo_library),
        ),
        const SizedBox(width: 16),
        FloatingActionButton(
          heroTag: 'scan_button',
          onPressed: isProcessing ? null : onScan,
          tooltip: 'Scan Label',
          foregroundColor: isProcessing ? inactiveColor : activeColor,
          backgroundColor: Colors.transparent,
          elevation: 0.0, focusElevation: 0.0, hoverElevation: 0.0, highlightElevation: 0.0,
          shape: CircleBorder(side: BorderSide(color: isProcessing ? inactiveColor : activeColor, width: 1.5)),
          child: const Icon(Icons.qr_code_scanner),
        ),
      ],
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  final String message;
  const _LoadingOverlay({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            Text(
              message, // Corrected: Use the 'message' parameter
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
