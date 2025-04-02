import 'dart:math';
import 'package:flutter/material.dart'; // For BuildContext in services
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart'; // For XFile
import 'package:intl/intl.dart'; // For currency formatting

import '../models/scanned_item.dart';
import '../services/api_service.dart';
import '../services/image_service.dart';

// --- State Definition ---

// Using a simple class for state for now. Could use Freezed for more features.
@immutable
class HomeState {
  final List<ScannedItem> scannedItems;
  final bool isProcessing;
  final String processingMessage;
  final double taxRate; // Keep tax rate in state if it might change
  final Object? error; // To hold potential errors
  final String? pendingItemDescription; // For confirmation dialog
  final int? pendingItemPriceCents; // For confirmation dialog

  const HomeState({
    this.scannedItems = const [],
    this.isProcessing = false,
    this.processingMessage = "Processing...",
    this.taxRate = 0.0825, // Default tax rate
    this.error,
    this.pendingItemDescription,
    this.pendingItemPriceCents,
  });

  // Calculated properties
  int get subtotalCents => scannedItems.fold(0, (sum, item) => sum + item.priceInCents);
  int get taxCents => (subtotalCents * taxRate).round();
  int get totalCents => subtotalCents + taxCents;

  // Formatting helper (can be moved to a utility class later)
  String formatCents(int cents) {
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    return currencyFormat.format(cents / 100.0);
  }

  // CopyWith method for immutability
  HomeState copyWith({
    List<ScannedItem>? scannedItems,
    bool? isProcessing,
    String? processingMessage,
    double? taxRate,
    Object? error,
    bool clearError = false, // Flag to explicitly clear error
    String? pendingItemDescription,
    int? pendingItemPriceCents,
    bool clearPendingItem = false, // Flag to explicitly clear pending item
  }) {
    return HomeState(
      scannedItems: scannedItems ?? this.scannedItems,
      isProcessing: isProcessing ?? this.isProcessing,
      processingMessage: processingMessage ?? this.processingMessage,
      taxRate: taxRate ?? this.taxRate,
      error: clearError ? null : error ?? this.error,
      pendingItemDescription: clearPendingItem ? null : pendingItemDescription ?? this.pendingItemDescription,
      pendingItemPriceCents: clearPendingItem ? null : pendingItemPriceCents ?? this.pendingItemPriceCents,
    );
  }
}


// --- Providers ---

// Provider for ImageService
final imageServiceProvider = Provider<ImageService>((ref) => ImageService());

// Provider for ApiService
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

// Provider for the HomeController (using StateNotifier)
final homeControllerProvider = StateNotifierProvider<HomeController, HomeState>((ref) {
  return HomeController(ref);
});


// --- Controller ---

class HomeController extends StateNotifier<HomeState> {
  final Ref _ref;
  final Random _random = Random();
  // TODO: Move processing words to constants
  final List<String> _processingWords = [
    "Vibing", "Cooking", "Analyzing", "Decoding", "Unpacking",
    "Processing", "Thinking", "Calculating", "Scanning", "Inspecting",
    "Reviewing", "Checking", "Working", "Loading", "Fetching",
    "Magic...", "Beaming", "Zooming",
  ];

  HomeController(this._ref) : super(const HomeState());

  // --- Actions ---

  Future<void> scanLabel(BuildContext context) async {
    _clearError(); // Clear previous errors
    final imageService = _ref.read(imageServiceProvider);
    final XFile? imageFile = await imageService.captureImage(context);
    if (imageFile != null) {
      await _processImage(imageFile);
    }
  }

  Future<void> pickImageFromGallery(BuildContext context) async {
    _clearError();
    final imageService = _ref.read(imageServiceProvider);
    final XFile? imageFile = await imageService.pickImageFromGallery(context);
    if (imageFile != null) {
      await _processImage(imageFile);
    }
  }

  Future<void> _processImage(XFile imageFile) async {
    final String randomWord = _processingWords[_random.nextInt(_processingWords.length)];
    state = state.copyWith(
      isProcessing: true,
      processingMessage: "$randomWord...",
      clearError: true, // Clear error when starting processing
    );

    try {
      final apiService = _ref.read(apiServiceProvider);
      final Map<String, dynamic> data = await apiService.uploadAndProcessImage(imageFile);

      // Process the data (similar to _showConfirmationDialog logic)
      final description = data['description']?.toString() ?? 'No description';
      final amount = data['amount'];
      int? priceInCents;

      if (amount is String && amount.toUpperCase() == "N/A") {
        priceInCents = null; // Explicitly null for N/A
      } else if (amount is String) {
        priceInCents = int.tryParse(amount);
      } else if (amount is int) {
        priceInCents = amount;
      } else if (amount is double) {
        priceInCents = amount.round();
      }

      if (priceInCents != null) {
        // Store pending item for confirmation
        state = state.copyWith(
          pendingItemDescription: description,
          pendingItemPriceCents: priceInCents,
        );
        // The UI layer (HomeScreen) will listen for these pending fields
        // and trigger the confirmation dialog.
      } else {
         // Handle N/A or invalid price
         debugPrint("Received N/A or invalid price for '$description': $amount");
         // Optionally set an error state or show a message via UI listener
         state = state.copyWith(error: "Could not determine price for '$description'.");
      }

    } on ApiException catch (e) {
      debugPrint("API Exception caught in controller: $e");
      state = state.copyWith(error: e); // Store the specific API error
    } catch (e) {
      debugPrint("Generic Exception caught in controller: $e");
      state = state.copyWith(error: e); // Store generic error
    } finally {
      state = state.copyWith(isProcessing: false);
    }
  }

  // Called by UI after user confirms the dialog
  void confirmPendingItem() {
    if (state.pendingItemDescription != null && state.pendingItemPriceCents != null) {
      _addItem(state.pendingItemDescription!, state.pendingItemPriceCents!);
      // Clear pending item after adding
      state = state.copyWith(clearPendingItem: true);
    }
  }

  // Called by UI after user cancels the dialog
  void cancelPendingItem() {
    // Just clear the pending item state
    state = state.copyWith(clearPendingItem: true);
  }

  // Internal method to add item to the list
  void _addItem(String description, int priceInCents) {
    final newItem = ScannedItem(description: description, priceInCents: priceInCents);
    // Create a new list with the added item
    final updatedItems = List<ScannedItem>.from(state.scannedItems)..add(newItem);
    state = state.copyWith(scannedItems: updatedItems, clearError: true);
  }

  void deleteItem(int index) {
    if (index < 0 || index >= state.scannedItems.length) return;
    final updatedItems = List<ScannedItem>.from(state.scannedItems)..removeAt(index);
    state = state.copyWith(scannedItems: updatedItems, clearError: true);
    // Optionally: Show confirmation SnackBar from UI layer
  }

  void editItem(int index, String newDescription, int newPriceInCents) {
     if (index < 0 || index >= state.scannedItems.length) return;
     final updatedItem = ScannedItem(description: newDescription, priceInCents: newPriceInCents);
     final updatedItems = List<ScannedItem>.from(state.scannedItems);
     updatedItems[index] = updatedItem;
     state = state.copyWith(scannedItems: updatedItems, clearError: true);
  }

  void clearAllItems() {
    state = state.copyWith(scannedItems: [], clearError: true);
  }

  // Helper to clear error state
  void _clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }
}
