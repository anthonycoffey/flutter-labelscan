import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for InputFormatter
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
// import 'package:flutter_svg/flutter_svg.dart'; // Keep package but comment out import
import 'package:intl/intl.dart'; // For NumberFormat

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
          ScaffoldMessenger.of(context).clearSnackBars(); // Clear previous SnackBars
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating, // Make it float
              margin: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0), // Add top margin
            ),
          );
          // Optionally clear the error after showing it
          // Future.microtask(() => homeController.clearError());
        }
      }

      // Show save error
      if (next.saveError != null && next.saveError != previous?.saveError) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).clearSnackBars(); // Clear previous SnackBars
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error saving list: ${next.saveError.toString()}"),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating, // Make it float
              margin: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0), // Add top margin
            ),
          );
          // Optionally clear the save error after showing it
          // Future.microtask(() => homeController.clearSaveError()); // Need to add clearSaveError to controller if desired
        }
      }
    });

    // Listen for pending items to show confirmation dialog
    ref.listen<HomeState>(homeControllerProvider, (previous, next) {
      final hasNewPendingItem =
          next.pendingItemDescription != null &&
          next.pendingItemPriceCents != null;
      final wasDifferent =
          previous == null ||
          next.pendingItemDescription != previous.pendingItemDescription ||
          next.pendingItemPriceCents != previous.pendingItemPriceCents;

      if (hasNewPendingItem && wasDifferent) {
        // Using Future.microtask to avoid calling dialog during build/state update
        Future.microtask(() {
          if (context.mounted) {
            // Check if widget is still in the tree
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

    // Listen for successful save to show confirmation and clear list
    ref.listen<HomeState>(homeControllerProvider, (previous, next) {
      final justSavedSuccessfully =
          previous?.isSaving == true &&
          next.isSaving == false &&
          next.saveError == null;

      if (justSavedSuccessfully && context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars(); // Clear previous SnackBars
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('List saved successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating, // Make it float
            margin: EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0), // Add top margin
          ),
        );

        homeController.clearAllItems();
      }
    });

    return Scaffold(
      appBar: AppBar(
        // Use PNG logo instead of SVG
        title: Image.asset(
          'lib/assets/logo-text@4x.png', // Use highest resolution PNG
          height: 35, // Increased height
          // Optional: Add semantics label for accessibility
          semanticLabel: 'LabelScan Logo',
          // Optional: Add scale parameter if needed, but height usually suffices
          // scale: 1.0,
        ),
        centerTitle: false, // Ensure left alignment
        actions: [
          // Context Menu Button
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu_open), // Changed icon to plus
            tooltip: 'More Options',
            onSelected: (String result) {
              switch (result) {
                case 'save':
                  // Call the existing dialog function
                  _showSaveListDialog(context, ref);
                  break;
                case 'clear':
                  // Call the existing dialog function
                  _showClearConfirmationDialog(context, homeController);
                  break;
              }
            },
            itemBuilder:
                (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'save',
                    // Disable if list is empty or currently saving
                    enabled:
                        !(homeState.scannedItems.isEmpty || homeState.isSaving),
                    child: Row(
                      children: [
                        homeState.isSaving
                            ? const SizedBox(
                              // Show progress indicator when saving
                              width: 20, // Slightly smaller for menu item
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                              ), // Use default color
                            )
                            : const Icon(
                              Icons.cloud_upload,
                              size: 20,
                            ), // Changed save icon
                        const SizedBox(width: 8),
                        const Text('Save List'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'clear',
                    // Disable if list is empty or processing/saving
                    enabled:
                        !(homeState.scannedItems.isEmpty ||
                            homeState.isProcessing ||
                            homeState.isSaving),
                    child: const Row(
                      children: [
                        Icon(Icons.delete_sweep_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('Clear All Items'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: <Widget>[
              Expanded(
                child:
                    homeState.scannedItems.isEmpty
                        ? Center( // Removed 'const' here
                            child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Use brand icon instead of inventory icon
                              Image.asset(
                                'lib/assets/logo-icon-transparent-bg@4x.png', // Path to the brand icon
                                height: 200, // Match the previous icon size
                                // color: Colors.black38, // Keep the color muted
                                // Optional: Add semantics label
                                semanticLabel: 'LabelScan Logo Icon',
                              ),
                              SizedBox(height: 32),
                              Text('No items in your list yet'),
                              SizedBox(height: 8),
                              Text('Upload or scan price tags to get started!', style: TextStyle(fontSize: 14, color: Colors.black54)),
                            ],
                            ),
                        )
                        : _ScannedItemsListView(
                          // Pass isSaving state here
                          items: homeState.scannedItems,
                          isSaving: homeState.isSaving,
                          onEdit:
                              (index) =>
                                  _showEditItemDialog(context, ref, index),
                          onDelete: (index) {
                            // Disable delete if saving (already handled in SlidableAction onPressed)
                            // if (homeState.isSaving) return; // Redundant check
                            homeController.deleteItem(index);
                            // Show confirmation SnackBar after delete
                            ScaffoldMessenger.of(context).clearSnackBars(); // Clear previous SnackBars
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Item deleted'),
                                behavior: SnackBarBehavior.floating, // Make it float
                                margin: EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0), // Add top margin
                              ),
                            );
                          },
                        ),
              ),
              // --- Action Buttons Moved Here ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: _ActionButtons(
                  // Disable scan/upload if saving or processing
                  isProcessing: homeState.isProcessing || homeState.isSaving,
                  onScan:
                      () => homeController.scanLabel(context), // Pass context
                  onUpload:
                      () => homeController.pickImageFromGallery(
                        context,
                      ), // Pass context
                ),
              ),
              // Collapsible Totals Section
              if (homeState.scannedItems.isNotEmpty) ...[
                const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ), // Divider before totals
                ExpansionTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Totals',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        homeState.formatCents(homeState.totalCents),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                  childrenPadding:
                      EdgeInsets.zero, // _TotalsDisplay handles its padding
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
              // Removed SizedBox placeholder for FAB
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
      // Removed floatingActionButton and floatingActionButtonLocation
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
      ScaffoldMessenger.of(context).clearSnackBars(); // Clear previous SnackBars
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nothing to save.'),
          behavior: SnackBarBehavior.floating, // Make it float
          margin: EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0), // Add top margin
        ),
      );
      return;
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          // title: const Text('Save List'),
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
              onPressed: () async {
                // Make async for save operation
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

  void _showClearConfirmationDialog(
    BuildContext context,
    HomeController controller,
  ) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Start Over?'),
          content: const Text(
            'Are you sure you want to clear all scanned items?',
          ),
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

  Future<void> _showEditItemDialog(
    BuildContext context,
    WidgetRef ref,
    int index,
  ) async {
    // Access the current state via ref.read since this is triggered by an action
    final homeState = ref.read(
      homeControllerProvider,
    ); // Read state for isSaving check
    if (homeState.isSaving) return; // Prevent editing while saving

    final currentItem = homeState.scannedItems[index];
    final controller = ref.read(homeControllerProvider.notifier);

    final descriptionController = TextEditingController(
      text: currentItem.description,
    );
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
                    // Force uppercase input
                    inputFormatters: [
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        return newValue.copyWith(
                          text: newValue.text.toUpperCase(),
                        );
                      }),
                    ],
                    // Also suggest uppercase via keyboard if possible
                    textCapitalization: TextCapitalization.characters,
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Please enter a price';
                      final price = double.tryParse(value);
                      if (price == null || price < 0)
                        return 'Please enter a valid positive price';
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
                  final newPriceInCents =
                      (double.parse(priceController.text) * 100).round();
                  controller.editItem(
                    index,
                    newDescription,
                    newPriceInCents,
                  ); // Call controller
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
    final theme = Theme.of(context); // Get theme for styling
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            // Add icon to title
            children: [
              Icon(Icons.check_circle_outline, size: 28, color: Colors.green),
              SizedBox(width: 10),
              Text('Label Scanned', style: TextStyle(color: Colors.green)),
            ],
          ),
          content: SingleChildScrollView(
            // Keep scrollable just in case
            child: Padding(
              // Add padding around content
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                // Use Column for better layout
                mainAxisSize: MainAxisSize.min, // Take minimum space
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 20,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        // Allow text wrapping
                        child: RichText(
                          text: TextSpan(
                            style:
                                theme.textTheme.bodyLarge, // Default text style
                            children: [
                              // Removed: const TextSpan(text: 'Description: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(
                                text: description.toUpperCase(),
                              ), // Ensure display is uppercase
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 20,
                        color: theme.colorScheme.secondary,
                      ), // Changed icon
                      const SizedBox(width: 8),
                      Expanded(
                        // Allow text wrapping (though less likely for price)
                        child: RichText(
                          text: TextSpan(
                            style: theme.textTheme.bodyLarge,
                            children: [
                              // Removed: const TextSpan(text: 'Price: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: formatCents(priceInCents)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0, // Increased vertical padding
          ), // Add padding to actions
          actions: <Widget>[
            TextButton(
              
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.secondary, // Use secondary color
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // Match Add button padding
              ),
              child: const Text('Cancel'),
              onPressed: () {
                controller.cancelPendingItem(); // Call controller action
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton.icon( // Changed to ElevatedButton.icon
              // Use ElevatedButton for Add
           
              icon: const Icon(Icons.add_circle, size: 18), // Added icon
              label: const Text('Add to List'), // Keep label
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
              dismissible:
                  isSaving
                      ? null
                      : DismissiblePane(onDismissed: () => onDelete(index)),
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
              const Text(
                'Subtotal',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                formatCents(subtotalCents),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
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

    // Use Extended FABs for better clarity
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        FloatingActionButton.extended(
          heroTag: 'upload_button',
          onPressed: isProcessing ? null : onUpload,
          tooltip: 'Upload Image',
          shape: StadiumBorder(
            side: BorderSide(
              color: isProcessing ? inactiveColor : activeColor,
              width: 1.5,
            ),
          ), // Use StadiumBorder for extended
          icon: const Icon(Icons.photo_library),
          label: const Text('Upload'), // Added label
        ),
        const SizedBox(width: 16),
        FloatingActionButton.extended(
          heroTag: 'scan_button',
          onPressed: isProcessing ? null : onScan,
          tooltip: 'Scan Label',
          shape: StadiumBorder(
            side: BorderSide(
              color: isProcessing ? inactiveColor : activeColor,
              width: 1.5,
            ),
          ), // Use StadiumBorder for extended
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan'), // Added label
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
