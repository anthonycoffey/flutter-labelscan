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
    // Listeners should ideally be outside the main build method if possible,
    // but for simplicity here, we keep them. They don't rebuild the widget directly.
    // We still watch the whole state here for convenience in dialogs/listeners,
    // but specific UI sections below will use Consumer/select for optimization.
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
              homeController, // Pass controller read above
              next.pendingItemDescription!,
              next.pendingItemPriceCents!,
              ref.read(homeControllerProvider).formatCents, // Read formatter from state
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
        // Wrap actions in a Consumer for targeted rebuilds
        actions: [
          Consumer(
            builder: (context, ref, child) {
              // Select only the state needed for the buttons
              final itemsEmpty = ref.watch(homeControllerProvider.select((s) => s.scannedItems.isEmpty));
              final isSaving = ref.watch(homeControllerProvider.select((s) => s.isSaving));
              final isProcessing = ref.watch(homeControllerProvider.select((s) => s.isProcessing));
              // Read controller once, it doesn't change
              final controller = ref.read(homeControllerProvider.notifier);

              return Row( // Use Row to keep buttons together
                mainAxisSize: MainAxisSize.min, // Prevent Row from taking max width
                children: [
                  // Save List Button
                  IconButton(
                    icon: const Icon(Icons.save_as), // Save icon
                    tooltip: 'Save List',
                    // Apply green color only when active
                    color: (itemsEmpty || isSaving)
                        ? null // Use default color when disabled
                        : Colors.green, // Use green when active
                    // Disable if list is empty or currently saving
                    onPressed: (itemsEmpty || isSaving)
                        ? null
                        : () => _showSaveListDialog(context, ref),
                  ),
                  // Clear List Button
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined), // Clear icon
                    tooltip: 'Clear All Items',
                    // Apply red color only when active
                    color: (itemsEmpty || isProcessing || isSaving)
                        ? null // Use default color when disabled
                        : Colors.red, // Use red when active
                    // Disable if list is empty or processing/saving
                    onPressed: (itemsEmpty || isProcessing || isSaving)
                        ? null
                        : () => _showClearConfirmationDialog(context, controller), // Pass controller read above
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: <Widget>[
              // Wrap the list/empty view in a Consumer for targeted rebuilds
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    // Select only the necessary state parts for this section
                    final items = ref.watch(homeControllerProvider.select((s) => s.scannedItems));
                    final isSaving = ref.watch(homeControllerProvider.select((s) => s.isSaving));

                    return items.isEmpty
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
                              const Text('No items in your list yet'),
                              const SizedBox(height: 8),
                              const Text('Upload or Scan an item to get started!', style: TextStyle(fontSize: 14, color: Colors.black54)),
                            ],
                          ),
                        )
                        : _ScannedItemsListView(
                            // Pass the watched state parts
                            items: items,
                            isSaving: isSaving,
                            onEdit: (index) => _showEditItemDialog(context, ref, index),
                            onDelete: (index) {
                              // Read controller here as it doesn't change
                              final controller = ref.read(homeControllerProvider.notifier);
                              controller.deleteItem(index);
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
                          );
                  },
                ),
              ),
              // --- Action Buttons Moved Here ---
              // Wrap Action Buttons in Consumer for targeted rebuilds
              Consumer(
                builder: (context, ref, child) {
                  // Select only the state needed for the buttons
                  final isProcessing = ref.watch(homeControllerProvider.select((s) => s.isProcessing));
                  final isSaving = ref.watch(homeControllerProvider.select((s) => s.isSaving));
                  // Read controller once, it doesn't change
                  final controller = ref.read(homeControllerProvider.notifier);
                  final bool isDisabled = isProcessing || isSaving;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: _ActionButtons(
                      // Pass the watched state
                      isProcessing: isDisabled,
                      onScan: () => controller.scanLabel(context), // Pass context
                      onUpload: () => controller.pickImageFromGallery(context), // Pass context
                    ),
                  );
                },
              ),
              // Collapsible Totals Section - Wrap in Consumer
              Consumer(
                builder: (context, ref, child) {
                  // Select only the state needed for the totals section
                  final itemsNotEmpty = ref.watch(homeControllerProvider.select((s) => s.scannedItems.isNotEmpty));
                  final totalCents = ref.watch(homeControllerProvider.select((s) => s.totalCents));
                  final subtotalCents = ref.watch(homeControllerProvider.select((s) => s.subtotalCents));
                  final taxCents = ref.watch(homeControllerProvider.select((s) => s.taxCents));
                  final taxRate = ref.watch(homeControllerProvider.select((s) => s.taxRate));
                  final formatCents = ref.watch(homeControllerProvider.select((s) => s.formatCents)); // Get formatter method

                  // Only build if items are not empty
                  if (!itemsNotEmpty) {
                    return const SizedBox.shrink(); // Return empty widget if no items
                  }

                  return Column( // Wrap ExpansionTile in Column to return it
                    mainAxisSize: MainAxisSize.min, // Prevent Column from expanding
                    children: [
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
                              formatCents(totalCents), // Use selected value
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                        childrenPadding: EdgeInsets.zero, // _TotalsDisplay handles its padding
                        initiallyExpanded: false,
                        children: <Widget>[
                          _TotalsDisplay(
                            subtotalCents: subtotalCents, // Use selected value
                            taxCents: taxCents, // Use selected value
                            taxRate: taxRate, // Use selected value
                            formatCents: formatCents, // Pass selected formatter
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              // Removed SizedBox placeholder for FAB
            ],
          ),
          // Loading Indicator Overlay for image processing - Wrap in Consumer
          Consumer(
            builder: (context, ref, child) {
              final isProcessing = ref.watch(homeControllerProvider.select((s) => s.isProcessing));
              final message = ref.watch(homeControllerProvider.select((s) => s.processingMessage));

              if (isProcessing) {
                return _LoadingOverlay(message: message);
              } else {
                return const SizedBox.shrink(); // Return empty widget if not processing
              }
            },
          ),
          // Could add a saving overlay too if desired, but button indicator might be enough
          // if (homeState.isSaving) // This would need its own Consumer if re-enabled
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
    // Read state directly here as it's needed for pre-check and dialog logic
    final homeState = ref.read(homeControllerProvider);
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
    final quantityController = TextEditingController(
      text: currentItem.quantity.toString(),
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
                  TextFormField(
                    controller: quantityController,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter quantity';
                      }
                      final qty = int.tryParse(value);
                      if (qty == null || qty < 1) {
                        return 'Quantity must be at least 1';
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
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final newDescription = descriptionController.text.trim();
                  final newPriceInCents =
                      (double.parse(priceController.text) * 100).round();
                  final newQuantity = int.parse(quantityController.text);
                  controller.editItem(
                    index,
                    newDescription,
                    newPriceInCents,
                    newQuantity,
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
    final theme = Theme.of(context);
    final quantityController = TextEditingController(text: '1');
    double sliderValue = 1;
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, size: 28, color: Colors.green),
              SizedBox(width: 10),
              Text('Label Scan Complete!', style: TextStyle(color: Colors.green)),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                        child: RichText(
                          text: TextSpan(
                            style: theme.textTheme.bodyLarge,
                            children: [
                              TextSpan(text: description.toUpperCase()),
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
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: theme.textTheme.bodyLarge,
                            children: [
                              TextSpan(text: formatCents(priceInCents)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quantity'),
                      StatefulBuilder(
                        builder: (context, setState) {
                          return Column(
                            children: [
                              Slider(
                                value: sliderValue,
                                min: 1,
                                max: 20,
                                divisions: 19,
                                label: sliderValue.toInt().toString(),
                                onChanged: (value) {
                                  setState(() {
                                    sliderValue = value;
                                    quantityController.text = value.toInt().toString();
                                  });
                                },
                              ),
                              Center(
                                child: Text(
                                  sliderValue.toInt().toString(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0,
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.secondary,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              ),
              child: const Text('Cancel'),
              onPressed: () {
                controller.cancelPendingItem();
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_circle, size: 18),
              label: const Text('Add to List'),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final quantity = int.parse(quantityController.text);
                      // Update pending item state directly
                      controller.state = controller.state.copyWith(
                        pendingItemQuantity: quantity
                      );
                      controller.confirmPendingItem();
                      Navigator.of(context).pop();
                    }
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
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.description,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  Text(
                    'Qty: ${item.quantity} • ${NumberFormat.currency(locale: 'en_US', symbol: '\$').format(item.priceInCents / 100)}/ea',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              trailing: Text(
                item.totalPriceFormatted,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                ),
              ),
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
