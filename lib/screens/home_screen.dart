import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart'; // For NumberFormat

import '../models/scanned_item.dart';
import '../providers/home_providers.dart';
import '../services/api_service.dart'; // For ApiException

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the state and listen for errors
    final homeState = ref.watch(homeControllerProvider);
    final homeController = ref.read(homeControllerProvider.notifier);

    // Listen for errors and show SnackBars
    ref.listen<HomeState>(homeControllerProvider, (previous, next) {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('LabelScan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear All Items',
            // Disable button if list is empty or processing
            onPressed: homeState.scannedItems.isEmpty || homeState.isProcessing
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
                    : _ScannedItemsListView(
                        items: homeState.scannedItems,
                        onEdit: (index) => _showEditItemDialog(context, ref, index),
                        onDelete: (index) {
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
                      // totalCents: homeState.totalCents, // Removed, shown in title
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
          // Loading Indicator Overlay
          if (homeState.isProcessing)
            _LoadingOverlay(message: homeState.processingMessage),
        ],
      ),
      floatingActionButton: _ActionButtons(
        isProcessing: homeState.isProcessing,
        onScan: () => homeController.scanLabel(context), // Pass context
        onUpload: () => homeController.pickImageFromGallery(context), // Pass context
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // --- Dialogs (kept in UI layer, but trigger controller actions) ---

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
    final currentItem = ref.read(homeControllerProvider).scannedItems[index];
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

  const _ScannedItemsListView({
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Slidable(
            key: ValueKey(item.hashCode), // Use a unique key, hashCode might work if items are immutable enough
            startActionPane: ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) => onEdit(index),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  icon: Icons.edit,
                  label: 'Edit',
                ),
              ],
            ),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              dismissible: DismissiblePane(onDismissed: () => onDelete(index)),
              children: [
                SlidableAction(
                  onPressed: (context) => onDelete(index),
                  backgroundColor: Colors.red,
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
  // final int totalCents; // Removed - now shown in ExpansionTile title
  final double taxRate;
  final String Function(int) formatCents; // Receive formatter function

  const _TotalsDisplay({
    required this.subtotalCents,
    required this.taxCents,
    // required this.totalCents, // Removed
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
          // const SizedBox(height: 8), // Removed SizedBox before total
          // Row for Total removed - now shown in ExpansionTile title
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool isProcessing;
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
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
